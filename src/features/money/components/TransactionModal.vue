<script setup lang="ts">
import BaseModal from '@/components/common/BaseModal.vue';
import DateTimePicker from '@/components/common/DateTimePicker.vue';
import FormRow from '@/components/common/FormRow.vue';
import CurrencySelector from '@/components/common/money/CurrencySelector.vue';
// 注意：CURRENCY_CNY 已移至 transactionFormUtils
import {
  TransactionStatusSchema,
  TransactionTypeSchema,
} from '@/schema/common';
import { useCategoryStore } from '@/stores/money';
import { lowercaseFirstLetter } from '@/utils/common';
import { DateUtils } from '@/utils/date';
import { Lg } from '@/utils/debugLog';
import { toast } from '@/utils/toast';
import { isInstallmentTransaction } from '@/utils/transaction';
import { useAccountFilter } from '../composables/useAccountFilter';
import { useInstallmentManagement } from '../composables/useInstallmentManagement';
import { getDefaultPaymentMethod, usePaymentMethods } from '../composables/usePaymentMethods';
import { useTransactionCategory } from '../composables/useTransactionCategory';
import { useTransactionLedgerLink } from '../composables/useTransactionLedgerLink';
import { useTransactionValidation } from '../composables/useTransactionValidation';
import { INSTALLMENT_CONSTANTS } from '../constants/transactionConstants';
import { handleAmountInput as handleAmountInputUtil } from '../utils/formUtils';
import { formatCurrency } from '../utils/money';
import { safeToFixed } from '../utils/numberUtils';
import { initializeFormData } from '../utils/transactionFormUtils';
import TransactionSplitSection from './TransactionSplitSection.vue';
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

  return props.transaction
    ? t('financial.transaction.editTransaction')
    : t(titles[props.type]);
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

// 支付方式管理
const {
  availablePaymentMethods,
  isPaymentMethodEditable: baseIsPaymentMethodEditable,
} = usePaymentMethods(
  computed(() => props.accounts),
  computed(() => form.value.accountSerialNum),
  computed(() => form.value.transactionType),
);

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

// 显示账本选择器
const showLedgerSelector = ref(false);
// 显示成员选择器
const showMemberSelector = ref(false);

// 注意：selectAccounts 已从 useAccountFilter 解构（原名 selectableAccounts）

// 注意：categoryMap 已从 categoryManager 解构

const isTransferReadonly = computed(() => {
  return !!(props.transaction && form.value.category === 'Transfer');
});

const isEditabled = computed<boolean>(() => !!props.transaction);
const isDisabled = computed<boolean>(() => isTransferReadonly.value || isEditabled.value);

// 注意：safeToFixed 已移至 utils/numberUtils.ts

// 注意：所有分期状态现在直接从 installmentManager 获取
// 例如：installmentManager.calculationResult.value
//       installmentManager.isCalculating.value
//       installmentManager.installmentDetails.value
//       installmentManager.planDetails.value
//       installmentManager.hasPaidInstallments.value

// 注意：直接使用 composable 提供的计算属性
// - installmentManager.paidPeriodsCount.value
// - installmentManager.pendingPeriodsCount.value
// - installmentManager.totalPeriodsCount.value

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
// 注意：使用 composable 方法
async function calculateInstallmentFromBackend() {
  // 使用 composable 的方法
  await installmentManager.calculateInstallment(
    form.value.amount,
    form.value.totalPeriods,
    form.value.firstDueDate || undefined,
    form.value.date,
  );

  // 注意：不需要同步，直接使用 installmentManager 的状态
}

// 加载分期计划详情（用于编辑模式）
// 注意：使用 composable 方法
async function loadInstallmentPlanDetails(planSerialNum: string) {
  await installmentManager.loadPlanBySerialNum(planSerialNum);
  // 同步数据（TODO: Phase 2.6 删除）
  if (installmentManager.planDetails.value) {
    processInstallmentPlanResponse(installmentManager.planDetails.value as any);
  }
}

// 加载分期计划详情（根据交易序列号）
// 注意：使用 composable 方法
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
    // 注意：数据已由 installmentManager 管理，这里只更新表单

    // 更新表单中的分期相关字段（如果有值才更新）
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

// 注意：calculatedInstallmentAmount 和 installmentDetails 已从 installmentManager 解构

// 检查交易是否有已完成的分期付款
// 注意：使用 composable 方法
async function checkPaidInstallments(transactionSerialNum: string) {
  // 使用 composable 的方法
  await installmentManager.checkPaidStatus(transactionSerialNum);
  // 注意：状态已由 installmentManager 管理
}

// 判断分期付款相关字段是否应该被禁用（直接使用 composable）
const isInstallmentFieldsDisabled = computed(() => {
  return isEditabled.value && hasPaidInstallments.value;
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

// 注意：分期统计属性已从 useInstallmentManagement 中解构
// paidPeriodsCount, pendingPeriodsCount, totalPeriodsCount 可直接在模板中使用

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

// 初始化：加载账本列表
onMounted(async () => {
  await loadAvailableLedgers();

  // 如果是编辑模式，加载现有的关联
  if (props.transaction) {
    try {
      const { ledgers, members } = await getTransactionLinks(props.transaction.serialNum);
      selectedLedgers.value = ledgers.map(l => l.serialNum);
      selectedMembers.value = members.map(m => m.serialNum);
      // 加载成员列表（基于已选择的账本）
      await loadAvailableMembers();

      // 恢复分摊配置
      if (props.transaction.splitConfig && props.transaction.splitConfig.enabled) {
        splitConfig.value = {
          enabled: true,
          splitType: props.transaction.splitConfig.splitType,
          members: props.transaction.splitConfig.members || [],
        };
      } else {
        splitConfig.value = {
          enabled: false,
        };
      }
    } catch (error) {
      Lg.e('TransactionModal', 'Failed to load transaction links:', error);
    }
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

// 监听账户变化，智能推荐账本和成员
watch(() => form.value.accountSerialNum, async (accountId, oldAccountId) => {
  // 只在创建模式下处理（编辑模式保持原有关联）
  if (!props.transaction) {
    // 如果账户被清空，清除所有关联
    if (!accountId) {
      selectedLedgers.value = [];
      selectedMembers.value = [];
      return;
    }

    // 账户切换时，获取新账户的推荐
    try {
      const { suggestedLedgers } = await getSmartSuggestions(accountId);

      // ✅ 账户切换时清除旧的账本和成员选择，避免数据不一致
      if (oldAccountId && oldAccountId !== accountId) {
        selectedLedgers.value = [];
        selectedMembers.value = [];
      }

      // ✅ 账本自动反显：如果账户属于家庭账本，自动选择
      if (suggestedLedgers.length > 0) {
        selectedLedgers.value = suggestedLedgers.map(l => l.serialNum);
        // Auto-selected ledgers for account
      } else {
        // 如果没有推荐的账本，确保清空选择
        selectedLedgers.value = [];
      }

      // ❌ 成员不自动选择：保持为空，让用户手动选择
      selectedMembers.value = [];
      // Members cleared for manual selection
    } catch (error) {
      Lg.e('TransactionModal', 'Failed to get smart suggestions:', error);
      // 发生错误时也清空选择，避免数据不一致
      selectedLedgers.value = [];
      selectedMembers.value = [];
    }
  }
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

// 注意：visibleDetails 已从 installmentManager 解构，直接使用

// 注意：hasMorePeriods 已从 installmentManager 解构，直接使用

// 注意：availablePaymentMethods 已从 usePaymentMethods 解构

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

const selectToAccounts = computed(() => {
  return selectAccounts.value.filter(account => account.serialNum !== form.value.accountSerialNum);
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

// 清空成员（别名）
function clearMembers() {
  clearMemberSelection();
}

async function handleSubmit() {
  if (isSubmitting.value) return;

  const amount = form.value.amount;
  const fromAccount = props.accounts.find(acc => acc.serialNum === form.value.accountSerialNum);

  // 转账验证
  if (form.value.category === TransactionTypeSchema.enum.Transfer) {
    const toAccount = props.accounts.find(acc => acc.serialNum === form.value.toAccountSerialNum);
    const result = validateTransfer(fromAccount, toAccount, amount);

    if (!result.valid) {
      toast.error(result.error || '转账验证失败');
      return;
    }

    isSubmitting.value = true;
    try {
      await emitTransfer(amount);
    } finally {
      isSubmitting.value = false;
    }
  } else {
    // 支出验证
    if (form.value.transactionType === TransactionTypeSchema.enum.Expense) {
      const result = validateExpense(fromAccount, amount);

      if (!result.valid) {
        toast.error(result.error || '支出验证失败');
        return;
      }
    }

    isSubmitting.value = true;
    try {
      await emitTransaction(amount);
    } finally {
      isSubmitting.value = false;
    }
  }
}

// 注意：parseBalance, canWithdraw, canDeposit 已移至 useTransactionValidation composable

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

// 注意：getDefaultTransaction 已移至 utils/transactionFormUtils.ts

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

// 监听账户变化，自动设置支付方式
watch(
  () => form.value.accountSerialNum,
  newAccountSerialNum => {
    const selectedAccount = props.accounts.find(acc => acc.serialNum === newAccountSerialNum);

    // 使用工具函数根据账户类型和交易类型自动设置支付方式
    form.value.paymentMethod = getDefaultPaymentMethod(
      selectedAccount,
      form.value.transactionType,
    );

    // 防止转账时来源账户和目标账户相同
    if (newAccountSerialNum === form.value.toAccountSerialNum) {
      form.value.toAccountSerialNum = '';
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
  <BaseModal
    :title="modalTitle"
    size="md"
    :confirm-loading="isSubmitting"
    :show-footer="!isReadonlyMode"
    @close="$emit('close')"
    @confirm="handleSubmit"
  >
    <form @submit.prevent="handleSubmit">
      <!-- 交易类型 -->
      <FormRow :label="t('financial.transaction.transType')" required>
        <div class="form-display">
          {{ form.transactionType === 'Income' ? t('financial.transaction.income')
            : form.transactionType === 'Expense' ? t('financial.transaction.expense')
              : t('financial.transaction.transfer') }}
        </div>
      </FormRow>

      <!-- 金额 -->
      <FormRow :label="t('financial.money')" required>
        <input
          v-model="form.amount"
          v-has-value
          type="number"
          class="modal-input-select w-full"
          :placeholder="t('common.placeholders.enterAmount')"
          :disabled="isInstallmentFieldsDisabled || isInstallmentTransactionFieldsDisabled || isReadonlyMode"
          step="0.01"
          required
          @input="handleAmountInput"
        >
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
        <select v-model="form.accountSerialNum" v-has-value class="modal-input-select w-full" required :disabled="isDisabled || isReadonlyMode">
          <option value="">
            {{ t('common.placeholders.selectAccount') }}
          </option>
          <option v-for="account in selectAccounts" :key="account.serialNum" :value="account.serialNum">
            {{ account.name }} ({{ formatCurrency(account.balance) }})
          </option>
        </select>
      </FormRow>

      <!-- 转入账户 -->
      <FormRow
        v-if="isTransferReadonly || form.transactionType === TransactionTypeSchema.enum.Transfer"
        :label="t('financial.transaction.toAccount')"
        required
      >
        <select v-model="form.toAccountSerialNum" v-has-value class="modal-input-select w-full" required :disabled="isDisabled">
          <option value="">
            {{ t('common.placeholders.selectAccount') }}
          </option>
          <option v-for="account in selectToAccounts" :key="account.serialNum" :value="account.serialNum">
            {{ account.name }} ({{ formatCurrency(account.balance) }})
          </option>
        </select>
      </FormRow>

      <!-- 支付渠道 -->
      <FormRow :label="t('financial.transaction.paymentMethod')" required>
        <select
          v-if="isPaymentMethodEditable"
          v-model="form.paymentMethod"
          v-has-value
          :disabled="isTransferReadonly"
          class="modal-input-select w-full"
          required
        >
          <option value="">
            {{ t('common.placeholders.selectOption') }}
          </option>
          <option v-for="method in availablePaymentMethods" :key="method" :value="method">
            {{ t(`financial.paymentMethods.${method.toLowerCase()}`) }}
          </option>
        </select>
        <div v-else class="form-display">
          {{ t(`financial.paymentMethods.${form.paymentMethod.toLowerCase()}`) }}
        </div>
      </FormRow>

      <!-- 分类 -->
      <FormRow :label="t('categories.category')" required>
        <select
          v-model="form.category"
          v-has-value
          class="modal-input-select w-full"
          required
          :disabled="isTransferReadonly || isInstallmentTransactionFieldsDisabled || isReadonlyMode"
        >
          <option value="">
            {{ t('common.placeholders.selectCategory') }}
          </option>
          <option v-for="[key, category] in categoryMap" :key="key" :value="category.name">
            {{ t(`common.categories.${lowercaseFirstLetter(category.name)}`) }}
          </option>
        </select>
      </FormRow>

      <!-- 子分类 -->
      <FormRow
        v-if="form.category && categoryMap.get(form.category)?.subs.length"
        :label="t('categories.subCategory')"
        optional
      >
        <select
          v-model="form.subCategory"
          v-has-value
          class="modal-input-select w-full"
          :disabled="isTransferReadonly || isInstallmentTransactionFieldsDisabled || isReadonlyMode"
        >
          <option value="">
            {{ t('common.placeholders.selectOption') }}
          </option>
          <option v-for="sub in categoryMap.get(form.category)?.subs" :key="sub" :value="sub">
            {{ t(`common.subCategories.${lowercaseFirstLetter(sub)}`) }}
          </option>
        </select>
      </FormRow>

      <!-- 关联账本 -->
      <div v-if="!isReadonlyMode" class="form-row">
        <label class="label-with-hint">
          关联账本
        </label>
        <div class="ledger-selector-compact">
          <div class="selector-row">
            <div v-if="selectedLedgers.length === 0" class="empty-selection">
              <LucideInbox class="empty-icon" />
              <span>未选择账本</span>
            </div>
            <div v-else class="selected-items-compact">
              <span class="selected-item">
                {{ availableLedgers.find(l => l.serialNum === selectedLedgers[0])?.name || selectedLedgers[0] }}
                <button
                  type="button"
                  class="remove-btn"
                  @click="selectedLedgers = selectedLedgers.filter(id => id !== selectedLedgers[0])"
                >
                  <LucideX />
                </button>
              </span>
              <span
                v-if="selectedLedgers.length > 1"
                class="more-count"
                :title="selectedLedgers.slice(1).map(id => availableLedgers.find(l => l.serialNum === id)?.name || id).join('\n')"
              >
                +{{ selectedLedgers.length - 1 }}
              </span>
            </div>
            <button
              type="button"
              class="btn-add-ledger btn-icon-only"
              :title="showLedgerSelector ? '收起' : '选择账本'"
              @click="showLedgerSelector = !showLedgerSelector"
            >
              <LucideChevronDown v-if="!showLedgerSelector" />
              <LucideChevronUp v-else />
            </button>
          </div>
        </div>
      </div>

      <!-- 账本选择下拉 -->
      <div v-if="!isReadonlyMode && showLedgerSelector" class="form-row">
        <label />
        <div class="selector-dropdown">
          <div class="dropdown-header">
            <span>选择账本</span>
            <button type="button" @click="showLedgerSelector = false">
              <LucideX />
            </button>
          </div>
          <div class="dropdown-content">
            <label
              v-for="ledger in availableLedgers"
              :key="ledger.serialNum"
              class="checkbox-item"
            >
              <input
                v-model="selectedLedgers"
                type="checkbox"
                :value="ledger.serialNum"
              >
              <span class="item-name">{{ ledger.name }}</span>
              <span class="item-type">{{ ledger.ledgerType }}</span>
            </label>
          </div>
        </div>
      </div>

      <!-- 分摊成员 -->
      <div v-if="!isReadonlyMode && selectedLedgers.length > 0" class="form-row">
        <label class="label-with-hint">
          分摊成员
        </label>
        <div class="member-selector-with-hint">
          <div class="member-selector-compact">
            <div class="selector-row">
              <div v-if="selectedMembers.length === 0" class="empty-selection">
                <LucideUsers class="empty-icon" />
                <span>未选择成员</span>
              </div>
              <div v-else class="selected-items-compact">
                <span class="selected-item">
                  {{ availableMembers.find(m => m.serialNum === selectedMembers[0])?.name || selectedMembers[0] }}
                  <button
                    type="button"
                    class="remove-btn"
                    @click="selectedMembers = selectedMembers.filter(id => id !== selectedMembers[0])"
                  >
                    <LucideX />
                  </button>
                </span>
                <span
                  v-if="selectedMembers.length > 1"
                  class="more-count"
                  :title="selectedMembers.slice(1).map(id => availableMembers.find(m => m.serialNum === id)?.name || id).join('\n')"
                >
                  +{{ selectedMembers.length - 1 }}
                </span>
              </div>
              <button
                type="button"
                class="btn-add-member btn-icon-only"
                :title="showMemberSelector ? '收起' : '选择成员'"
                @click="showMemberSelector = !showMemberSelector"
              >
                <LucideChevronDown v-if="!showMemberSelector" />
                <LucideChevronUp v-else />
              </button>
            </div>
          </div>
          <!-- 小字提示 -->
          <div v-if="selectedMembers.length === 0" class="member-hint-text">
            如不选择成员，则为个人交易
          </div>
        </div>
      </div>

      <!-- 成员选择下拉 -->
      <div v-if="!isReadonlyMode && selectedLedgers.length > 0 && showMemberSelector" class="form-row">
        <label />
        <div class="selector-dropdown">
          <div class="dropdown-header">
            <span>选择成员</span>
            <div class="quick-actions">
              <button
                v-if="availableMembers.length > 0"
                type="button"
                class="btn-quick"
                title="全选成员"
                @click="selectAllMembers"
              >
                <LucideUserPlus class="icon-sm" />
                全选
              </button>
              <button
                v-if="selectedMembers.length > 0"
                type="button"
                class="btn-quick"
                title="清空成员"
                @click="clearMembers"
              >
                <LucideX class="icon-sm" />
                清空
              </button>
              <button type="button" @click="showMemberSelector = false">
                <LucideX />
              </button>
            </div>
          </div>
          <div class="dropdown-content">
            <label
              v-for="member in availableMembers"
              :key="member.serialNum"
              class="checkbox-item"
            >
              <input
                v-model="selectedMembers"
                type="checkbox"
                :value="member.serialNum"
              >
              <span class="item-name">{{ member.name }}</span>
            </label>
          </div>
        </div>
      </div>

      <!-- 分摊设置 -->
      <TransactionSplitSection
        v-if="!isReadonlyMode && selectedLedgers.length > 0 && selectedMembers.length > 0 && form.amount > 0 && form.transactionType !== TransactionTypeSchema.enum.Transfer"
        :transaction-amount="form.amount"
        :ledger-serial-num="selectedLedgers[0]"
        :selected-members="selectedMembers"
        :available-members="availableMembers"
        :initial-config="splitConfig"
        @update:split-config="handleSplitConfigUpdate"
      />

      <!-- 交易状态 -->
      <FormRow :label="t('financial.transaction.status')" required>
        <select
          v-model="form.transactionStatus"
          v-has-value
          class="modal-input-select w-full"
          :disabled="isInstallmentTransactionFieldsDisabled || isReadonlyMode"
        >
          <option
            v-for="status in availableTransactionStatuses"
            :key="status.value"
            :value="status.value"
          >
            {{ status.label }}
          </option>
        </select>
      </FormRow>

      <!-- 分期选项 -->
      <div v-if="form.transactionType === 'Expense' && !isCurrentTransactionInstallment" class="form-row">
        <label class="checkbox-label">
          <input
            v-model="form.isInstallment"
            type="checkbox"
            :disabled="isInstallmentFieldsDisabled"
          >
          {{ t('financial.transaction.installment') }}
        </label>
      </div>

      <!-- 分期详情 -->
      <div v-if="form.isInstallment" class="installment-section">
        <!-- 分期计划已开始执行的提示 -->
        <div v-if="isInstallmentFieldsDisabled" class="installment-warning">
          <span class="warning-icon">!</span>
          <span class="warning-text">分期计划已开始执行，部分设置不可修改</span>
        </div>
        <FormRow :label="t('financial.transaction.totalPeriods')" required>
          <input
            v-model="form.totalPeriods"
            type="number"
            min="2"
            class="modal-input-select w-full"
            :disabled="isInstallmentFieldsDisabled"
          >
        </FormRow>

        <FormRow :label="t('financial.transaction.installmentAmount')" required>
          <input
            :value="safeToFixed(calculatedInstallmentAmount)"
            type="text"
            readonly
            class="modal-input-select w-full"
          >
        </FormRow>

        <FormRow :label="t('financial.transaction.firstDueDate')" required>
          <input
            v-model="form.firstDueDate"
            type="date"
            class="modal-input-select w-full"
            :disabled="isInstallmentFieldsDisabled"
          >
        </FormRow>

        <FormRow :label="t('financial.transaction.relatedTransaction')" optional>
          <input
            v-model="form.relatedTransactionSerialNum"
            type="text"
            class="modal-input-select w-full"
            :placeholder="t('common.misc.optional')"
          >
        </FormRow>

        <!-- 分期计划详情 -->
        <div v-if="installmentDetails" class="installment-plan">
          <div class="plan-header">
            <h4>{{ t('financial.transaction.installmentPlan') }}</h4>
            <button
              v-if="hasMorePeriods"
              type="button"
              class="toggle-btn"
              @click="installmentManager.toggleExpanded()"
            >
              {{ isExpanded ? t('common.actions.collapse') : t('common.actions.expand') }}
            </button>
          </div>

          <div class="plan-list">
            <div
              v-for="(detail, index) in visibleDetails"
              :key="detail.period || index"
              class="plan-item"
              :class="{ paid: detail.status === 'PAID', pending: detail.status === 'PENDING', overdue: detail.status === 'OVERDUE' }"
            >
              <div class="period-info">
                <div class="period-header">
                  <span class="period-label">第 {{ detail.period || (index + 1) }} 期</span>
                  <span v-if="detail.status" class="status-text" :class="`status-${detail.status.toLowerCase()}`">
                    {{ getStatusText(detail.status) }}
                  </span>
                </div>
                <div class="due-date-wrapper">
                  <span class="due-date-icon">📅</span>
                  <span class="due-date-label">应还日:</span>
                  <span class="due-date-value">{{ detail.dueDate || '未设置' }}</span>
                </div>
              </div>
              <div class="amount-info">
                <span class="amount-label">¥{{ detail.amount ? safeToFixed(detail.amount) : '0.00' }}</span>
                <div v-if="detail.status === 'PAID'" class="payment-details">
                  <div class="paid-date-wrapper">
                    <span class="paid-icon">✓</span>
                    <span class="paid-label">入账:</span>
                    <span class="paid-value">{{ detail.paidDate || detail.dueDate || '日期未记录' }}</span>
                  </div>
                  <div v-if="detail.paidAmount" class="paid-amount-wrapper">
                    <span class="amount-icon">💰</span>
                    <span class="amount-paid-label">实付:</span>
                    <span class="amount-paid-value">¥{{ safeToFixed(detail.paidAmount) }}</span>
                  </div>
                </div>
                <div v-else-if="detail.status === 'PENDING'" class="pending-info">
                  <span class="status-badge pending-badge">⏳ 待入账</span>
                </div>
                <div v-else-if="detail.status === 'OVERDUE'" class="overdue-info">
                  <span class="status-badge overdue-badge">⚠️ 已逾期</span>
                </div>
              </div>
            </div>
          </div>

          <div class="plan-summary">
            <div class="summary-stats">
              <div class="stat-item">
                <span class="stat-label">已入账:</span>
                <span class="stat-value paid">{{ paidPeriodsCount }} 期</span>
              </div>
              <div class="stat-item">
                <span class="stat-label">待入账:</span>
                <span class="stat-value pending">{{ pendingPeriodsCount }} 期</span>
              </div>
              <div class="stat-item">
                <span class="stat-label">总期数:</span>
                <span class="stat-value">{{ totalPeriodsCount }} 期</span>
              </div>
            </div>
            <div class="total-amount">
              <strong>{{ t('financial.transaction.totalAmount') }}: ¥{{ safeToFixed(form.amount) }}</strong>
              <button
                v-if="hasMorePeriods"
                type="button"
                class="toggle-btn"
                @click="installmentManager.toggleExpanded()"
              >
                {{ isExpanded ? t('common.actions.collapse') : t('common.actions.expand') }}
              </button>
            </div>
          </div>
        </div>
      </div>

      <!-- 日期 -->
      <FormRow :label="t('date.transactionDate')" required>
        <DateTimePicker
          v-model="form.date"
          class="datetime-picker"
          format="yyyy-MM-dd HH:mm:ss"
          :disabled="isInstallmentTransactionFieldsDisabled || isReadonlyMode"
          :placeholder="t('common.selectDate')"
        />
      </FormRow>

      <!-- 备注 -->
      <textarea
        v-model="form.description"
        class="modal-input-select w-full"
        rows="3"
        :placeholder="`${t('common.misc.remark')}（${t('common.misc.optional')}）`"
        :disabled="isReadonlyMode"
      />
    </form>
  </BaseModal>
</template>

<style scoped lang="postcss">
/* CurrencySelector 样式统一 */
:deep(.currency-selector) {
  margin-bottom: 0 !important;
}

:deep(.currency-selector__select) {
  border: 2px solid var(--color-base-300) !important;
  border-radius: 0.5rem !important;
  background-color: var(--color-base-100) !important;
  transition: all 0.2s ease !important;
}

:deep(.currency-selector__select:hover:not(:disabled)) {
  background-color: var(--color-base-200) !important;
}

:deep(.currency-selector__select:focus) {
  border-color: var(--color-primary) !important;
  box-shadow: 0 0 0 3px oklch(from var(--color-primary) l c h / 0.1) !important;
}

:deep(.currency-selector__select:disabled) {
  background-color: var(--color-base-300) !important;
  cursor: not-allowed !important;
}

.checkbox-label {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  cursor: pointer;
}

.installment-warning {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.75rem;
  margin-bottom: 1rem;
  background-color: color-mix(in oklch, var(--color-warning) 10%, transparent);
  border: 1px solid color-mix(in oklch, var(--color-warning) 30%, transparent);
  border-radius: 0.375rem;
  font-size: 0.875rem;
}

.warning-icon {
  font-size: 1rem;
}

.warning-text {
  color: var(--color-warning);
  font-weight: 500;
}

.installment-section {
  background: linear-gradient(to bottom, var(--color-base-100), var(--color-base-200));
  border: 2px solid var(--color-primary-soft);
  border-radius: 0.75rem;
  padding: 1.25rem;
  margin: 1rem 0;
  box-shadow: var(--shadow-sm);
  transition: all 0.3s ease;
}

.installment-section:hover {
  box-shadow: var(--shadow-md);
  border-color: var(--color-primary);
}

.installment-section .form-row {
  margin-bottom: 0.75rem;
}

.installment-section .form-row:last-child {
  margin-bottom: 0;
}

.installment-plan {
  margin-top: 0.75rem;
  padding: 0.75rem;
  background: var(--color-base-100);
  border-radius: 0.5rem;
  border: 1px solid var(--color-base-300);
}

.plan-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 0.5rem;
}

.plan-header h4 {
  margin: 0;
  font-size: 0.8125rem;
  font-weight: 600;
  color: var(--color-base-content);
}

.plan-list {
  margin-bottom: 0.75rem;
}

.plan-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 0.375rem 0.5rem;
  border-bottom: 1px solid var(--color-base-200);
}

.plan-item:last-child {
  border-bottom: none;
}

.period-info {
  display: flex;
  flex-direction: column;
  gap: 0.125rem;
}

.period-label {
  font-size: 0.8125rem;
  color: var(--color-base-content);
  font-weight: 500;
}

.due-date-wrapper {
  display: flex;
  align-items: center;
  gap: 0.2rem;
  padding: 0.15rem 0.4rem;
  background: color-mix(in oklch, var(--color-info) 8%, transparent);
  border-radius: 0.2rem;
  font-size: 0.6875rem;
}

.due-date-icon {
  font-size: 0.75rem;
}

.due-date-label {
  color: var(--color-info);
  font-weight: 500;
}

.due-date-value {
  color: var(--color-base-content);
  font-family: 'SF Mono', Monaco, 'Courier New', monospace;
  font-weight: 500;
}

.amount-label {
  font-size: 0.8125rem;
  font-weight: 600;
  color: var(--color-primary);
}

/* 入账详情样式 */
.payment-details {
  display: flex;
  flex-direction: column;
  gap: 0.2rem;
  font-size: 0.6875rem;
}

.paid-date-wrapper,
.paid-amount-wrapper {
  display: flex;
  align-items: center;
  gap: 0.2rem;
}

.paid-icon,
.amount-icon {
  font-size: 0.75rem;
}

.paid-icon {
  color: var(--color-success);
  font-weight: bold;
}

.paid-label,
.amount-paid-label {
  color: var(--color-success);
  font-weight: 500;
}

.paid-value,
.amount-paid-value {
  color: var(--color-base-content);
  font-family: 'SF Mono', Monaco, 'Courier New', monospace;
  font-weight: 500;
}

/* 状态徽章样式 */
.status-badge {
  display: inline-flex;
  align-items: center;
  gap: 0.2rem;
  padding: 0.15rem 0.4rem;
  border-radius: 0.2rem;
  font-size: 0.6875rem;
  font-weight: 500;
}

.pending-badge {
  background: color-mix(in oklch, var(--color-warning) 15%, transparent);
  color: var(--color-warning);
  border: 1px solid color-mix(in oklch, var(--color-warning) 30%, transparent);
}

.overdue-badge {
  background: color-mix(in oklch, var(--color-error) 15%, transparent);
  color: var(--color-error);
  border: 1px solid color-mix(in oklch, var(--color-error) 30%, transparent);
}

/* 分期计划状态样式 */
.plan-item.paid {
  background-color: color-mix(in oklch, var(--color-success) 8%, transparent);
  border: 1px solid color-mix(in oklch, var(--color-success) 25%, transparent);
  border-radius: 0.25rem;
  padding: 0.375rem 0.5rem;
  margin: 0.2rem 0;
}

.plan-item.pending {
  background-color: color-mix(in oklch, var(--color-warning) 8%, transparent);
  border: 1px solid color-mix(in oklch, var(--color-warning) 25%, transparent);
  border-radius: 0.25rem;
  padding: 0.375rem 0.5rem;
  margin: 0.2rem 0;
}

.plan-item.overdue {
  background-color: color-mix(in oklch, var(--color-error) 8%, transparent);
  border: 1px solid color-mix(in oklch, var(--color-error) 25%, transparent);
  border-radius: 0.25rem;
  padding: 0.375rem 0.5rem;
  margin: 0.2rem 0;
}

.status-badge {
  font-size: 0.625rem;
  padding: 0.125rem 0.375rem;
  border-radius: 0.25rem;
  font-weight: 500;
  text-transform: uppercase;
  letter-spacing: 0.025em;
}

.status-badge.status-paid {
  background-color: var(--color-success);
  color: var(--color-base-content);
}

.status-badge.status-pending {
  background-color: var(--color-warning);
  color: var(--color-base-content);
}

.status-badge.status-overdue {
  background-color: var(--color-error);
  color: var(--color-base-content);
}

.period-header {
  display: flex;
  align-items: center;
  gap: 0.375rem;
  margin-bottom: 0.125rem;
}

.status-text {
  font-size: 0.6875rem;
  font-weight: 500;
  padding: 0.1rem 0.4rem;
  border-radius: 0.2rem;
  border: 1px solid;
}

.status-text.status-paid {
  color: var(--color-success);
  background-color: rgba(var(--color-success-rgb), 0.1);
  border-color: var(--color-success);
}

.status-text.status-pending {
  color: var(--color-warning);
  background-color: rgba(var(--color-warning-rgb), 0.1);
  border-color: var(--color-warning);
}

.status-text.status-overdue {
  color: var(--color-error);
  background-color: rgba(var(--color-error-rgb), 0.1);
  border-color: var(--color-error);
}

.amount-info {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  gap: 0.15rem;
}

.payment-details {
  display: flex;
  flex-direction: column;
  align-items: flex-end;
  gap: 0.125rem;
}

.paid-date {
  font-size: 0.625rem;
  color: var(--color-success);
  font-style: italic;
}

.paid-amount {
  font-size: 0.625rem;
  color: var(--color-success);
  font-weight: 500;
}

.pending-info {
  display: flex;
  align-items: center;
}

.pending-text {
  font-size: 0.625rem;
  color: var(--color-warning);
  font-weight: 500;
}

.overdue-info {
  display: flex;
  align-items: center;
}

.overdue-text {
  font-size: 0.625rem;
  color: var(--color-error);
  font-weight: 500;
}

.first-due-date-row {
  margin-top: 1.5rem !important;
}

.plan-summary {
  padding-top: 0.5rem;
  border-top: 1px solid var(--color-base-300);
  color: var(--color-base-content);
}

.summary-stats {
  display: flex;
  justify-content: space-between;
  margin-bottom: 0.75rem;
  padding: 0.5rem;
  background-color: var(--color-base-100);
  border-radius: 0.375rem;
}

.stat-item {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.25rem;
}

.stat-label {
  font-size: 0.75rem;
  color: var(--color-base-content-soft);
}

.stat-value {
  font-size: 0.875rem;
  font-weight: 600;
}

.stat-value.paid {
  color: var(--color-success);
}

.stat-value.pending {
  color: var(--color-warning);
}

.total-amount {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding-top: 0.5rem;
  border-top: 1px solid var(--color-base-200);
}

.toggle-btn {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  background: transparent;
  border: 1px solid var(--color-base-300);
  border-radius: 0.375rem;
  padding: 0.5rem 1rem;
  color: var(--color-base-content);
  font-size: 0.875rem;
  cursor: pointer;
  transition: all 0.2s ease;
}

.toggle-btn:hover {
  background: var(--color-base-100);
  border-color: var(--color-primary);
  color: var(--color-primary);
}

.toggle-icon {
  width: 1rem;
  height: 1rem;
  transition: transform 0.2s ease;
}

.toggle-icon.expanded {
  transform: rotate(180deg);
}

.icon {
  width: 1.5rem;
  height: 1.5rem;
}

/* ==================== 账本和成员选择器样式 ==================== */
.label-with-hint {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.label-hint {
  font-size: 0.75rem;
  color: var(--color-neutral);
  font-weight: normal;
}

.form-row .ledger-selector-compact,
.form-row .member-selector-compact {
  display: flex;
  flex-direction: column;
  gap: 0;
  padding: 0.75rem;
  border: 1px solid var(--color-base-300);
  border-radius: 0.375rem;
  background: var(--color-base-200);
  flex: 1;
}

.form-row .member-selector-with-hint {
  flex: 1;
}

.selector-row {
  display: flex;
  flex-direction: row;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
  flex-wrap: nowrap;
  width: 100%;
}

.empty-selection {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  color: var(--color-neutral);
  font-size: 0.875rem;
  flex: 0 1 auto;
  white-space: nowrap;
}

.empty-icon {
  width: 1rem;
  height: 1rem;
}

.selected-items {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
  flex: 0 1 auto;
  min-width: 0;
}

.selected-items-compact {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  flex: 0 1 auto;
  min-width: 0;
}

.selected-item {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.25rem 0.5rem;
  background: var(--color-primary-soft);
  color: var(--color-primary);
  border-radius: 0.25rem;
  font-size: 0.875rem;
}

.more-count {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  min-width: 1.5rem;
  height: 1.5rem;
  padding: 0 0.375rem;
  background: var(--color-neutral);
  color: var(--color-neutral-content);
  border-radius: 0.75rem;
  font-size: 0.75rem;
  font-weight: 600;
  cursor: help;
  transition: all 0.2s;
}

.more-count:hover {
  background: var(--color-primary);
  color: var(--color-primary-content);
  transform: scale(1.1);
}

.remove-btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  padding: 0;
  background: transparent;
  border: none;
  color: var(--color-primary);
  cursor: pointer;
  width: 1rem;
  height: 1rem;
}

.remove-btn:hover {
  color: var(--color-error);
}

.btn-add-ledger,
.btn-add-member {
  display: inline-flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.5rem 0.75rem;
  background: var(--color-base-100);
  border: 1px dashed var(--color-base-300);
  border-radius: 0.25rem;
  color: var(--color-base-content);
  font-size: 0.875rem;
  cursor: pointer;
  transition: all 0.2s;
  flex-shrink: 0;
  white-space: nowrap;
}

.btn-add-ledger:hover,
.btn-add-member:hover {
  border-color: var(--color-primary);
  color: var(--color-primary);
  background: var(--color-primary-soft);
}

.btn-icon-only {
  padding: 0.5rem;
  min-width: 2rem;
  min-height: 2rem;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  border-radius: 0.375rem;
}

.btn-icon-only svg {
  width: 1.25rem;
  height: 1.25rem;
}

.selector-dropdown {
  width: 100%;
  padding: 0;
  background: var(--color-base-100);
  border: 1px solid var(--color-base-300);
  border-radius: 0.375rem;
  box-shadow: var(--shadow-md);
  max-height: 300px;
  overflow: hidden;
  display: flex;
  flex-direction: column;
}

/* 成员选择器包装容器 */
.member-selector-with-hint {
  display: flex;
  flex-direction: column;
  width: 100%;
  gap: 0;
}

.member-selector-with-hint .member-selector-compact {
  width: 100%;
}

/* 成员小字提示 */
.member-hint-text {
  font-size: 0.75rem;
  color: var(--color-base-content-soft);
  margin-top: 0.375rem;
  padding-left: 0.25rem;
}

.dropdown-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0.75rem 1rem;
  border-bottom: 1px solid var(--color-base-300);
  font-weight: 500;
  background: var(--color-base-200);
  color: var(--color-base-content);
}

/* 快捷操作按钮容器 */
.dropdown-header .quick-actions {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.dropdown-header button {
  background: transparent;
  border: none;
  cursor: pointer;
  color: var(--color-neutral);
  padding: 0.25rem;
  display: flex;
  align-items: center;
  transition: color 0.2s;
}

.dropdown-header button:hover {
  color: var(--color-error);
}

/* 快捷操作按钮 */
.btn-quick {
  display: inline-flex;
  align-items: center;
  gap: 0.375rem;
  padding: 0.375rem 0.75rem;
  background: var(--color-primary-soft);
  border: 1px solid var(--color-primary);
  border-radius: 0.375rem;
  color: var(--color-primary);
  font-size: 0.8125rem;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s;
}

.btn-quick:hover {
  background: var(--color-primary);
  color: var(--color-primary-content);
  transform: translateY(-1px);
  box-shadow: var(--shadow-sm);
}

.btn-quick:active {
  transform: translateY(0);
}

.btn-quick .icon-sm {
  width: 0.875rem;
  height: 0.875rem;
}

.dropdown-content {
  overflow-y: auto;
  max-height: 240px;
  background: var(--color-base-100);
}

.checkbox-item {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.75rem 1rem;
  cursor: pointer;
  transition: background 0.2s;
  background: var(--color-base-100);
}

.checkbox-item:hover {
  background: var(--color-base-200);
}

.checkbox-item input[type="checkbox"] {
  width: 1rem;
  height: 1rem;
  cursor: pointer;
}

.item-name {
  flex: 1;
  font-size: 0.875rem;
  color: var(--color-base-content);
}

.item-type,
.item-role {
  font-size: 0.75rem;
  padding: 0.125rem 0.5rem;
  background: var(--color-base-300);
  border-radius: 0.25rem;
  color: var(--color-base-content);
}

/* ==================== 表单行横向布局（用于复杂区块） ==================== */
.form-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 0.75rem;
  gap: 1rem;
}

.form-row label {
  font-size: 0.875rem;
  font-weight: 500;
  margin-bottom: 0;
  flex: 0 0 auto;
  width: 6rem;
  min-width: 6rem;
  white-space: nowrap;
}

/* 只读显示样式 */
.form-display {
  padding: 0.625rem 0.875rem;
  border-radius: 0.5rem;
  background-color: var(--color-base-200);
  color: var(--color-neutral);
  font-size: 0.875rem;
  font-weight: 600;
}

/* 移动端响应式布局 - 保持同一行显示 */
@media (max-width: 768px) {
  .form-row {
    flex-direction: row;
    align-items: center;
    gap: 0.5rem;
  }
  .form-row label {
    flex: 0 0 auto;
    min-width: 4rem;
    width: 4rem;
    white-space: nowrap;
    font-size: 0.8rem;
  }

  /* 选择器容器移动端优化 */
  .form-row .ledger-selector-compact,
  .form-row .member-selector-compact {
    flex: 1;
    padding: 0.5rem;
  }

  .form-row .member-selector-with-hint {
    flex: 1;
  }

  /* 选择器行移动端优化 */
  .selector-row {
    gap: 0.5rem;
  }

  /* 空状态文字缩小 */
  .empty-selection {
    font-size: 0.75rem;
  }

  /* 选中项文字缩小 */
  .selected-item {
    font-size: 0.75rem;
    padding: 0.125rem 0.375rem;
  }

  /* 更多计数徽章缩小 */
  .more-count {
    min-width: 1.25rem;
    height: 1.25rem;
    font-size: 0.625rem;
  }

  /* 按钮触摸区域优化 */
  .btn-add-ledger,
  .btn-add-member {
    min-width: 2.5rem;
    min-height: 2.5rem;
    padding: 0.625rem;
  }

  .btn-icon-only {
    min-width: 2.5rem;
    min-height: 2.5rem;
    padding: 0.625rem;
  }

  .btn-icon-only svg {
    width: 1rem;
    height: 1rem;
  }

  /* 下拉弹窗移动端优化 */
  .selector-dropdown {
    max-height: 250px;
  }

  .dropdown-content {
    max-height: 190px;
  }

  /* 复选框项触摸区域优化 */
  .checkbox-item {
    padding: 1rem;
    font-size: 0.875rem;
  }

  .checkbox-item input[type="checkbox"] {
    width: 1.25rem;
    height: 1.25rem;
  }

  /* 移除按钮触摸区域优化 */
  .remove-btn {
    width: 1.25rem;
    height: 1.25rem;
    padding: 0.125rem;
  }
}

.textarea-max {
  max-width: 400px;
  width: 100%;
  box-sizing: border-box;
}
</style>
