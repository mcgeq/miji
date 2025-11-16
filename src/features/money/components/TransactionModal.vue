<script setup lang="ts">
import DateTimePicker from '@/components/common/DateTimePicker.vue';
import CurrencySelector from '@/components/common/money/CurrencySelector.vue';
import { CURRENCY_CNY } from '@/constants/moneyConst';
import {
  TransactionStatusSchema,
  TransactionTypeSchema,
} from '@/schema/common';
import { AccountTypeSchema, PaymentMethodSchema } from '@/schema/money';
import { useCategoryStore } from '@/stores/money';
import { invokeCommand } from '@/types/api';
import { lowercaseFirstLetter } from '@/utils/common';
import { DateUtils } from '@/utils/date';
import { Lg } from '@/utils/debugLog';
import { toast } from '@/utils/toast';
import { isInstallmentTransaction } from '@/utils/transaction';
import { useTransactionLedgerLink } from '../composables/useTransactionLedgerLink';
import { formatCurrency } from '../utils/money';
import type {
  TransactionType,
} from '@/schema/common';
import type {
  Account,
  InstallmentCalculationRequest,
  InstallmentCalculationResponse,
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

const selectAccounts = computed(() => {
  if (props.transaction?.category === 'Transfer') {
    return props.accounts.filter(account => account.isActive);
  }
  if (props.type === TransactionTypeSchema.enum.Income) {
    return props.accounts.filter(account => account.type !== AccountTypeSchema.enum.CreditCard && account.isActive);
  }
  return props.accounts.filter(account => account.isActive);
});

const trans = props.transaction || getDefaultTransaction(props.type, props.accounts);

const form = ref<Transaction>({
  ...trans,
  // 确保 amount 是数字类型
  amount: typeof trans.amount === 'string' ? Number.parseFloat(trans.amount) : (trans.amount || 0),
  currency: trans.currency || CURRENCY_CNY,
  category: props.type === TransactionTypeSchema.enum.Transfer ? 'Transfer' : 'other',
  refundAmount: 0,
  toAccountSerialNum: '',
  date: trans.date || DateUtils.getLocalISODateTimeWithOffset(),
  // 分期相关字段
  isInstallment: false,
  firstDueDate: undefined,
  totalPeriods: 0,
  remainingPeriods: 0,
  installmentAmount: 0,
  remainingPeriodsAmount: 0,
  installmentPlanSerialNum: null,
});

const categoryMap = computed(() => {
  const map = new Map<string, { name: string; subs: string[] }>();
  categoryStore.subCategories.forEach(sub => {
    if (form.value.transactionType === 'Income') {
      const allowedCategories = ['Salary', 'Investment', 'Savings', 'Gift'];
      if (allowedCategories.includes(sub.categoryName)) {
        if (!map.has(sub.categoryName)) {
          map.set(sub.categoryName, { name: sub.categoryName, subs: [] });
        }
        map.get(sub.categoryName)!.subs.push(sub.name);
      }
    } else if (form.value.transactionType === 'Transfer') {
      if (sub.categoryName === 'Transfer') {
        if (!map.has('Transfer')) {
          map.set('Transfer', { name: 'Transfer', subs: [] });
        }
        map.get('Transfer')!.subs.push(sub.name);
      }
    } else {
      if (!map.has(sub.categoryName)) {
        map.set(sub.categoryName, { name: sub.categoryName, subs: [] });
      }
      map.get(sub.categoryName)!.subs.push(sub.name);
    }
  });
  return map;
});

const isTransferReadonly = computed(() => {
  return !!(props.transaction && form.value.category === 'Transfer');
});

const isEditabled = computed<boolean>(() => !!props.transaction);
const isDisabled = computed<boolean>(() => isTransferReadonly.value || isEditabled.value);

// 安全的数字格式化函数
function safeToFixed(value: any, decimals: number = 2): string {
  const numValue = typeof value === 'string' ? Number.parseFloat(value) : value;
  return Number.isNaN(numValue) ? '0.00' : numValue.toFixed(decimals);
}

// 后端计算结果的响应式数据（用于创建交易时）
const installmentCalculationResult = ref<InstallmentCalculationResponse | null>(null);
const isCalculatingInstallment = ref(false);

// 存储原始的分期详情数据（用于统计计算）
const rawInstallmentDetails = ref<any[]>([]);

// 分期计划详情数据（用于编辑交易时）
const installmentPlanDetails = ref<InstallmentPlanResponse | null>(null);

// 调用后端API计算分期金额
async function calculateInstallmentFromBackend() {
  if (!form.value.isInstallment || form.value.totalPeriods <= 0 || form.value.amount <= 0) {
    installmentCalculationResult.value = null;
    return;
  }

  try {
    isCalculatingInstallment.value = true;

    const request: InstallmentCalculationRequest = {
      total_amount: form.value.amount,
      total_periods: form.value.totalPeriods,
      first_due_date: form.value.firstDueDate
        ? DateUtils.formatDateOnly(new Date(form.value.firstDueDate))
        : DateUtils.formatDateOnly(new Date(form.value.date)),
    };

    const response = await invokeCommand<InstallmentCalculationResponse>('installment_calculate', {
      data: request,
    });

    // 确保每个detail都有status字段
    if (response.details) {
      response.details = response.details.map(detail => ({
        ...detail,
        status: detail.status || 'PENDING', // 如果没有status字段，默认为PENDING
      }));
    }
    installmentCalculationResult.value = response;
  } catch (error) {
    console.error('计算分期金额失败:', error);
    toast.error('计算分期金额失败');
    installmentCalculationResult.value = null;
  } finally {
    isCalculatingInstallment.value = false;
  }
}

// 加载分期计划详情（用于编辑模式）
async function loadInstallmentPlanDetails(planSerialNum: string) {
  try {
    const response = await invokeCommand<InstallmentPlanResponse>('installment_plan_get', {
      planSerialNum,
    });
    if (response && response.details) {
      // 存储原始数据用于统计计算
      rawInstallmentDetails.value = response.details;
      // 存储分期计划详情数据
      installmentPlanDetails.value = response;

      // 更新表单中的分期相关字段
      form.value.totalPeriods = response.total_periods;
      form.value.remainingPeriods = response.total_periods;
      form.value.installmentAmount = Number(response.installment_amount);
      form.value.firstDueDate = response.first_due_date;
    }
  } catch (error) {
    Lg.e('加载分期计划详情失败:', error);
    toast.error('加载分期计划详情失败');
  }
}

// 计算每期金额（用于显示在输入框中）
const calculatedInstallmentAmount = computed(() => {
  // 编辑模式：使用分期计划详情数据
  if (installmentPlanDetails.value) {
    return Number(installmentPlanDetails.value.installment_amount) || 0;
  }
  // 创建模式：使用计算结果数据
  return installmentCalculationResult.value?.installment_amount || 0;
});

// 获取分期金额详情（用于显示）
const installmentDetails = computed(() => {
  // 编辑模式：使用分期计划详情数据
  if (installmentPlanDetails.value && installmentPlanDetails.value.details) {
    return installmentPlanDetails.value.details.map(detail => ({
      period: detail.period_number,
      amount: Number(safeToFixed(detail.amount)),
      dueDate: detail.due_date,
      status: detail.status || 'PENDING', // 确保有status字段
      paidDate: detail.paid_date,
      paidAmount: detail.paid_amount,
    }));
  }
  // 创建模式：使用计算结果数据
  if (installmentCalculationResult.value && installmentCalculationResult.value.details) {
    return installmentCalculationResult.value.details.map(detail => ({
      period: detail.period,
      amount: Number(safeToFixed(detail.amount)),
      dueDate: detail.due_date,
      status: detail.status || 'PENDING', // 确保有status字段
      paidDate: detail.paid_date,
      paidAmount: detail.paid_amount,
    }));
  }
  return null;
});

// 后端查询是否有已完成的分期付款
const hasPaidInstallmentsFromBackend = ref(false);

// 检查交易是否有已完成的分期付款
async function checkPaidInstallments(transactionSerialNum: string) {
  if (!transactionSerialNum) {
    hasPaidInstallmentsFromBackend.value = false;
    return;
  }

  try {
    const response = await invokeCommand<boolean>('installment_has_paid', {
      transactionSerialNum,
    });
    hasPaidInstallmentsFromBackend.value = response;
  } catch (error) {
    console.error('检查分期付款状态失败:', error);
    hasPaidInstallmentsFromBackend.value = false;
  }
}

// 判断分期付款相关字段是否应该被禁用
const isInstallmentFieldsDisabled = computed(() => {
  return isEditabled.value && hasPaidInstallmentsFromBackend.value;
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

// 获取已入账期数
function getPaidPeriodsCount(): number {
  // 如果是创建模式且勾选了分期付款，返回0（因为还没有入账）
  if (form.value.isInstallment && !props.transaction) {
    return 0;
  }

  // 如果是编辑模式且勾选了分期付款
  if (form.value.isInstallment && props.transaction) {
    // 如果还没有入账，返回0
    if (!hasPaidInstallmentsFromBackend.value) {
      return 0;
    }
    // 如果已经入账，使用后端数据
    if (rawInstallmentDetails.value && rawInstallmentDetails.value.length > 0) {
      const paidCount = rawInstallmentDetails.value.filter(detail => detail.status === 'PAID').length;
      return paidCount;
    }
  }

  return 0;
}

// 获取待入账期数
function getPendingPeriodsCount(): number {
  // 如果是创建模式且勾选了分期付款，返回总期数（因为都待入账）
  if (form.value.isInstallment && !props.transaction) {
    return form.value.totalPeriods || 0;
  }

  // 如果是编辑模式且勾选了分期付款
  if (form.value.isInstallment && props.transaction) {
    // 如果还没有入账，使用表单中的总期数（因为都待入账）
    if (!hasPaidInstallmentsFromBackend.value) {
      return form.value.totalPeriods || 0;
    }
    // 如果已经入账，使用后端数据
    if (rawInstallmentDetails.value && rawInstallmentDetails.value.length > 0) {
      const pendingCount = rawInstallmentDetails.value.filter(detail => detail.status === 'PENDING' || detail.status === 'OVERDUE').length;
      return pendingCount;
    }
  }

  return 0;
}

// 获取总期数
function getTotalPeriodsCount(): number {
  // 如果是创建模式且勾选了分期付款，使用表单中的总期数
  if (form.value.isInstallment && !props.transaction) {
    return form.value.totalPeriods || 0;
  }

  // 如果是编辑模式且勾选了分期付款
  if (form.value.isInstallment && props.transaction) {
    // 如果还没有入账，使用表单中的总期数
    if (!hasPaidInstallmentsFromBackend.value) {
      return form.value.totalPeriods || 0;
    }
    // 如果已经入账，使用后端数据
    if (rawInstallmentDetails.value && rawInstallmentDetails.value.length > 0) {
      return rawInstallmentDetails.value.length;
    }
  }

  return 0;
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
watch(() => form.value.accountSerialNum, async accountId => {
  if (accountId && !props.transaction) {
    // 只在创建模式下自动推荐
    try {
      const { suggestedLedgers } = await getSmartSuggestions(accountId);

      // ✅ 账本自动反显：如果账户属于家庭账本，自动选择
      if (selectedLedgers.value.length === 0 && suggestedLedgers.length > 0) {
        selectedLedgers.value = suggestedLedgers.map(l => l.serialNum);
        // Auto-selected ledgers for account
      }

      // ❌ 成员不自动选择：保持为空，让用户手动选择
      // 清空之前的选择，避免账户切换时保留旧的成员
      selectedMembers.value = [];
      // Members cleared for manual selection
    } catch (error) {
      Lg.e('TransactionModal', 'Failed to get smart suggestions:', error);
    }
  }
});

// 监听分期选项变化
watch(() => form.value.isInstallment, newValue => {
  if (newValue) {
    // 启用分期时，设置默认值
    form.value.totalPeriods = 12;
    form.value.remainingPeriods = 12;
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
    installmentCalculationResult.value = null;
    installmentPlanDetails.value = null;
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

// 分期计划展开/收起状态
const isInstallmentPlanExpanded = ref(false);

// 获取显示的分期详情（默认显示前2期）
const visibleInstallmentDetails = computed(() => {
  if (!installmentDetails.value) {
    return null;
  }

  const result = isInstallmentPlanExpanded.value
    ? installmentDetails.value
    : installmentDetails.value.slice(0, 2);
  return result;
});

// 是否有更多期数需要收起
const hasMorePeriods = computed(() => {
  return installmentDetails.value && installmentDetails.value.length > 2;
});

// Compute available payment methods based on selected account and transaction typ
const availablePaymentMethods = computed(() => {
  const selectedAccount = props.accounts.find(acc => acc.serialNum === form.value.accountSerialNum);
  if (form.value.transactionType !== TransactionTypeSchema.enum.Income) {
    if (selectedAccount?.type === AccountTypeSchema.enum.Alipay) {
      return [PaymentMethodSchema.enum.Alipay];
    } else if (selectedAccount?.type === AccountTypeSchema.enum.WeChat) {
      return [PaymentMethodSchema.enum.WeChat];
    } else if (selectedAccount?.type === AccountTypeSchema.enum.CreditCard) {
      return [
        PaymentMethodSchema.enum.CreditCard,
        PaymentMethodSchema.enum.Alipay,
        PaymentMethodSchema.enum.WeChat,
        PaymentMethodSchema.enum.CloudQuickPass,
        PaymentMethodSchema.enum.JD,
        PaymentMethodSchema.enum.UnionPay,
        PaymentMethodSchema.enum.PayPal,
        PaymentMethodSchema.enum.ApplePay,
        PaymentMethodSchema.enum.GooglePay,
        PaymentMethodSchema.enum.SamsungPay,
        PaymentMethodSchema.enum.HuaweiPay,
        PaymentMethodSchema.enum.MiPay,
      ];
    }
  }
  return PaymentMethodSchema.options;
});

// Determine if payment method should be editable
const isPaymentMethodEditable = computed(() => {
  if (form.value.transactionType === TransactionTypeSchema.enum.Income) return false;
  if (isInstallmentTransactionFieldsDisabled.value) return false;
  if (isReadonlyMode.value) return false;
  return availablePaymentMethods.value.length > 1;
});

const selectToAccounts = computed(() => {
  return selectAccounts.value.filter(account => account.serialNum !== form.value.accountSerialNum);
});

function getModalTitle() {
  const titles: Record<TransactionType, string> = {
    Income: 'financial.transaction.recordIncome',
    Expense: 'financial.transaction.recordExpense',
    Transfer: 'financial.transaction.recordTransfer',
  };

  return props.transaction
    ? t('financial.transaction.editTransaction')
    : t(titles[props.type]);
}

function handleOverlayClick() {
  emit('close');
}

// 快捷操作：全选成员
function selectAllMembers() {
  if (availableMembers.value.length > 0) {
    selectedMembers.value = availableMembers.value.map(m => m.serialNum);
    // Selected all members
    toast.success(`已选择全部 ${availableMembers.value.length} 位成员`);
  }
}

// 快捷操作：清空成员
function clearMembers() {
  selectedMembers.value = [];
  // Cleared all members
  toast.info('已清空成员选择');
}

function handleSubmit() {
  const amount = form.value.amount;
  const fromAccount = props.accounts.find(acc => acc.serialNum === form.value.accountSerialNum);
  if (!fromAccount) {
    console.error('未找到转出账户');
    toast.error('未找到转出账户');
    return;
  }

  const fromBalance = parseBalance(fromAccount);
  if (fromBalance === null) {
    toast.error('转出账户余额数据无效');
    return;
  }
  // 转出校验
  if (form.value.transactionType === TransactionTypeSchema.enum.Expense && !canWithdraw(amount, fromBalance)) {
    toast.error(fromAccount.type === AccountTypeSchema.enum.CreditCard
      ? '信用卡转出金额不能大于账户余额'
      : '转出金额超过账户余额');
    return;
  }
  if (form.value.category === TransactionTypeSchema.enum.Transfer) {
    const toAccount = props.accounts.find(acc => acc.serialNum === form.value.toAccountSerialNum);
    if (!toAccount) {
      toast.error('未找到转入账户');
      return;
    }

    // 转入校验
    if (!canDeposit(toAccount, amount)) {
      toast.error('转入金额将导致信用卡余额超过授信额度');
      return;
    }

    emitTransfer(amount);
  } else {
    emitTransaction(amount);
  }
}

// 解析余额，credit=true时返回初始额度
function parseBalance(account: any, credit: boolean = false): number | null {
  const value = credit ? account.initialBalance : account.balance;
  const num = Number.parseFloat(value);
  return Number.isNaN(num) ? null : num;
}

// 校验是否可以转出
function canWithdraw(amount: number, balance: number): boolean {
  return amount <= balance;
}

// 校验是否可以转入
function canDeposit(account: any, amount: number): boolean {
  if (account.type === AccountTypeSchema.enum.CreditCard) {
    const balance = parseBalance(account);
    const initialBalance = parseBalance(account, true);
    if (balance === null || initialBalance === null) return false;
    return balance + amount <= initialBalance;
  }
  // 非信用卡账户不限制转入
  return true;
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
  // 将 selectedMembers 转换为后端需要的 splitMembers 格式
  const splitMembers = selectedMembers.value.length > 0
    ? selectedMembers.value.map(memberId => {
        const member = availableMembers.value.find(m => m.serialNum === memberId);
        return {
          serialNum: memberId,
          name: member?.name || 'Unknown',
        };
      })
    : undefined;

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
    splitMembers, // ✅ 使用转换后的数据
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
  };

  if (props.transaction) {
    const updateTransaction: TransactionUpdate = {
      ...transaction,
    };
    emit('update', props.transaction.serialNum, updateTransaction);
  } else {
    emit('save', transaction);
  }
}

function handleAmountInput(event: Event) {
  const input = event.target as HTMLInputElement;
  const value = input.value;

  if (value === '') {
    form.value.amount = 0;
    return;
  }

  const numValue = Number.parseFloat(value);
  if (!Number.isNaN(numValue)) {
    form.value.amount = numValue;
  }
}

function getDefaultTransaction(type: TransactionType, accounts: Account[]) {
  return {
    serialNum: '',
    transactionType: type,
    category: type === TransactionTypeSchema.enum.Transfer ? 'Transfer' : 'other',
    subCategory: 'other',
    amount: 0,
    refundAmount: 0,
    currency: CURRENCY_CNY,
    date: DateUtils.getLocalISODateTimeWithOffset(),
    description: '',
    notes: null,
    accountSerialNum: '',
    toAccountSerialNum: '',
    tags: [],
    paymentMethod: PaymentMethodSchema.enum.Other,
    actualPayerAccount: AccountTypeSchema.enum.Bank,
    transactionStatus: TransactionStatusSchema.enum.Completed,
    isDeleted: false,
    createdAt: DateUtils.getLocalISODateTimeWithOffset(),
    updatedAt: null,
    account: accounts[0] || ({} as Account),
    // 分期相关字段
    isInstallment: false,
    firstDueDate: undefined,
    totalPeriods: 0,
    remainingPeriods: 0,
    installmentPlanSerialNum: null,
    installmentAmount: 0,
    remainingPeriodsAmount: 0,
    // 家庭记账本关联
    familyLedgerSerialNums: [],
  };
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
  () => form.value.accountSerialNum,
  newAccountSerialNum => {
    const selectedAccount = props.accounts.find(acc => acc.serialNum === newAccountSerialNum);
    if (form.value.transactionType === TransactionTypeSchema.enum.Income) {
      form.value.paymentMethod = PaymentMethodSchema.enum.Other;
    } else {
      form.value.paymentMethod = PaymentMethodSchema.enum.Cash;
      if (selectedAccount) {
        if (selectedAccount.type === AccountTypeSchema.enum.Alipay) {
          form.value.paymentMethod = PaymentMethodSchema.enum.Alipay;
        } else if (selectedAccount.type === AccountTypeSchema.enum.WeChat) {
          form.value.paymentMethod = PaymentMethodSchema.enum.WeChat;
        } else if (selectedAccount.type === AccountTypeSchema.enum.CreditCard) {
          form.value.paymentMethod = PaymentMethodSchema.enum.CreditCard;
        }
      }
    }
    if (newAccountSerialNum === form.value.toAccountSerialNum) {
      form.value.toAccountSerialNum = '';
    }
  },
);

watch(
  () => props.transaction,
  async transaction => {
    if (transaction) {
      form.value = {
        ...getDefaultTransaction(props.type, props.accounts),
        ...transaction,
        // 确保 amount 是数字类型
        amount: typeof transaction.amount === 'string' ? Number.parseFloat(transaction.amount) : transaction.amount,
        currency: transaction.currency || CURRENCY_CNY,
        subCategory: transaction.subCategory || 'other',
        toAccountSerialNum: transaction.toAccountSerialNum || null,
        refundAmount: 0,
        date: transaction.date || DateUtils.getLocalISODateTimeWithOffset(),
      };

      // 如果是分期付款交易，加载分期计划详情
      if (transaction.isInstallment && transaction.installmentPlanSerialNum) {
        await loadInstallmentPlanDetails(transaction.installmentPlanSerialNum);
      }

      // 检查是否有已完成的分期付款
      await checkPaidInstallments(transaction.serialNum);
    } else {
      form.value = getDefaultTransaction(props.type, props.accounts);
      // 重置分期付款状态
      hasPaidInstallmentsFromBackend.value = false;
      rawInstallmentDetails.value = [];
      installmentPlanDetails.value = null;
      installmentCalculationResult.value = null;
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
  <div class="modal-mask" @click="handleOverlayClick">
    <div class="modal-mask-window-money" @click.stop>
      <div class="modal-header">
        <h2 class="modal-title">
          {{ getModalTitle() }}
        </h2>
        <button class="modal-close-btn" @click="$emit('close')">
          <svg class="icon" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      </div>

      <form class="modal-form" @submit.prevent="handleSubmit">
        <!-- 交易类型 -->
        <div class="form-row">
          <label>{{ t('financial.transaction.transType') }}</label>
          <div class="form-control form-display">
            {{ form.transactionType === 'Income' ? t('financial.transaction.income')
              : form.transactionType === 'Expense' ? t('financial.transaction.expense')
                : t('financial.transaction.transfer') }}
          </div>
        </div>

        <!-- 金额 -->
        <div class="form-row">
          <label>{{ t('financial.money') }}</label>
          <input
            v-model="form.amount"
            type="number"
            class="form-control"
            :placeholder="t('common.placeholders.enterAmount')"
            :disabled="isInstallmentFieldsDisabled || isInstallmentTransactionFieldsDisabled || isReadonlyMode"
            step="0.01"
            required
            @input="handleAmountInput"
          >
        </div>

        <!-- 币种 -->
        <div class="form-row">
          <label>{{ t('financial.currency') }}</label>
          <CurrencySelector
            v-model="form.currency"
            class="form-control"
            :disabled="isTransferReadonly || isInstallmentFieldsDisabled || isInstallmentTransactionFieldsDisabled || isReadonlyMode"
          />
        </div>

        <!-- 转出账户 -->
        <div class="form-row">
          <label>
            {{ isTransferReadonly || form.transactionType === TransactionTypeSchema.enum.Transfer ? t('financial.transaction.fromAccount') : t('financial.account.account') }}
          </label>
          <select v-model="form.accountSerialNum" class="form-control" required :disabled="isDisabled || isReadonlyMode">
            <option value="">
              {{ t('common.placeholders.selectAccount') }}
            </option>
            <option v-for="account in selectAccounts" :key="account.serialNum" :value="account.serialNum">
              {{ account.name }} ({{ formatCurrency(account.balance) }})
            </option>
          </select>
        </div>

        <!-- 转入账户 -->
        <div v-if="isTransferReadonly || form.transactionType === TransactionTypeSchema.enum.Transfer" class="form-row">
          <label>{{ t('financial.transaction.toAccount') }}</label>
          <select v-model="form.toAccountSerialNum" class="form-control" required :disabled="isDisabled">
            <option value="">
              {{ t('common.placeholders.selectAccount') }}
            </option>
            <option v-for="account in selectToAccounts" :key="account.serialNum" :value="account.serialNum">
              {{ account.name }} ({{ formatCurrency(account.balance) }})
            </option>
          </select>
        </div>

        <!-- 支付渠道 -->
        <div class="form-row">
          <label>{{ t('financial.transaction.paymentMethod') }}</label>
          <select
            v-if="isPaymentMethodEditable"
            v-model="form.paymentMethod"
            :disabled="isTransferReadonly"
            class="form-control"
            required
          >
            <option value="">
              {{ t('common.placeholders.selectOption') }}
            </option>
            <option v-for="method in availablePaymentMethods" :key="method" :value="method">
              {{ t(`financial.paymentMethods.${method.toLowerCase()}`) }}
            </option>
          </select>
          <div v-else class="form-control form-display">
            {{ t(`financial.paymentMethods.${form.paymentMethod.toLowerCase()}`) }}
          </div>
        </div>

        <!-- 分类 -->
        <div class="form-row">
          <label>{{ t('categories.category') }}</label>
          <select
            v-model="form.category"
            class="form-control"
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
        </div>

        <!-- 子分类 -->
        <div v-if="form.category && categoryMap.get(form.category)?.subs.length" class="form-row">
          <label>{{ t('categories.subCategory') }}</label>
          <select
            v-model="form.subCategory"
            class="form-control"
            :disabled="isTransferReadonly || isInstallmentTransactionFieldsDisabled || isReadonlyMode"
          >
            <option value="">
              {{ t('common.placeholders.selectOption') }}
            </option>
            <option v-for="sub in categoryMap.get(form.category)?.subs" :key="sub" :value="sub">
              {{ t(`common.subCategories.${lowercaseFirstLetter(sub)}`) }}
            </option>
          </select>
        </div>

        <!-- 关联账本 -->
        <div v-if="!isReadonlyMode" class="form-row">
          <label class="label-with-hint">
            关联账本
            <span class="label-hint">(可选)</span>
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
            <span class="label-hint">(可选)</span>
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
                <span class="item-role">{{ member.role }}</span>
              </label>
            </div>
          </div>
        </div>

        <!-- 交易状态 -->
        <div class="form-row">
          <label>{{ t('financial.transaction.status') }}</label>
          <select
            v-model="form.transactionStatus"
            class="form-control"
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
        </div>

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
          <div class="form-row">
            <label>{{ t('financial.transaction.totalPeriods') }}</label>
            <input
              v-model="form.totalPeriods"
              type="number"
              min="2"
              class="form-control"
              :disabled="isInstallmentFieldsDisabled"
            >
          </div>

          <div class="form-row">
            <label>{{ t('financial.transaction.installmentAmount') }}</label>
            <input
              :value="safeToFixed(calculatedInstallmentAmount)"
              type="text"
              readonly
              class="form-control"
            >
          </div>

          <div class="form-row">
            <label>{{ t('financial.transaction.firstDueDate') }}</label>
            <input
              v-model="form.firstDueDate"
              type="date"
              class="form-control"
              :disabled="isInstallmentFieldsDisabled"
            >
          </div>

          <div class="form-row">
            <label>{{ t('financial.transaction.relatedTransaction') }}</label>
            <input
              v-model="form.relatedTransactionSerialNum"
              type="text"
              class="form-control"
              :placeholder="t('common.misc.optional')"
            >
          </div>

          <!-- 分期计划详情 -->
          <div v-if="installmentDetails" class="installment-plan">
            <div class="plan-header">
              <h4>{{ t('financial.transaction.installmentPlan') }}</h4>
              <button
                v-if="hasMorePeriods"
                type="button"
                class="toggle-btn"
                @click="isInstallmentPlanExpanded = !isInstallmentPlanExpanded"
              >
                {{ isInstallmentPlanExpanded ? t('common.actions.collapse') : t('common.actions.expand') }}
              </button>
            </div>

            <div class="plan-list">
              <div
                v-for="detail in visibleInstallmentDetails"
                :key="detail.period"
                class="plan-item"
                :class="{ paid: detail.status === 'PAID', pending: detail.status === 'PENDING', overdue: detail.status === 'OVERDUE' }"
              >
                <div class="period-info">
                  <div class="period-header">
                    <span class="period-label">{{ t('financial.transaction.period', { period: detail.period }) }}</span>
                    <span v-if="detail.status" class="status-text" :class="`status-${detail.status.toLowerCase()}`">
                      {{ getStatusText(detail.status) }}
                    </span>
                  </div>
                  <span class="due-date">{{ detail.dueDate }}</span>
                </div>
                <div class="amount-info">
                  <span class="amount-label">¥{{ safeToFixed(detail.amount) }}</span>
                  <div v-if="detail.status === 'PAID'" class="payment-details">
                    <span class="paid-date">入账日期: {{ detail.paidDate }}</span>
                    <span v-if="detail.paidAmount" class="paid-amount">实付: ¥{{ safeToFixed(detail.paidAmount) }}</span>
                  </div>
                  <div v-else-if="detail.status === 'PENDING'" class="pending-info">
                    <span class="pending-text">{{ t('financial.installment.status.pending') }}</span>
                  </div>
                  <div v-else-if="detail.status === 'OVERDUE'" class="overdue-info">
                    <span class="overdue-text">{{ t('financial.installment.status.overdue') }}</span>
                  </div>
                </div>
              </div>
            </div>

            <div class="plan-summary">
              <div class="summary-stats">
                <div class="stat-item">
                  <span class="stat-label">已入账:</span>
                  <span class="stat-value paid">{{ getPaidPeriodsCount() }} 期</span>
                </div>
                <div class="stat-item">
                  <span class="stat-label">待入账:</span>
                  <span class="stat-value pending">{{ getPendingPeriodsCount() }} 期</span>
                </div>
                <div class="stat-item">
                  <span class="stat-label">总期数:</span>
                  <span class="stat-value">{{ getTotalPeriodsCount() }} 期</span>
                </div>
              </div>
              <div class="total-amount">
                <strong>{{ t('financial.transaction.totalAmount') }}: ¥{{ safeToFixed(form.amount) }}</strong>
                <button
                  v-if="hasMorePeriods"
                  type="button"
                  class="toggle-btn"
                  @click="isInstallmentPlanExpanded = !isInstallmentPlanExpanded"
                >
                  {{ isInstallmentPlanExpanded ? t('common.actions.collapse') : t('common.actions.expand') }}
                </button>
              </div>
            </div>
          </div>
        </div>

        <!-- 日期 -->
        <div class="form-row">
          <label>{{ t('date.transactionDate') }}</label>
          <DateTimePicker
            v-model="form.date"
            class="form-control datetime-picker"
            format="yyyy-MM-dd HH:mm:ss"
            :disabled="isInstallmentTransactionFieldsDisabled || isReadonlyMode"
            :placeholder="t('common.selectDate')"
          />
        </div>

        <!-- 备注 -->
        <div class="form-row">
          <textarea
            v-model="form.description"
            class="form-control textarea-max"
            rows="3"
            :placeholder="`${t('common.misc.remark')}（${t('common.misc.optional')}）`"
            :disabled="isReadonlyMode"
          />
        </div>

        <!-- 按钮 -->
        <div class="modal-actions">
          <button type="button" class="btn-close" @click="$emit('close')">
            <LucideX class="icon-btn" />
          </button>
          <button v-if="!isReadonlyMode" type="submit" class="btn-submit">
            <LucideCheck class="icon-btn" />
          </button>
        </div>
      </form>
    </div>
  </div>
</template>

<style scoped lang="postcss">
.modal-header {
  display: flex; justify-content: space-between; align-items: center;
  border-bottom: 1px solid var(--color-base-200);
  margin-bottom: 1rem; padding-bottom: 0.5rem;
}

.modal-title {
  font-size: 1.125rem; font-weight: 600;
}

.modal-close-btn {
  background: transparent; border: none; cursor: pointer;
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
  background: var(--color-base-50);
  border: 1px solid var(--color-base-200);
  border-radius: 0.5rem;
  padding: 1rem;
  margin: 0.5rem 0;
}

.installment-section .form-row {
  margin-bottom: 0.75rem;
}

.installment-section .form-row:last-child {
  margin-bottom: 0;
}

.installment-plan {
  margin-top: 1rem;
  padding: 1rem;
  background: var(--color-base-100);
  border-radius: 0.5rem;
  border: 1px solid var(--color-base-300);
}

.plan-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1rem;
}

.plan-header h4 {
  margin: 0;
  font-size: 0.875rem;
  font-weight: 600;
  color: var(--color-base-content);
}

.plan-list {
  margin-bottom: 1rem;
}

.plan-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 0.5rem 0;
  border-bottom: 1px solid var(--color-base-200);
}

.plan-item:last-child {
  border-bottom: none;
}

.period-info {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}

.period-label {
  font-size: 0.875rem;
  color: var(--color-base-content);
  font-weight: 500;
}

.due-date {
  font-size: 0.75rem;
  color: var(--color-base-content-soft);
  font-family: monospace;
}

.amount-label {
  font-size: 0.875rem;
  font-weight: 600;
  color: var(--color-primary);
}

/* 分期计划状态样式 */
.plan-item.paid {
  background-color: color-mix(in oklch, var(--color-success) 10%, transparent);
  border-radius: 0.25rem;
  padding: 0.5rem;
  margin: 0.25rem 0;
}

.plan-item.pending {
  background-color: color-mix(in oklch, var(--color-warning) 10%, transparent);
  border-radius: 0.25rem;
  padding: 0.5rem;
  margin: 0.25rem 0;
}

.plan-item.overdue {
  background-color: color-mix(in oklch, var(--color-error) 10%, transparent);
  border-radius: 0.25rem;
  padding: 0.5rem;
  margin: 0.25rem 0;
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
  gap: 0.5rem;
  margin-bottom: 0.25rem;
}

.status-text {
  font-size: 0.75rem;
  font-weight: 500;
  padding: 0.125rem 0.5rem;
  border-radius: 0.25rem;
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
  gap: 0.25rem;
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

.modal-close-btn:hover { color: var(--color-primary); }

.icon { width: 1.5rem; height: 1.5rem; }

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
  width: 66%;
  flex: 0 0 66%;
}

.form-row .member-selector-with-hint {
  width: 66%;
  flex: 0 0 66%;
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

/* ==================== 表单行横向布局 ==================== */
.form-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 0.05rem;
}

.form-row label {
  font-size: 0.875rem;
  font-weight: 500;
  margin-bottom: 0;
  flex: 0 0 auto; /* 标签不伸缩，保持固定宽度 */
  width: 6rem; /* 固定标签宽度 */
  min-width: 6rem; /* 最小宽度 */
  white-space: nowrap; /* 防止标签换行 */
  margin-right: 1rem; /* 标签和输入框之间的间距 */
}

.form-control, .form-display {
  width: 66%;
  padding: 0.5rem 0.75rem;
  border-radius: 6px;
  border: 1px solid var(--color-base-300);
  background-color: var(--color-base-200);
  color: var(--color-neutral);
  font-size: 0.875rem;
}

/* 移动端响应式布局 - 保持同一行显示 */
@media (max-width: 768px) {
  .form-row {
    flex-direction: row; /* 保持水平布局 */
    align-items: center;
    gap: 0.5rem;
  }
  .form-row label {
    flex: 0 0 auto; /* 标签不伸缩，保持固定宽度 */
    min-width: 4rem; /* 设置最小宽度确保标签不被压缩 */
    width: 4rem; /* 移动端缩小标签宽度 */
    margin-right: 0.5rem; /* 减少间距 */
    white-space: nowrap; /* 防止标签换行 */
    font-size: 0.8rem; /* 稍微减小字体以适应移动端 */
  }
  .form-control, .form-display {
    flex: 1; /* 输入框占据剩余空间 */
    min-width: 0; /* 允许输入框收缩 */
  }

  /* 选择器容器移动端优化 */
  .form-row .ledger-selector-compact,
  .form-row .member-selector-compact {
    width: 100%;
    flex: 1;
    padding: 0.5rem;
  }

  .form-row .member-selector-with-hint {
    width: 100%;
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

.form-control:disabled {
  background-color: var(--color-base-300);
  color: var(--color-neutral);
}

/* DateTimePicker 样式 - 与普通input保持一致 */
.form-row > :deep(.datetime-picker) {
  width: 66% !important;
  margin: 0 !important;
  padding: 0 !important;
  flex: 0 0 66%;
}

/* DateTimePicker 移动端响应式 */
@media (max-width: 768px) {
  .form-row > :deep(.datetime-picker) {
    width: 100% !important;
    flex: 1;
  }
}

/* CurrencySelector 样式 - 与普通input保持一致 */
:deep(.currency-selector) {
  margin-bottom: 0 !important; /* 移除外边距 */
  display: block !important; /* 移除flex布局 */
  width: 66% !important; /* 与form-control保持一致 */
  background-color: transparent !important; /* 移除外层背景 */
  border: none !important; /* 移除外层边框 */
  padding: 0 !important; /* 移除外层内边距 */
}

/* CurrencySelector 移动端响应式 */
@media (max-width: 768px) {
  :deep(.currency-selector) {
    width: 100% !important; /* 移动端占满宽度 */
  }
}

:deep(.currency-selector__wrapper) {
  display: block !important; /* 移除flex布局 */
  width: 100% !important;
  background-color: transparent !important; /* 移除包装器背景 */
  border: none !important; /* 移除包装器边框 */
  padding: 0 !important; /* 移除包装器内边距 */
  margin: 0 !important; /* 移除包装器外边距 */
}

:deep(.currency-selector__select) {
  background-color: var(--color-base-200) !important; /* 与其他input一致 */
  border: 1px solid var(--color-base-300) !important; /* 与其他input一致 */
  color: var(--color-neutral) !important; /* 与其他input文字颜色一致 */
  border-radius: 6px !important;
  padding: 0.5rem 0.75rem !important;
  width: 100% !important;
  margin: 0 !important;
  box-sizing: border-box !important;
}

:deep(.currency-selector__select option) {
  color: var(--color-neutral) !important; /* 选项文字颜色 */
  background-color: var(--color-base-200) !important; /* 选项背景色 */
}

:deep(.currency-selector__select option:disabled) {
  color: var(--color-neutral) !important; /* 禁用选项文字颜色 */
}

:deep(.currency-selector__select:focus) {
  border-color: var(--color-primary) !important;
  box-shadow: 0 0 0 2px rgba(96, 165, 250, 0.2) !important;
}

:deep(.currency-selector__select:disabled) {
  background-color: var(--color-base-300) !important;
  color: var(--color-neutral) !important;
}

textarea.form-control { resize: vertical; }

.textarea-max {
  max-width: 400px;
  width: 100%;
  box-sizing: border-box;
}
</style>
