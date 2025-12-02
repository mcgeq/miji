<script setup lang="ts">
import DateTimePicker from '@/components/common/DateTimePicker.vue';
import CurrencySelector from '@/components/common/money/CurrencySelector.vue';
import { Checkbox, FormRow, Input, Modal, Select, Textarea } from '@/components/ui';
import {
  TransactionStatusSchema,
  TransactionTypeSchema,
} from '@/schema/common';
import { useCategoryStore } from '@/stores/money';
import { lowercaseFirstLetter } from '@/utils/string';
import { DateUtils } from '@/utils/date';
import { Lg } from '@/utils/debugLog';
import { toast } from '@/utils/toast';
import { isInstallmentTransaction } from '@/utils/transaction';
import { useAccountFilter } from '../composables/useAccountFilter';
import { useInstallmentManagement } from '../composables/useInstallmentManagement';
import { getDefaultPaymentMethod, usePaymentMethods } from '../composables/usePaymentMethods';
import { useTransactionCategory } from '../composables/useTransactionCategory';
import { useTransactionDataLoader } from '../composables/useTransactionDataLoader';
import { useTransactionLedgerLink } from '../composables/useTransactionLedgerLink';
import { useTransactionValidation } from '../composables/useTransactionValidation';
import { INSTALLMENT_CONSTANTS } from '../constants/transactionConstants';
import { handleAmountInput as handleAmountInputUtil } from '../utils/formUtils';
import { formatCurrency } from '../utils/money';
import { safeToFixed } from '../utils/numberUtils';
import { initializeFormData } from '../utils/transactionFormUtils';
import TransactionSplitSection from './TransactionSplitSection.vue';
import type { SelectOption } from '@/components/ui';
import type {
  TransactionType,
} from '@/schema/common';
import type {
  Account,
  Transaction,
  TransactionCreate,
  TransactionUpdate,
  TransferCreate,
} from '@/schema/money';
import type { InstallmentPlanResponse } from '@/services/money/transactions';

interface Props {
  type: TransactionType;
  transaction?: Transaction | null;
  accounts: Account[];
  readonly?: boolean;
}

const props = defineProps<Props>();
const emit = defineEmits<{
  close: [];
  save: [transaction: TransactionCreate];
  update: [serialNum: string, transaction: TransactionUpdate];
  saveTransfer: [transfer: TransferCreate];
  updateTransfer: [serialNum: string, transfer: TransferCreate];
  refresh: [];
}>();
const categoryStore = useCategoryStore();
const { t } = useI18n();

// 提交状态
const isSubmitting = ref(false);

// 模态框标题
const modalTitle = computed(() => {
  const titles: Record<TransactionType, string> = {
    Income: 'financial.transaction.recordIncome',
    Expense: 'financial.transaction.recordExpense',
    Transfer: 'financial.transaction.recordTransfer',
  };

  if (props.transaction) {
    return props.readonly
      ? t('financial.transaction.viewTransaction')
      : t('financial.transaction.editTransaction');
  }
  return t(titles[props.type]);
});

// 使用验证 Composable
const {
  validateTransfer,
  validateExpense,
} = useTransactionValidation();

// 使用工具函数初始化表单（必须先定义，因为其他 composables 依赖它）
const form = ref<Transaction>(initializeFormData(
  props.transaction || null,
  props.type,
  props.accounts,
));

// 分期管理功能
const installmentManager = useInstallmentManagement();
// 解构常用属性供模板直接使用
const {
  // 统计属性
  paidPeriodsCount,
  pendingPeriodsCount,
  totalPeriodsCount,
  // 计算属性
  calculatedInstallmentAmount,
  installmentDetails,
  visibleDetails,
  hasMorePeriods,
  // 状态
  hasPaidInstallments,
  isExpanded,
} = installmentManager;

// 分类管理功能
const categoryManager = useTransactionCategory(
  computed(() => form.value.transactionType),
  computed(() => categoryStore.subCategories),
);
// 解构分类相关属性
const { categoryMap } = categoryManager;

// 账户过滤功能
const { selectableAccounts: selectAccounts } = useAccountFilter(
  computed(() => props.accounts),
  computed(() => form.value.transactionType),
  computed(() => form.value.category),
);

// Select 组件选项数据
const accountOptions = computed<SelectOption[]>(() =>
  selectAccounts.value.map(account => ({
    value: account.serialNum,
    label: `${account.name} (${formatCurrency(account.balance)})`,
  })),
);

// 支付方式管理
const {
  availablePaymentMethods,
  isPaymentMethodEditable: baseIsPaymentMethodEditable,
} = usePaymentMethods(
  computed(() => props.accounts),
  computed(() => form.value.accountSerialNum),
  computed(() => form.value.transactionType),
);

const paymentMethodOptions = computed<SelectOption[]>(() =>
  availablePaymentMethods.value.map(method => ({
    value: method,
    label: t(`financial.paymentMethods.${method.toLowerCase()}`),
  })),
);

const categoryOptions = computed<SelectOption[]>(() =>
  Array.from(categoryMap.value.entries()).map(([_key, category]) => ({
    value: category.name,
    label: t(`common.categories.${lowercaseFirstLetter(category.name)}`),
  })),
);

const subCategoryOptions = computed<SelectOption[]>(() => {
  if (!form.value.category) return [];
  const subs = categoryMap.value.get(form.value.category)?.subs || [];
  return subs.map(sub => ({
    value: sub,
    label: t(`common.subCategories.${lowercaseFirstLetter(sub)}`),
  }));
});

// 账本和成员关联功能
const {
  availableLedgers,
  selectedLedgers,
  availableMembers,
  selectedMembers,
  loading: _ledgerLinkLoading,
  loadAvailableLedgers,
  loadAvailableMembers,
  getSmartSuggestions,
  getTransactionLinks,
} = useTransactionLedgerLink();

// 数据加载器
const dataLoader = useTransactionDataLoader({
  loadAvailableLedgers,
  loadAvailableMembers,
  getTransactionLinks,
});

// 显示账本选择器
const showLedgerSelector = ref(false);
// 显示成员选择器
const showMemberSelector = ref(false);

const isTransferReadonly = computed(() => {
  return !!(props.transaction && form.value.category === 'Transfer');
});

const isEditMode = computed<boolean>(() => !!props.transaction);
const isAccountDisabled = computed<boolean>(() => isTransferReadonly.value || isEditMode.value);

// 转入账户的计算属性，处理 nullable 转换
const toAccountSerialNum = computed<string>({
  get: () => form.value.toAccountSerialNum ?? '',
  set: (value: string) => {
    form.value.toAccountSerialNum = value || undefined;
  },
});

// 子分类的计算属性，处理 nullable 转换
const subCategory = computed<string>({
  get: () => form.value.subCategory ?? '',
  set: (value: string) => {
    form.value.subCategory = value || undefined;
  },
});

// 首次到期日的计算属性，处理 nullable 转换
const firstDueDate = computed<string>({
  get: () => form.value.firstDueDate ?? '',
  set: (value: string) => {
    form.value.firstDueDate = value || undefined;
  },
});

// 关联交易序列号的计算属性，处理 optional 转换
const relatedTransactionSerialNum = computed<string>({
  get: () => form.value.relatedTransactionSerialNum ?? '',
  set: (value: string) => {
    form.value.relatedTransactionSerialNum = value || undefined;
  },
});

// 分摊配置状态
const splitConfig = ref<{
  enabled: boolean;
  splitType?: string;
  members?: Array<{
    memberSerialNum: string;
    memberName: string;
    amount: number;
    percentage?: number;
    weight?: number;
  }>;
}>({
  enabled: false,
});

// 处理分摊配置更新
function handleSplitConfigUpdate(config: any) {
  splitConfig.value = config;
}

// 调用后端API计算分期金额
async function calculateInstallmentFromBackend() {
  await installmentManager.calculateInstallment(
    form.value.amount,
    form.value.totalPeriods,
    form.value.firstDueDate || undefined,
    form.value.date,
  );
}

// 加载分期计划详情（用于编辑模式）
async function loadInstallmentPlanDetails(planSerialNum: string) {
  await installmentManager.loadPlanBySerialNum(planSerialNum);
  // 同步数据（TODO: Phase 2.6 删除）
  if (installmentManager.planDetails.value) {
    processInstallmentPlanResponse(installmentManager.planDetails.value as any);
  }
}

// 加载分期计划详情（根据交易序列号）
async function loadInstallmentPlanDetailsByTransaction(transactionSerialNum: string) {
  await installmentManager.loadPlanByTransaction(transactionSerialNum);
  // 同步数据（TODO: Phase 2.6 删除）
  if (installmentManager.planDetails.value) {
    processInstallmentPlanResponse(installmentManager.planDetails.value as any);
  }
}

// 处理分期计划响应（共用逻辑）
function processInstallmentPlanResponse(response: InstallmentPlanResponse | null) {
  if (response && response.details) {
    // 更新表单中的分期相关字段
    if (response.total_periods !== undefined && response.total_periods !== null) {
      form.value.totalPeriods = Number(response.total_periods);
      form.value.remainingPeriods = Number(response.total_periods);
    }
    if (response.installment_amount !== undefined && response.installment_amount !== null) {
      form.value.installmentAmount = Number(response.installment_amount);
    }
    if (response.first_due_date) {
      form.value.firstDueDate = response.first_due_date;
    }
  }
}

// 检查交易是否有已完成的分期付款
async function checkPaidInstallments(transactionSerialNum: string) {
  await installmentManager.checkPaidStatus(transactionSerialNum);
}

// 判断分期付款相关字段是否应该被禁用（直接使用 composable）
const isInstallmentFieldsDisabled = computed(() => {
  return isEditMode.value && hasPaidInstallments.value;
});

// 判断当前交易是否为分期交易
const isCurrentTransactionInstallment = computed(() => {
  if (!props.transaction) {
    return false;
  }
  return isInstallmentTransaction(props.transaction);
});

// 判断是否应该禁用某些字段（分期交易时）
const isInstallmentTransactionFieldsDisabled = computed(() => {
  return isCurrentTransactionInstallment.value;
});

// 判断是否应该禁用所有字段（只读模式）
const isReadonlyMode = computed(() => {
  return props.readonly === true;
});

// 获取状态显示文本
function getStatusText(status: string): string {
  if (!status) {
    return '';
  }
  const statusMap: Record<string, string> = {
    PAID: t('financial.installment.status.paid'),
    PENDING: t('financial.installment.status.pending'),
    OVERDUE: t('financial.installment.status.overdue'),
    paid: t('financial.installment.status.paid'),
    pending: t('financial.installment.status.pending'),
    overdue: t('financial.installment.status.overdue'),
  };
  const result = statusMap[status] || status;
  return result;
}

// 查找账户
function findAccount(accountId: string | null | undefined) {
  if (!accountId) return undefined;
  return props.accounts.find(acc => acc.serialNum === accountId);
}

// 清除账本和成员关联
function clearLedgerAssociations() {
  selectedLedgers.value = [];
  selectedMembers.value = [];
}

// 处理账户变化：智能推荐账本（仅创建模式）
async function handleAccountChangeForLedgers(accountId: string | null, oldAccountId: string | null) {
  // 只在创建模式下处理
  if (props.transaction) return;

  // 清空账户时，清除所有关联
  if (!accountId) {
    clearLedgerAssociations();
    return;
  }

  // 账户切换时
  try {
    const { suggestedLedgers } = await getSmartSuggestions(accountId);

    // 切换到不同账户时，清除旧的关联
    if (oldAccountId && oldAccountId !== accountId) {
      clearLedgerAssociations();
    }

    // 自动反显家庭账本
    if (suggestedLedgers.length > 0) {
      selectedLedgers.value = suggestedLedgers.map(l => l.serialNum);
    } else {
      selectedLedgers.value = [];
    }

    // 成员保持为空，让用户手动选择
    selectedMembers.value = [];
  } catch (error) {
    Lg.e('TransactionModal', 'Failed to get smart suggestions:', error);
    clearLedgerAssociations();
  }
}

// 处理账户变化：设置支付方式
function handleAccountChangeForPayment(accountId: string | null) {
  const selectedAccount = findAccount(accountId);

  // 自动设置支付方式
  form.value.paymentMethod = getDefaultPaymentMethod(
    selectedAccount,
    form.value.transactionType,
  );

  // 防止转账时来源账户和目标账户相同
  if (accountId === form.value.toAccountSerialNum) {
    form.value.toAccountSerialNum = '';
  }
}

// 可用的交易状态选项
const availableTransactionStatuses = computed(() => {
  if (!form.value.isInstallment) {
    return [
      {
        value: TransactionStatusSchema.enum.Pending,
        label: t('financial.transaction.statusOptions.pending'),
      },
      { value: TransactionStatusSchema.enum.Completed, label: t('financial.transaction.statusOptions.completed') },
      { value: TransactionStatusSchema.enum.Reversed, label: t('financial.transaction.statusOptions.reversed') },
    ];
  }

  // 分期付款时，只能选择 Pending 或 Reversed，不能选择 Completed
  return [
    { value: TransactionStatusSchema.enum.Pending, label: t('financial.transaction.statusOptions.pending') },
    { value: TransactionStatusSchema.enum.Reversed, label: t('financial.transaction.statusOptions.reversed') },
  ];
});

// 初始化：加载必要数据
onMounted(async () => {
  try {
    if (props.transaction) {
      // 编辑模式：加载完整数据
      const loadedData = await dataLoader.loadEditModeData(props.transaction);

      // 应用加载的数据到状态
      dataLoader.applyLoadedData(loadedData, {
        selectedLedgers,
        selectedMembers,
        splitConfig,
      });
    } else {
      // 创建模式：只加载基础数据
      await dataLoader.loadCreateModeData();
    }
  } catch (error) {
    Lg.e('TransactionModal', 'Failed to initialize transaction modal:', error);
    toast.error('加载交易数据失败');
  }
});

// 监听账本选择变化，重新加载成员列表
watch(() => selectedLedgers.value, async () => {
  // 当账本选择发生变化时，重新加载成员列表
  await loadAvailableMembers();

  // 清理不再有效的成员选择
  if (availableMembers.value.length > 0) {
    const validMemberIds = new Set(availableMembers.value.map(m => m.serialNum));
    selectedMembers.value = selectedMembers.value.filter(id => validMemberIds.has(id));
  } else {
    selectedMembers.value = [];
  }
}, { deep: true });

// 监听账户变化：处理账本推荐和支付方式设置
watch(() => form.value.accountSerialNum, async (accountId, oldAccountId) => {
  // 1. 智能推荐账本（仅创建模式）
  await handleAccountChangeForLedgers(accountId, oldAccountId);

  // 2. 设置支付方式
  handleAccountChangeForPayment(accountId);
});

// 监听分期选项变化
watch(() => form.value.isInstallment, newValue => {
  if (newValue) {
    // 启用分期时，设置默认值（使用常量而非魔法数字）
    form.value.totalPeriods = INSTALLMENT_CONSTANTS.DEFAULT_PERIODS;
    form.value.remainingPeriods = INSTALLMENT_CONSTANTS.DEFAULT_PERIODS;
    form.value.transactionStatus = TransactionStatusSchema.enum.Pending;
    // 设置默认首期还款日期为交易日期
    form.value.firstDueDate = DateUtils.formatDateOnly(new Date(form.value.date));
    // 调用后端计算分期金额
    calculateInstallmentFromBackend();
  } else {
    // 禁用分期时，重置相关字段
    form.value.totalPeriods = 0;
    form.value.remainingPeriods = 0;
    form.value.installmentPlanSerialNum = null;
    form.value.installmentAmount = 0;
    form.value.firstDueDate = undefined;
    form.value.transactionStatus = TransactionStatusSchema.enum.Completed;
    // 使用 composable 重置状态
    installmentManager.resetInstallmentState();
  }
});

// 监听总期数变化，更新剩余期数
watch(() => form.value.totalPeriods, () => {
  if (form.value.isInstallment) {
    form.value.remainingPeriods = form.value.totalPeriods;
  }
});

// 监听金额和期数变化，调用后端API计算分期金额
watch([() => form.value.amount, () => form.value.totalPeriods, () => form.value.firstDueDate], () => {
  if (form.value.isInstallment) {
    calculateInstallmentFromBackend();
  }
}, { immediate: false });

// 监听分期计算结果变化，更新表单中的分期金额
watch(calculatedInstallmentAmount, newAmount => {
  if (form.value.isInstallment) {
    form.value.installmentAmount = newAmount;
  }
});

// 判断支付方式是否可编辑（增强版，考虑分期和只读模式）
const isPaymentMethodEditable = computed(() => {
  // 基础判断（收入交易、单一支付方式）
  if (!baseIsPaymentMethodEditable.value) return false;
  // 分期交易且字段被禁用时不可编辑
  if (isInstallmentTransactionFieldsDisabled.value) return false;
  // 只读模式下不可编辑
  if (isReadonlyMode.value) return false;
  return true;
});

function clearMemberSelection() {
  selectedMembers.value = [];
  toast.info('已清空成员选择');
}

// 全选成员
function selectAllMembers() {
  if (availableMembers.value.length > 0) {
    selectedMembers.value = availableMembers.value.map(m => m.serialNum);
    toast.success('已选择所有成员');
  }
}

// 验证并提交表单
async function handleSubmit() {
  if (isSubmitting.value) return;

  const isValid = await validateForm();
  if (!isValid) return;

  await submitForm();
}

// 验证表单
async function validateForm(): Promise<boolean> {
  const amount = form.value.amount;
  const fromAccount = findAccount(form.value.accountSerialNum);

  // 转账验证
  if (form.value.category === TransactionTypeSchema.enum.Transfer) {
    const toAccount = findAccount(form.value.toAccountSerialNum);
    const result = validateTransfer(fromAccount, toAccount, amount);

    if (!result.valid) {
      toast.error(result.error || '转账验证失败');
      return false;
    }
  } else if (form.value.transactionType === TransactionTypeSchema.enum.Expense) {
    // 支出验证
    const result = validateExpense(fromAccount, amount);

    if (!result.valid) {
      toast.error(result.error || '支出验证失败');
      return false;
    }
  }

  return true;
}

// 提交表单
async function submitForm() {
  isSubmitting.value = true;
  try {
    const amount = form.value.amount;

    if (form.value.category === TransactionTypeSchema.enum.Transfer) {
      await emitTransfer(amount);
    } else {
      await emitTransaction(amount);
    }
  } catch (error) {
    Lg.e('TransactionModal', 'Failed to submit form:', error);
    toast.error('提交失败，请重试');
  } finally {
    isSubmitting.value = false;
  }
}

// 发射转账事件
function emitTransfer(amount: number) {
  const fromTransaction: TransferCreate = {
    amount,
    transactionType: form.value.transactionType,
    accountSerialNum: form.value.accountSerialNum,
    toAccountSerialNum: form.value.toAccountSerialNum!,
    currency: form.value.currency.code,
    paymentMethod: form.value.paymentMethod,
    category: form.value.category,
    subCategory: form.value.subCategory,
    date: DateUtils.formatDateToBackend(typeof form.value.date === 'string' ? new Date(form.value.date) : form.value.date),
    description: form.value.description,
  };

  if (props.transaction && props.transaction.relatedTransactionSerialNum) {
    emit('updateTransfer', props.transaction.relatedTransactionSerialNum, fromTransaction);
  } else {
    emit('saveTransfer', fromTransaction);
  }
}

// 发射普通交易事件
function emitTransaction(amount: number) {
  const transaction: TransactionCreate = {
    transactionType: form.value.transactionType,
    transactionStatus: form.value.transactionStatus,
    date: DateUtils.formatDateToBackend(typeof form.value.date === 'string' ? new Date(form.value.date) : form.value.date),
    amount,
    refundAmount: props.transaction ? props.transaction.amount : 0,
    description: form.value.description,
    notes: form.value.notes,
    accountSerialNum: form.value.accountSerialNum,
    toAccountSerialNum: null,
    category: form.value.category,
    subCategory: form.value.subCategory,
    tags: form.value.tags,
    paymentMethod: form.value.paymentMethod,
    actualPayerAccount: form.value.actualPayerAccount,
    relatedTransactionSerialNum: form.value.relatedTransactionSerialNum,
    isDeleted: false,
    currency: form.value.currency.code,
    // 分期相关字段
    isInstallment: form.value.isInstallment,
    firstDueDate: form.value.firstDueDate || undefined,
    totalPeriods: form.value.totalPeriods,
    remainingPeriods: form.value.remainingPeriods,
    installmentAmount: amount,
    remainingPeriodsAmount: amount,
    // 家庭记账本关联（支持多个）
    familyLedgerSerialNums: selectedLedgers.value,
    // 分摊配置
    splitConfig: splitConfig.value.enabled && splitConfig.value.members && splitConfig.value.members.length > 0
      ? {
          splitType: splitConfig.value.splitType || 'EQUAL',
          members: splitConfig.value.members,
        }
      : undefined,
  } as any;

  if (props.transaction) {
    const updateTransaction: TransactionUpdate = {
      ...transaction,
    };
    emit('update', props.transaction.serialNum, updateTransaction);
  } else {
    emit('save', transaction);
  }
}

// 处理金额输入（使用工具函数）
function handleAmountInput(event: Event) {
  form.value.amount = handleAmountInputUtil(event);
}

watch(
  () => form.value.category,
  newCategory => {
    const subs = categoryMap.value.get(newCategory)?.subs || [];
    const currentSubCategory = form.value.subCategory ?? '';
    if (subs.length > 0 && !subs.includes(currentSubCategory)) {
      form.value.subCategory = subs[0];
    }
  },
);

watch(
  () => props.transaction,
  async transaction => {
    if (transaction) {
      form.value = initializeFormData(
        transaction,
        props.type,
        props.accounts,
      );
      // 注意：初始化已由工具函数处理，数字字段已转换

      // 如果是分期付款交易，加载分期计划详情
      if (transaction.isInstallment) {
        if (transaction.installmentPlanSerialNum) {
          await loadInstallmentPlanDetails(transaction.installmentPlanSerialNum);
        } else {
          // 如果没有 installmentPlanSerialNum，尝试根据交易序列号查询
          await loadInstallmentPlanDetailsByTransaction(transaction.serialNum);
        }
      }

      // 检查是否有已完成的分期付款
      await checkPaidInstallments(transaction.serialNum);
    } else {
      form.value = initializeFormData(null, props.type, props.accounts);
      // 重置分期付款状态
      installmentManager.resetInstallmentState();
    }
  },
  { immediate: true },
);

watch(
  () => form.value.amount,
  newVal => {
    if (newVal === 0) {
      nextTick(() => {
        const input = document.querySelector('input[type="number"]') as HTMLInputElement;
        if (input && input.value === '0') input.value = '';
      });
    }
  },
);
</script>

<template>
  <Modal
    :open="true"
    :title="modalTitle"
    size="md"
    :confirm-loading="isSubmitting"
    :show-footer="!isReadonlyMode"
    @close="$emit('close')"
    @confirm="handleSubmit"
  >
    <form @submit.prevent="handleSubmit">
      <!-- 交易类型 - 仅在编辑/查看模式显示 -->
      <FormRow v-if="props.transaction" :label="t('financial.transaction.transType')" required>
        <div class="px-4 py-2.5 rounded-lg bg-gray-50 dark:bg-gray-900 border border-gray-300 dark:border-gray-600 text-gray-900 dark:text-white font-medium">
          {{ form.transactionType === 'Income' ? t('financial.transaction.income')
            : form.transactionType === 'Expense' ? t('financial.transaction.expense')
              : t('financial.transaction.transfer') }}
        </div>
      </FormRow>

      <!-- 金额 -->
      <FormRow :label="t('financial.money')" required>
        <Input
          v-model="form.amount"
          v-has-value
          type="number"
          :placeholder="t('common.placeholders.enterAmount')"
          :disabled="isInstallmentFieldsDisabled || isInstallmentTransactionFieldsDisabled || isReadonlyMode"
          @input="handleAmountInput"
        />
      </FormRow>

      <!-- 币种 -->
      <FormRow :label="t('financial.currency')" required>
        <CurrencySelector
          v-model="form.currency"
          width="full"
          :disabled="isTransferReadonly || isInstallmentFieldsDisabled || isInstallmentTransactionFieldsDisabled || isReadonlyMode"
        />
      </FormRow>

      <!-- 分摊设置已移到分摊成员选择之后 -->

      <!-- 转出账户 -->
      <FormRow
        :label="isTransferReadonly || form.transactionType === TransactionTypeSchema.enum.Transfer ? t('financial.transaction.fromAccount') : t('financial.account.account')"
        required
      >
        <Select
          v-model="form.accountSerialNum"
          v-has-value
          :options="accountOptions"
          :placeholder="t('common.placeholders.selectAccount')"
          :disabled="isAccountDisabled || isReadonlyMode"
        />
      </FormRow>

      <!-- 转入账户 -->
      <FormRow
        v-if="isTransferReadonly || form.transactionType === TransactionTypeSchema.enum.Transfer"
        :label="t('financial.transaction.toAccount')"
        required
      >
        <Select
          v-model="toAccountSerialNum"
          v-has-value
          :options="accountOptions.filter(opt => opt.value !== form.accountSerialNum)"
          :placeholder="t('common.placeholders.selectAccount')"
          :disabled="isAccountDisabled || isReadonlyMode"
        />
      </FormRow>

      <!-- 支付渠道 -->
      <FormRow :label="t('financial.transaction.paymentMethod')" required>
        <Select
          v-if="isPaymentMethodEditable"
          v-model="form.paymentMethod"
          v-has-value
          :options="paymentMethodOptions"
          :placeholder="t('common.placeholders.selectOption')"
          :disabled="isTransferReadonly || isReadonlyMode"
        />
        <div v-else class="px-4 py-2.5 rounded-lg bg-gray-50 dark:bg-gray-900 border border-gray-300 dark:border-gray-600 text-gray-900 dark:text-white font-medium">
          {{ t(`financial.paymentMethods.${form.paymentMethod.toLowerCase()}`) }}
        </div>
      </FormRow>

      <!-- 分类 -->
      <FormRow :label="t('categories.category')" required>
        <Select
          v-model="form.category"
          v-has-value
          :options="categoryOptions"
          :placeholder="t('common.placeholders.selectCategory')"
          :disabled="isTransferReadonly || isInstallmentTransactionFieldsDisabled || isReadonlyMode"
        />
      </FormRow>

      <!-- 子分类 -->
      <FormRow
        v-if="form.category && categoryMap.get(form.category)?.subs.length"
        :label="t('categories.subCategory')"
        optional
      >
        <Select
          v-model="subCategory"
          v-has-value
          :options="subCategoryOptions"
          :placeholder="t('common.placeholders.selectOption')"
          :disabled="isTransferReadonly || isInstallmentTransactionFieldsDisabled || isReadonlyMode"
        />
      </FormRow>

      <!-- 关联账本 -->
      <FormRow v-if="!isReadonlyMode || selectedLedgers.length > 0" label="关联账本" optional>
        <div class="flex items-center gap-2 w-full">
          <div class="flex-1 flex items-center gap-2 px-3 py-2 rounded-lg border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-800 min-h-[42px]">
            <div v-if="selectedLedgers.length === 0" class="flex items-center gap-2 text-gray-400 dark:text-gray-500">
              <LucideInbox class="w-4 h-4" />
              <span class="text-sm">未选择账本</span>
            </div>
            <div v-else class="flex items-center gap-2 flex-wrap">
              <span class="inline-flex items-center gap-1.5 px-2.5 py-1 bg-blue-50 dark:bg-blue-900/20 text-blue-700 dark:text-blue-400 rounded-md text-sm font-medium">
                {{ availableLedgers.find(l => l.serialNum === selectedLedgers[0])?.name || selectedLedgers[0] }}
                <button
                  v-if="!isReadonlyMode"
                  type="button"
                  class="ml-1 hover:bg-blue-100 dark:hover:bg-blue-900/40 rounded p-0.5 transition-colors"
                  @click="selectedLedgers = selectedLedgers.filter(id => id !== selectedLedgers[0])"
                >
                  <LucideX class="w-3 h-3" />
                </button>
              </span>
              <span
                v-if="selectedLedgers.length > 1"
                class="inline-flex items-center px-2 py-1 bg-gray-100 dark:bg-gray-700 text-gray-600 dark:text-gray-300 rounded-md text-xs font-medium"
                :title="selectedLedgers.slice(1).map(id => availableLedgers.find(l => l.serialNum === id)?.name || id).join('\n')"
              >
                +{{ selectedLedgers.length - 1 }}
              </span>
            </div>
          </div>
          <button
            v-if="!isReadonlyMode"
            type="button"
            class="w-9 h-9 flex items-center justify-center rounded-lg border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-700 hover:border-blue-500 dark:hover:border-blue-400 transition-all"
            :title="showLedgerSelector ? '收起' : '选择账本'"
            @click="showLedgerSelector = !showLedgerSelector"
          >
            <LucideChevronDown v-if="!showLedgerSelector" class="w-4 h-4" />
            <LucideChevronUp v-else class="w-4 h-4" />
          </button>
        </div>
      </FormRow>

      <!-- 账本选择下拉 -->
      <div v-if="!isReadonlyMode && showLedgerSelector" class="mb-4 -mt-2">
        <div class="p-4 border border-gray-200 dark:border-gray-700 rounded-lg bg-gray-50 dark:bg-gray-900">
          <div class="flex items-center justify-between mb-3">
            <span class="text-sm font-semibold text-gray-900 dark:text-white">选择账本</span>
            <button
              type="button"
              class="p-1 hover:bg-gray-200 dark:hover:bg-gray-700 rounded transition-colors"
              @click="showLedgerSelector = false"
            >
              <LucideX class="w-4 h-4 text-gray-500 dark:text-gray-400" />
            </button>
          </div>
          <div class="flex flex-col gap-2 max-h-60 overflow-y-auto">
            <label
              v-for="ledger in availableLedgers"
              :key="ledger.serialNum"
              class="flex items-center gap-3 p-3 rounded-lg hover:bg-white dark:hover:bg-gray-800 border border-transparent hover:border-gray-200 dark:hover:border-gray-700 cursor-pointer transition-all"
            >
              <Checkbox
                v-model="selectedLedgers"
                :value="ledger.serialNum"
              />
              <div class="flex-1 flex items-center justify-between">
                <span class="text-sm font-medium text-gray-900 dark:text-white">{{ ledger.name }}</span>
                <span class="text-xs text-gray-500 dark:text-gray-400 bg-gray-100 dark:bg-gray-800 px-2 py-0.5 rounded">{{ ledger.ledgerType }}</span>
              </div>
            </label>
          </div>
        </div>
      </div>

      <!-- 分摆成员 -->
      <FormRow v-if="selectedLedgers.length > 0 && (!isReadonlyMode || selectedMembers.length > 0)" label="分摆成员" optional>
        <div class="flex flex-col gap-1.5 w-full">
          <div class="flex items-center gap-2">
            <div class="flex-1 flex items-center gap-2 px-3 py-2 rounded-lg border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-800 min-h-[42px]">
              <div v-if="selectedMembers.length === 0" class="flex items-center gap-2 text-gray-400 dark:text-gray-500">
                <LucideUsers class="w-4 h-4" />
                <span class="text-sm">未选择成员</span>
              </div>
              <div v-else class="flex items-center gap-2 flex-wrap">
                <span class="inline-flex items-center gap-1.5 px-2.5 py-1 bg-green-50 dark:bg-green-900/20 text-green-700 dark:text-green-400 rounded-md text-sm font-medium">
                  {{ availableMembers.find(m => m.serialNum === selectedMembers[0])?.name || selectedMembers[0] }}
                  <button
                    v-if="!isReadonlyMode"
                    type="button"
                    class="ml-1 hover:bg-green-100 dark:hover:bg-green-900/40 rounded p-0.5 transition-colors"
                    @click="selectedMembers = selectedMembers.filter(id => id !== selectedMembers[0])"
                  >
                    <LucideX class="w-3 h-3" />
                  </button>
                </span>
                <span
                  v-if="selectedMembers.length > 1"
                  class="inline-flex items-center px-2 py-1 bg-gray-100 dark:bg-gray-700 text-gray-600 dark:text-gray-300 rounded-md text-xs font-medium"
                  :title="selectedMembers.slice(1).map(id => availableMembers.find(m => m.serialNum === id)?.name || id).join('\n')"
                >
                  +{{ selectedMembers.length - 1 }}
                </span>
              </div>
            </div>
            <button
              v-if="!isReadonlyMode"
              type="button"
              class="w-9 h-9 flex items-center justify-center rounded-lg border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-700 hover:border-blue-500 dark:hover:border-blue-400 transition-all"
              :title="showMemberSelector ? '收起' : '选择成员'"
              @click="showMemberSelector = !showMemberSelector"
            >
              <LucideChevronDown v-if="!showMemberSelector" class="w-4 h-4" />
              <LucideChevronUp v-else class="w-4 h-4" />
            </button>
          </div>
          <div v-if="!isReadonlyMode && selectedMembers.length === 0" class="text-xs text-gray-500 dark:text-gray-400">
            如不选择成员，则为个人交易
          </div>
        </div>
      </FormRow>

      <!-- 成员选择下拉 -->
      <div v-if="!isReadonlyMode && selectedLedgers.length > 0 && showMemberSelector" class="mb-4 -mt-2">
        <div class="p-4 border border-gray-200 dark:border-gray-700 rounded-lg bg-gray-50 dark:bg-gray-900">
          <div class="flex items-center justify-between mb-3">
            <span class="text-sm font-semibold text-gray-900 dark:text-white">选择成员</span>
            <div class="flex items-center gap-2">
              <button
                v-if="availableMembers.length > 0"
                type="button"
                class="flex items-center gap-1 px-2.5 py-1 text-xs font-medium text-blue-600 dark:text-blue-400 bg-blue-50 dark:bg-blue-900/20 border border-blue-200 dark:border-blue-800 rounded hover:bg-blue-100 dark:hover:bg-blue-900/30 transition-colors"
                title="全选成员"
                @click="selectAllMembers"
              >
                <LucideUserPlus class="w-3.5 h-3.5" />
                全选
              </button>
              <button
                v-if="selectedMembers.length > 0"
                type="button"
                class="flex items-center gap-1 px-2.5 py-1 text-xs font-medium text-gray-600 dark:text-gray-400 bg-gray-100 dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded hover:bg-gray-200 dark:hover:bg-gray-700 transition-colors"
                title="清空成员"
                @click="clearMemberSelection"
              >
                <LucideX class="w-3.5 h-3.5" />
                清空
              </button>
              <button
                type="button"
                class="p-1 hover:bg-gray-200 dark:hover:bg-gray-700 rounded transition-colors"
                @click="showMemberSelector = false"
              >
                <LucideX class="w-4 h-4 text-gray-500 dark:text-gray-400" />
              </button>
            </div>
          </div>
          <div class="flex flex-col gap-2 max-h-60 overflow-y-auto">
            <label
              v-for="member in availableMembers"
              :key="member.serialNum"
              class="flex items-center gap-3 p-3 rounded-lg hover:bg-white dark:hover:bg-gray-800 border border-transparent hover:border-gray-200 dark:hover:border-gray-700 cursor-pointer transition-all"
            >
              <Checkbox
                v-model="selectedMembers"
                :value="member.serialNum"
              />
              <span class="text-sm font-medium text-gray-900 dark:text-white">{{ member.name }}</span>
            </label>
          </div>
        </div>
      </div>

      <!-- 分摊设置 -->
      <TransactionSplitSection
        v-if="selectedLedgers.length > 0 && selectedMembers.length > 0 && form.amount > 0 && form.transactionType !== TransactionTypeSchema.enum.Transfer && (!isReadonlyMode || splitConfig.enabled)"
        :transaction-amount="form.amount"
        :ledger-serial-num="selectedLedgers[0]"
        :selected-members="selectedMembers"
        :available-members="availableMembers"
        :readonly="isReadonlyMode"
        :initial-config="splitConfig"
        @update:split-config="handleSplitConfigUpdate"
      />

      <!-- 交易状态 -->
      <FormRow :label="t('financial.transaction.status')" required>
        <Select
          v-model="form.transactionStatus"
          v-has-value
          :options="availableTransactionStatuses"
          :disabled="isInstallmentTransactionFieldsDisabled || isReadonlyMode"
        />
      </FormRow>

      <!-- 分期选项 -->
      <div v-if="form.transactionType === 'Expense' && !isCurrentTransactionInstallment" class="flex items-center gap-4 mb-3">
        <Checkbox
          v-model="form.isInstallment"
          :label="t('financial.transaction.installment')"
          :disabled="isInstallmentFieldsDisabled || isReadonlyMode"
        />
      </div>

      <!-- 分期详情 -->
      <div v-if="form.isInstallment" class="installment-section">
        <!-- 分期计划已开始执行的提示 -->
        <div v-if="isInstallmentFieldsDisabled" class="installment-warning">
          <span class="warning-icon">!</span>
          <span class="warning-text">分期计划已开始执行，部分设置不可修改</span>
        </div>
        <FormRow :label="t('financial.transaction.totalPeriods')" required>
          <Input
            v-model.number="form.totalPeriods"
            type="number"
            :disabled="isInstallmentFieldsDisabled || isReadonlyMode"
          />
        </FormRow>

        <FormRow :label="t('financial.transaction.installmentAmount')" required>
          <Input
            :model-value="String(calculatedInstallmentAmount > 0 ? safeToFixed(calculatedInstallmentAmount) : '计算中...')"
            type="text"
            readonly
          >
            <template #prefix>
              ¥
            </template>
          </Input>
        </FormRow>

        <FormRow :label="t('financial.transaction.firstDueDate')" required>
          <Input
            v-model="firstDueDate"
            type="date"
            :disabled="isInstallmentFieldsDisabled || isReadonlyMode"
          />
        </FormRow>

        <FormRow :label="t('financial.transaction.relatedTransaction')" optional>
          <Input
            v-model="relatedTransactionSerialNum"
            type="text"
            :placeholder="t('common.misc.optional')"
          />
        </FormRow>

        <!-- 分期计划详情 -->
        <div v-if="installmentDetails" class="mt-4 p-4 border border-gray-200 dark:border-gray-700 rounded-lg bg-gray-50 dark:bg-gray-900">
          <div class="flex items-center justify-between mb-4">
            <h4 class="text-base font-semibold text-gray-900 dark:text-white">
              {{ t('financial.transaction.installmentPlan') }}
            </h4>
            <button
              v-if="hasMorePeriods"
              type="button"
              class="px-3 py-1.5 text-sm text-blue-600 dark:text-blue-400 hover:bg-blue-50 dark:hover:bg-blue-900/20 rounded-md transition-colors"
              @click="installmentManager.toggleExpanded()"
            >
              {{ isExpanded ? t('common.actions.collapse') : t('common.actions.expand') }}
            </button>
          </div>

          <div class="flex flex-col gap-3">
            <div
              v-for="(detail, index) in visibleDetails"
              :key="detail.period || index"
              class="p-3 rounded-lg border transition-all" :class="[
                detail.status === 'PAID' ? 'bg-green-50 dark:bg-green-900/10 border-green-200 dark:border-green-800' : '',
                detail.status === 'PENDING' ? 'bg-blue-50 dark:bg-blue-900/10 border-blue-200 dark:border-blue-800' : '',
                detail.status === 'OVERDUE' ? 'bg-red-50 dark:bg-red-900/10 border-red-200 dark:border-red-800' : '',
                !detail.status ? 'bg-white dark:bg-gray-800 border-gray-200 dark:border-gray-700' : '',
              ]"
            >
              <div class="flex items-start justify-between">
                <div class="flex-1">
                  <div class="flex items-center gap-2 mb-2">
                    <span class="text-sm font-medium text-gray-900 dark:text-white">第 {{ detail.period || (index + 1) }} 期</span>
                    <span
                      v-if="detail.status" class="px-2 py-0.5 text-xs rounded-full" :class="[
                        detail.status === 'PAID' ? 'bg-green-100 dark:bg-green-900/30 text-green-700 dark:text-green-400' : '',
                        detail.status === 'PENDING' ? 'bg-blue-100 dark:bg-blue-900/30 text-blue-700 dark:text-blue-400' : '',
                        detail.status === 'OVERDUE' ? 'bg-red-100 dark:bg-red-900/30 text-red-700 dark:text-red-400' : '',
                      ]"
                    >
                      {{ getStatusText(detail.status) }}
                    </span>
                  </div>
                  <div class="flex items-center gap-1.5 text-sm text-gray-600 dark:text-gray-400">
                    <span>📅</span>
                    <span>应还日:</span>
                    <span class="text-gray-900 dark:text-white font-medium">{{ detail.dueDate || '未设置' }}</span>
                  </div>
                </div>
                <div class="text-right">
                  <div class="text-lg font-semibold text-gray-900 dark:text-white">
                    ¥{{ detail.amount ? safeToFixed(detail.amount) : '0.00' }}
                  </div>
                  <div v-if="detail.status === 'PAID'" class="mt-2 flex flex-col gap-1">
                    <div class="flex items-center justify-end gap-1.5 text-xs text-green-600 dark:text-green-400">
                      <span>✓</span>
                      <span>入账:</span>
                      <span>{{ detail.paidDate || detail.dueDate || '日期未记录' }}</span>
                    </div>
                    <div v-if="detail.paidAmount" class="flex items-center justify-end gap-1.5 text-xs text-green-600 dark:text-green-400">
                      <span>💰</span>
                      <span>实付:</span>
                      <span>¥{{ safeToFixed(detail.paidAmount) }}</span>
                    </div>
                  </div>
                  <div v-else-if="detail.status === 'PENDING'" class="mt-2">
                    <span class="inline-flex items-center gap-1 px-2 py-1 text-xs bg-blue-100 dark:bg-blue-900/30 text-blue-700 dark:text-blue-400 rounded">
                      ⏳ 待入账
                    </span>
                  </div>
                  <div v-else-if="detail.status === 'OVERDUE'" class="mt-2">
                    <span class="inline-flex items-center gap-1 px-2 py-1 text-xs bg-red-100 dark:bg-red-900/30 text-red-700 dark:text-red-400 rounded">
                      ⚠️ 已逾期
                    </span>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <div class="mt-4 pt-4 border-t border-gray-200 dark:border-gray-700">
            <div class="flex items-center justify-between mb-3">
              <div class="flex gap-4">
                <div class="flex items-center gap-1.5 text-sm">
                  <span class="text-gray-600 dark:text-gray-400">已入账:</span>
                  <span class="font-medium text-green-600 dark:text-green-400">{{ paidPeriodsCount }} 期</span>
                </div>
                <div class="flex items-center gap-1.5 text-sm">
                  <span class="text-gray-600 dark:text-gray-400">待入账:</span>
                  <span class="font-medium text-blue-600 dark:text-blue-400">{{ pendingPeriodsCount }} 期</span>
                </div>
                <div class="flex items-center gap-1.5 text-sm">
                  <span class="text-gray-600 dark:text-gray-400">总期数:</span>
                  <span class="font-medium text-gray-900 dark:text-white">{{ totalPeriodsCount }} 期</span>
                </div>
              </div>
            </div>
            <div class="flex items-center justify-between">
              <strong class="text-base text-gray-900 dark:text-white">{{ t('financial.transaction.totalAmount') }}: ¥{{ safeToFixed(form.amount) }}</strong>
              <button
                v-if="hasMorePeriods"
                type="button"
                class="px-3 py-1.5 text-sm text-blue-600 dark:text-blue-400 hover:bg-blue-50 dark:hover:bg-blue-900/20 rounded-md transition-colors"
                @click="installmentManager.toggleExpanded()"
              >
                {{ isExpanded ? t('common.actions.collapse') : t('common.actions.expand') }}
              </button>
            </div>
          </div>
        </div>
      </div>

      <!-- 日期 -->
      <FormRow :label="t('date.transactionDate')" required :class="{ 'mt-6': form.isInstallment }">
        <DateTimePicker
          v-model="form.date"
          class="datetime-picker"
          format="yyyy-MM-dd HH:mm:ss"
          :disabled="isInstallmentTransactionFieldsDisabled || isReadonlyMode"
          :placeholder="t('common.selectDate')"
        />
      </FormRow>

      <!-- 备注 -->
      <FormRow full-width>
        <Textarea
          v-model="form.description"
          :rows="3"
          :max-length="1000"
          :placeholder="t('common.misc.remark')"
          :disabled="isReadonlyMode"
        />
      </FormRow>
    </form>
  </Modal>
</template>
