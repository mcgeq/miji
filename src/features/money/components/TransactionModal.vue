<script setup lang="ts">
import VueDatePicker from '@vuepic/vue-datepicker';
import CurrencySelector from '@/components/common/money/CurrencySelector.vue';
import { CURRENCY_CNY } from '@/constants/moneyConst';
import {
  TransactionStatusSchema,
  TransactionTypeSchema,
} from '@/schema/common';
import { AccountTypeSchema, PaymentMethodSchema } from '@/schema/money';
import { lowercaseFirstLetter } from '@/utils/common';
import { DateUtils } from '@/utils/date';
import { toast } from '@/utils/toast';
import { formatCurrency } from '../utils/money';
import type {
  TransactionType,
} from '@/schema/common';
import '@vuepic/vue-datepicker/dist/main.css';
import type { Account, Transaction, TransactionCreate, TransactionUpdate, TransferCreate } from '@/schema/money';

interface Props {
  type: TransactionType;
  transaction?: Transaction | null;
  accounts: Account[];
}

const props = defineProps<Props>();
const emit = defineEmits<{
  close: [];
  save: [transaction: TransactionCreate];
  update: [serialNum: string, transaction: TransactionUpdate];
  saveTransfer: [transfer: TransferCreate];
  updateTransfer: [serialNum: string, transfer: TransferCreate];
}>();
const moneyStore = useMoneyStore();
const { t } = useI18n();

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
  amount: trans.amount || 0,
  currency: trans.currency || CURRENCY_CNY,
  category: props.type === TransactionTypeSchema.enum.Transfer ? 'Transfer' : 'other',
  refundAmount: 0,
  toAccountSerialNum: '',
  date: trans.date || DateUtils.getLocalISODateTimeWithOffset(),
});

const categoryMap = computed(() => {
  const map = new Map<string, { name: string; subs: string[] }>();
  moneyStore.subCategories.forEach(sub => {
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
      ];
    }
  }
  return PaymentMethodSchema.options;
});

// Determine if payment method should be editable
const isPaymentMethodEditable = computed(() => {
  if (form.value.transactionType === TransactionTypeSchema.enum.Income) return false;
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
    splitMembers: form.value.splitMembers,
    paymentMethod: form.value.paymentMethod,
    actualPayerAccount: form.value.actualPayerAccount,
    relatedTransactionSerialNum: form.value.relatedTransactionSerialNum,
    isDeleted: false,
    currency: form.value.currency.code,
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
  transaction => {
    if (transaction) {
      form.value = {
        ...getDefaultTransaction(props.type, props.accounts),
        ...transaction,
        currency: transaction.currency || CURRENCY_CNY,
        subCategory: transaction.subCategory || 'other',
        toAccountSerialNum: transaction.toAccountSerialNum || null,
        refundAmount: 0,
        date: transaction.date || DateUtils.getLocalISODateTimeWithOffset(),
      };
    } else {
      form.value = getDefaultTransaction(props.type, props.accounts);
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
          <div class="form-display">
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
            :disabled="isTransferReadonly"
          />
        </div>

        <!-- 转出账户 -->
        <div class="form-row">
          <label>
            {{ isTransferReadonly || form.transactionType === TransactionTypeSchema.enum.Transfer ? t('financial.transaction.fromAccount') : t('financial.account.account') }}
          </label>
          <select v-model="form.accountSerialNum" class="form-control" required :disabled="isDisabled">
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
          <span v-else>
            {{ t(`financial.paymentMethods.${form.paymentMethod.toLowerCase()}`) }}
          </span>
        </div>

        <!-- 分类 -->
        <div class="form-row">
          <label>{{ t('categories.category') }}</label>
          <select v-model="form.category" class="form-control" required :disabled="isTransferReadonly">
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
          <select v-model="form.subCategory" class="form-control">
            <option value="">
              {{ t('common.placeholders.selectOption') }}
            </option>
            <option v-for="sub in categoryMap.get(form.category)?.subs" :key="sub" :value="sub">
              {{ t(`common.subCategories.${lowercaseFirstLetter(sub)}`) }}
            </option>
          </select>
        </div>

        <!-- 日期 -->
        <div class="form-row">
          <label>{{ t('date.transactionDate') }}</label>
          <VueDatePicker
            v-model="form.date"
            :enable-time-picker="true"
            :is-24="true"
            class="form-control"
            format="yyyy-MM-dd HH:mm:ss"
            required
          />
        </div>

        <!-- 备注 -->
        <div class="form-row">
          <textarea
            v-model="form.description"
            class="form-control textarea-max"
            rows="3"
            :placeholder="`${t('common.misc.remark')}（${t('common.misc.optional')}）`"
          />
        </div>

        <!-- 按钮 -->
        <div class="modal-actions">
          <button type="button" class="btn-close" @click="$emit('close')">
            <LucideX class="icon-btn" />
          </button>
          <button type="submit" class="btn-submit">
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
  color: var(--color-neutral-content);
}

.modal-close-btn:hover { color: var(--color-primary); }

.icon { width: 1.5rem; height: 1.5rem; }

/* ==================== 表单行横向布局 ==================== */
.form-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 1rem;
}

.form-row label {
  font-size: 0.875rem; font-weight: 500;
  margin-bottom: 0;
  flex: 1; /* label 自适应 */
}

.form-control, .form-display {
  width: 66%; /* 对应 Tailwind w-2/3 */
  padding: 0.5rem 0.75rem;
  border-radius: 6px;
  border: 1px solid var(--color-base-300);
  background-color: var(--color-base-200);
  color: var(--color-base-content);
  font-size: 0.875rem;
}

.form-control:disabled {
  background-color: var(--color-base-300);
  color: var(--color-neutral-content);
}

textarea.form-control { resize: vertical; }

.textarea-max {
  max-width: 400px;
  width: 100%;
  box-sizing: border-box;
}

/* ==================== 按钮 ==================== */
.modal-actions {
  display: flex; justify-content: center; gap: 0.75rem;
  margin-top: 1rem;
}

.btn-close, .btn-submit {
  display: inline-flex; align-items: center; justify-content: center;
  width: 3rem; height: 3rem; border-radius: 50%; border: none; cursor: pointer;
}

.btn-close {
  background-color: var(--color-neutral); color: var(--color-neutral-content);
}

.btn-close:hover {
  background-color: var(--color-neutral-content); color: var(--color-neutral);
}

.btn-submit {
  background-color: var(--color-primary); color: var(--color-primary-content);
}

.btn-submit:hover {
  background-color: var(--color-primary-content); color: var(--color-primary);
}

.icon-btn { width: 1.25rem; height: 1.25rem; }
</style>
