<script setup lang="ts">
import { Check, X } from 'lucide-vue-next';
import CurrencySelector from '@/components/common/money/CurrencySelector.vue';
import { CURRENCY_CNY } from '@/constants/moneyConst';
import {
  CategorySchema,
  SubCategorySchema,
  TransactionStatusSchema,
  TransactionTypeSchema,
} from '@/schema/common';
import { AccountTypeSchema, PaymentMethodSchema } from '@/schema/money';
import { DateUtils } from '@/utils/date';
import { toast } from '@/utils/toast';
import { formatCurrency } from '../utils/money';
import type {
  TransactionType,
} from '@/schema/common';
import type { Account, TransactionWithAccount } from '@/schema/money';

interface Props {
  type: TransactionType;
  transaction?: TransactionWithAccount | null;
  accounts: Account[];
}

const props = defineProps<Props>();
const emit = defineEmits<{
  close: [];
  save: [transaction: TransactionWithAccount];
  saveTransfer: [fromTransaction: TransactionWithAccount, toTransaction: TransactionWithAccount];
}>();

const { t } = useI18n();

const selectAccounts = computed(() => {
  if (props.type === TransactionTypeSchema.enum.Income) {
    return props.accounts.filter(account => account.type !== AccountTypeSchema.enum.CreditCard && account.isActive);
  }
  return props.accounts.filter(account => account.isActive);
});

const trans = props.transaction || {
  serialNum: '',
  transactionType: props.type,
  category: CategorySchema.enum.Others,
  subCategory: SubCategorySchema.enum.Other,
  amount: 0,
  currency: CURRENCY_CNY,
  date: DateUtils.getLocalISODateTimeWithOffset().split('T')[0],
  description: '',
  notes: null,
  accountSerialNum: '',
  tags: [],
  paymentMethod: PaymentMethodSchema.enum.Cash,
  actualPayerAccount: AccountTypeSchema.enum.Bank,
  transactionStatus: TransactionStatusSchema.enum.Completed,
  createdAt: DateUtils.getLocalISODateTimeWithOffset(),
  updatedAt: null,
  account: props.accounts[0] || ({} as Account),
};

const form = ref<TransactionWithAccount & { toAccountSerialNum?: string }>({
  ...trans,
  amount: trans.amount || 0,
  toAccountSerialNum: '',
});

// Compute available payment methods based on selected account and transaction type
const availablePaymentMethods = computed(() => {
  const selectedAccount = props.accounts.find(acc => acc.serialNum === form.value.accountSerialNum);
  if (form.value.transactionType === TransactionTypeSchema.enum.Expense) {
    if (selectedAccount?.type === AccountTypeSchema.enum.Alipay) {
      return [PaymentMethodSchema.enum.Alipay];
    }
    else if (selectedAccount?.type === AccountTypeSchema.enum.WeChat) {
      return [PaymentMethodSchema.enum.WeChat];
    }
    else if (selectedAccount?.type === AccountTypeSchema.enum.CloudQuickPass) {
      return [PaymentMethodSchema.enum.CloudQuickPass];
    }
    else if (selectedAccount?.type === AccountTypeSchema.enum.CreditCard) {
      return [PaymentMethodSchema.enum.CreditCard];
    }
    else if (selectedAccount?.type === AccountTypeSchema.enum.Savings || selectedAccount?.type === AccountTypeSchema.enum.Bank) {
      return [PaymentMethodSchema.enum.BankTransfer, PaymentMethodSchema.enum.Savings];
    }
  }
  return PaymentMethodSchema.options;
});

// Determine if payment method should be editable
const isPaymentMethodEditable = computed(() => {
  return availablePaymentMethods.value.length > 1;
});

// Update payment method when account or transaction type changes
watch(
  () => [form.value.accountSerialNum, form.value.transactionType],
  ([newAccountSerialNum, newTransactionType]) => {
    const selectedAccount = props.accounts.find(acc => acc.serialNum === newAccountSerialNum);
    if (newTransactionType === TransactionTypeSchema.enum.Expense) {
      if (selectedAccount?.type === AccountTypeSchema.enum.Alipay) {
        form.value.paymentMethod = PaymentMethodSchema.enum.Alipay;
      }
      else if (selectedAccount?.type === AccountTypeSchema.enum.WeChat) {
        form.value.paymentMethod = PaymentMethodSchema.enum.WeChat;
      }
      else if (selectedAccount?.type === AccountTypeSchema.enum.CloudQuickPass) {
        form.value.paymentMethod = PaymentMethodSchema.enum.CloudQuickPass;
      }
      else {
        // Reset to default if not Alipay, WeChat, or CloudQuickPass
        if (
          form.value.paymentMethod === PaymentMethodSchema.enum.Alipay ||
          form.value.paymentMethod === PaymentMethodSchema.enum.WeChat ||
          form.value.paymentMethod === PaymentMethodSchema.enum.CloudQuickPass
        ) {
          form.value.paymentMethod = PaymentMethodSchema.enum.Cash;
        }
      }
    }
    else {
      // For non-Expense transactions, reset if payment method is restricted
      if (
        form.value.paymentMethod === PaymentMethodSchema.enum.Alipay ||
        form.value.paymentMethod === PaymentMethodSchema.enum.WeChat ||
        form.value.paymentMethod === PaymentMethodSchema.enum.CloudQuickPass
      ) {
        form.value.paymentMethod = PaymentMethodSchema.enum.Cash;
      }
    }
    if (newAccountSerialNum === form.value.toAccountSerialNum) {
      form.value.toAccountSerialNum = '';
    }
  },
);

function mapSubToCategory(sub: string): string {
  if (['Restaurant', 'Groceries', 'Snacks'].includes(sub)) return 'Food';
  if (['Bus', 'Taxi', 'Fuel', 'Train', 'Flight', 'Parking'].includes(sub)) return 'Transport';
  if (['Movies', 'Concerts', 'Sports', 'Gaming', 'Streaming'].includes(sub)) return 'Entertainment';
  if (['Electricity', 'Water', 'Gas', 'Internet', 'Cable'].includes(sub)) return 'Utilities';
  if (['Clothing', 'Electronics', 'HomeDecor', 'Furniture', 'Toys'].includes(sub)) return 'Shopping';
  if (['MonthlySalary', 'Bonus', 'Overtime', 'Commission'].includes(sub)) return 'Salary';
  if (['StockDividend', 'BondInterest', 'PropertyRental', 'CryptoIncome'].includes(sub)) return 'Investment';
  if (['AccountTransfer', 'LoanRepayment', 'InvestmentWithdrawal'].includes(sub)) return 'Transfer';
  if (['Tuition', 'Books', 'Courses', 'SchoolSupplies'].includes(sub)) return 'Education';
  if (['DoctorVisit', 'Medications', 'Hospitalization', 'Dental', 'InsurancePremiums'].includes(sub)) return 'Healthcare';
  if (['HealthInsurance', 'CarInsurance', 'LifeInsurance'].includes(sub)) return 'Insurance';
  if (['BankInterest', 'FixedDeposit'].includes(sub)) return 'Savings';
  if (['GiftSent', 'GiftReceived'].includes(sub)) return 'Gift';
  if (['Mortgage', 'PersonalLoan', 'CreditCardPayment'].includes(sub)) return 'Loan';
  if (['OfficeSupplies', 'TravelExpenses', 'Marketing', 'ConsultingFees'].includes(sub)) return 'Business';
  if (['Hotel', 'TourPackage', 'Activities'].includes(sub)) return 'Travel';
  if (['Donation'].includes(sub)) return 'Charity';
  if (['Netflix', 'Spotify', 'Software'].includes(sub)) return 'Subscription';
  if (['PetFood', 'PetVet', 'PetToys'].includes(sub)) return 'Pet';
  if (['Furniture', 'Renovation', 'HomeMaintenance'].includes(sub)) return 'Home';
  return 'Others';
}

const categories = ref(
  CategorySchema.options.map(name => ({
    name,
    type: name === TransactionTypeSchema.enum.Transfer ? 'Transfer' : ['Salary', 'Investment'].includes(name) ? 'Income' : 'Expense',
  })),
);

const subcategories = ref(
  SubCategorySchema.options.map(name => ({
    name,
    category: mapSubToCategory(name),
  })),
);

const filteredCategories = computed(() => {
  const category = categories.value.filter(c => {
    if (props.transaction?.category === CategorySchema.enum.Transfer) {
      return c.type === CategorySchema.enum.Transfer;
    }
    else {
      return c.type === form.value.transactionType;
    }
  });

  return category.map(item => ({
    name: item.name,
    type: item.type,
    option: t(`financial.transactionCategories.${item.name.toLocaleLowerCase()}`),
  }));
});

const filteredSubcategories = computed(() => {
  if (form.value.category === TransactionTypeSchema.enum.Transfer) {
    return [];
  }
  const sub = subcategories.value.filter(s => s.category === form.value.category);
  return sub.map(item => ({
    name: item.name,
    category: item.category,
    option: t(`financial.transactionSubCategories.${item.name.toLocaleLowerCase()}`),
  }));
});

const selectToAccounts = computed(() => {
  return selectAccounts.value.filter(account => account.serialNum !== form.value.accountSerialNum);
});

function getModalTitle() {
  const titles = {
    Income: 'financial.transaction.recordIncome',
    Expense: 'financial.transaction.recordExpense',
    Transfer: 'financial.transaction.recordTransfer',
  };

  if (props.transaction) {
    return t('financial.transaction.editTransaction');
  }

  return t(titles[props.type]);
}

function handleOverlayClick() {
  emit('close');
}

function handleSubmit() {
  const amount = form.value.amount;
  if (Number.isNaN(amount) || amount <= 0) {
    toast.error('请输入有效的金额');
    return;
  }

  const fromAccount = props.accounts.find(acc => acc.serialNum === form.value.accountSerialNum);
  if (!fromAccount) {
    console.error('未找到转出账户');
    return;
  }

  // 校验 1: 如果转出账户是信用卡，检查转出金额是否超过授信额度
  // Validate credit card transactions
  if (fromAccount.type === AccountTypeSchema.enum.CreditCard) {
    const initialBalance = Number.parseFloat(fromAccount.initialBalance);
    const balance = Number.parseFloat(fromAccount.balance);
    if (Number.isNaN(initialBalance) || Number.isNaN(balance)) {
      console.error('Invalid balance data:', { initialBalance, balance });
      toast.error('账户余额数据无效');
      return;
    }
    const availableCredit = amount - initialBalance;
    if (availableCredit > 0) {
      toast.error('转出金额超过信用卡可用额度');
      return;
    }
  }
  else {
    // Non-credit card accounts, check balance
    const balance = Number.parseFloat(fromAccount.balance);
    if (Number.isNaN(balance) || amount > balance) {
      toast.error('转出金额超过账户余额');
      return;
    }
  }

  if (form.value.transactionType === TransactionTypeSchema.enum.Transfer) {
    const toAccount = props.accounts.find(acc => acc.serialNum === form.value.toAccountSerialNum);
    if (!toAccount) {
      toast.error('未找到转入账户');
      return;
    }

    // 校验 2: 如果转入账户是信用卡，检查转入金额是否导致余额超过授信额度
    // Validate credit card for transfer-in
    if (toAccount.type === AccountTypeSchema.enum.CreditCard) {
      const newBalance = Number.parseFloat(toAccount.balance) + amount;
      const initialBalance = Number.parseFloat(toAccount.initialBalance);
      if (newBalance > initialBalance) {
        toast.error('转入金额将导致信用卡余额超过授信额度');
        return;
      }
    }

    const fromTransaction: TransactionWithAccount = {
      serialNum: props.transaction?.serialNum || '',
      transactionType: TransactionTypeSchema.enum.Expense,
      amount: form.value.amount,
      accountSerialNum: form.value.accountSerialNum,
      category: CategorySchema.enum.Transfer,
      subCategory: form.value.subCategory,
      currency: form.value.currency || CURRENCY_CNY,
      date: form.value.date,
      description: `转账至 ${toAccount.name}${form.value.description ? ` - ${form.value.description}` : ''}`,
      notes: form.value.notes,
      tags: form.value.tags || [],
      paymentMethod: form.value.paymentMethod || 'Cash',
      actualPayerAccount: form.value.actualPayerAccount || 'Bank',
      transactionStatus: form.value.transactionStatus || 'Completed',
      createdAt: props.transaction?.createdAt || new Date().toISOString(),
      updatedAt: new Date().toISOString(),
      account: fromAccount,
    };

    const toTransaction: TransactionWithAccount = {
      serialNum: '',
      transactionType: TransactionTypeSchema.enum.Income,
      amount: form.value.amount,
      accountSerialNum: form.value.toAccountSerialNum!,
      category: CategorySchema.enum.Transfer,
      subCategory: form.value.subCategory,
      currency: form.value.currency || CURRENCY_CNY,
      date: form.value.date,
      description: `来自 ${fromAccount.name}${form.value.description ? ` - ${form.value.description}` : ''}`,
      notes: form.value.notes,
      tags: form.value.tags || [],
      paymentMethod: form.value.paymentMethod || 'Cash',
      actualPayerAccount: form.value.actualPayerAccount || 'Bank',
      transactionStatus: form.value.transactionStatus || 'Completed',
      createdAt: new Date().toISOString(),
      updatedAt: null,
      account: toAccount,
    };

    emit('saveTransfer', fromTransaction, toTransaction);
  }
  else {
    const transaction: TransactionWithAccount = {
      ...form.value,
      serialNum: props.transaction?.serialNum || '',
      updatedAt: new Date().toISOString(),
      createdAt: props.transaction?.createdAt || new Date().toISOString(),
    };

    delete (transaction as any).toAccountSerialNum;

    emit('save', transaction);
  }
}

function validateAmount(event: Event) {
  const input = event.target as HTMLInputElement;
  if (input.value === '' || Number.isNaN(Number(input.value))) {
    form.value.amount = 0; // Reset to empty string for invalid input
  }
  else {
    form.value.amount = Number.parseFloat(input.value); // Keep as string
  }
}

watch(
  () => form.value.category,
  () => {
    form.value.subCategory = SubCategorySchema.enum.Other;
  },
);

watch(
  () => form.value.transactionType,
  () => {
    form.value.category = CategorySchema.enum.Others;
    form.value.subCategory = SubCategorySchema.enum.Other;
  },
);

watch(
  () => [form.value.accountSerialNum, form.value.transactionType],
  ([newAccountSerialNum, newTransactionType]) => {
    const selectedAccount = props.accounts.find(acc => acc.serialNum === newAccountSerialNum);

    // Reset payment method to a default value
    form.value.paymentMethod = PaymentMethodSchema.enum.Cash;

    if (newTransactionType === TransactionTypeSchema.enum.Expense) {
      if (selectedAccount?.type === AccountTypeSchema.enum.Alipay) {
        form.value.paymentMethod = PaymentMethodSchema.enum.Alipay;
      }
      else if (selectedAccount?.type === AccountTypeSchema.enum.WeChat) {
        form.value.paymentMethod = PaymentMethodSchema.enum.WeChat;
      }
      else if (selectedAccount?.type === AccountTypeSchema.enum.CloudQuickPass) {
        form.value.paymentMethod = PaymentMethodSchema.enum.CloudQuickPass;
      }
      else if (selectedAccount?.type === AccountTypeSchema.enum.CreditCard) {
        form.value.paymentMethod = PaymentMethodSchema.enum.CreditCard;
      }
      else if (
        selectedAccount?.type === AccountTypeSchema.enum.Savings ||
        selectedAccount?.type === AccountTypeSchema.enum.Bank
      ) {
        form.value.paymentMethod = PaymentMethodSchema.enum.BankTransfer;
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
        ...transaction,
        serialNum: transaction.serialNum,
        transactionType: transaction.transactionType,
        amount: transaction.amount || 0,
        accountSerialNum: transaction.accountSerialNum,
        toAccountSerialNum: '',
        category: transaction.category,
        subCategory: transaction.subCategory || SubCategorySchema.enum.Other,
        currency: transaction.currency || CURRENCY_CNY,
        date: transaction.date,
        description: transaction.description || '',
        notes: transaction.notes || null,
        tags: transaction.tags || [],
        paymentMethod: transaction.paymentMethod || 'Cash',
        actualPayerAccount: transaction.actualPayerAccount || 'Bank',
        transactionStatus: transaction.transactionStatus || 'Completed',
        createdAt: transaction.createdAt,
        updatedAt: transaction.updatedAt || null,
        account: transaction.account,
      };
    }
    else {
      form.value = {
        serialNum: '',
        transactionType: props.type,
        amount: 0,
        accountSerialNum: '',
        toAccountSerialNum: '',
        category: CategorySchema.enum.Others,
        subCategory: SubCategorySchema.enum.Other,
        currency: CURRENCY_CNY,
        date: new Date().toISOString().split('T')[0],
        description: '',
        notes: null,
        tags: [],
        paymentMethod: 'Cash',
        actualPayerAccount: 'Bank',
        transactionStatus: 'Completed',
        createdAt: new Date().toISOString(),
        updatedAt: null,
        account: props.accounts[0] || ({} as Account),
      };
    }
  },
  { immediate: true },
);
</script>

<template>
  <div class="modal-mask" @click="handleOverlayClick">
    <div class="modal-mask-window-money" @click.stop>
      <div class="mb-4 flex items-center justify-between border-b pb-2">
        <h2 class="text-lg text-gray-800 font-semibold dark:text-gray-100">
          {{ getModalTitle() }}
        </h2>
        <button class="text-gray-500 hover:text-gray-700" @click="emit('close')">
          <svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      </div>
      <form class="space-y-4" @submit.prevent="handleSubmit">
        <!-- 交易类型 -->
        <div class="flex items-center justify-between">
          <label class="mb-1 text-sm font-medium">{{ t('financial.transaction.transType') }}</label>
          <div class="w-2/3 modal-input-select bg-gray-50 dark:bg-gray-700">
            {{ form.transactionType === 'Income' ? t('financial.transaction.income')
              : form.transactionType === 'Expense' ? t('financial.transaction.expense')
                : t('financial.transaction.transfer') }}
          </div>
        </div>

        <!-- 金额 -->
        <div class="mt-4 flex items-center justify-between">
          <label class="mb-1 text-sm font-medium">{{ t('financial.money') }}</label>
          <input
            v-model="form.amount"
            type="number"
            class="w-2/3 modal-input-select"
            :placeholder="t('common.placeholders.enterAmount')"
            step="0.01"
            min="0"
            required
            @input="validateAmount"
          >
        </div>

        <!-- 币种 -->
        <div class="mt-4 flex items-center justify-between">
          <label class="mb-1 text-sm font-medium">{{ t('financial.currency') }}</label>
          <CurrencySelector v-model="form.currency" class="w-2/3" />
        </div>

        <!-- 转出账户 -->
        <div class="flex items-center justify-between">
          <label class="mb-1 text-sm font-medium">
            {{ form.transactionType === TransactionTypeSchema.enum.Transfer ? t('financial.transaction.fromAccount')
              : t('financial.account.account') }}
          </label>
          <select v-model="form.accountSerialNum" class="w-2/3 modal-input-select" required>
            <option value="">
              {{ t('common.placeholders.selectAccount') }}
            </option>
            <option v-for="account in selectAccounts" :key="account.serialNum" :value="account.serialNum">
              {{ account.name }} ({{ formatCurrency(account.balance) }})
            </option>
          </select>
        </div>

        <!-- 转入账户（仅转账时显示） -->
        <div v-if="form.transactionType === TransactionTypeSchema.enum.Transfer" class="flex items-center justify-between">
          <label class="mb-1 text-sm font-medium">
            {{ t('financial.transaction.toAccount') }}
          </label>
          <select v-model="form.toAccountSerialNum" class="w-2/3 modal-input-select" required>
            <option value="">
              {{ t('common.placeholders.selectAccount') }}
            </option>
            <option v-for="account in selectToAccounts" :key="account.serialNum" :value="account.serialNum">
              {{ account.name }} ({{ formatCurrency(account.balance) }})
            </option>
          </select>
        </div>

        <!-- 支付渠道 -->
        <div class="flex items-center justify-between">
          <label class="mb-1 text-sm font-medium">{{ t('financial.transaction.paymentMethod') }}</label>
          <div class="w-2/3 modal-input-select bg-gray-50 dark:bg-gray-700">
            <select
              v-if="isPaymentMethodEditable"
              v-model="form.paymentMethod"
              class="w-full"
              required
            >
              <option value="">
                {{ t('common.placeholders.selectOption') }}
              </option>
              <option v-for="method in availablePaymentMethods" :key="method" :value="method">
                {{ t(`financial.paymentMethods.${method.toLocaleLowerCase()}`) }}
              </option>
            </select>
            <span v-else>
              {{ t(`financial.paymentMethods.${form.paymentMethod.toLocaleLowerCase()}`) }}
            </span>
          </div>
        </div>

        <!-- 分类 -->
        <div class="flex items-center justify-between">
          <label class="mb-1 block text-sm font-medium">{{ t('categories.category') }}</label>
          <select v-model="form.category" class="w-2/3 modal-input-select" required>
            <option value="">
              {{ t('common.placeholders.selectCategory') }}
            </option>
            <option v-for="category in filteredCategories" :key="category.name" :value="category.name">
              {{ category.option }}
            </option>
          </select>
        </div>

        <!-- 子分类 -->
        <div v-if="filteredSubcategories.length > 0" class="flex items-center justify-between">
          <label class="mb-1 text-sm font-medium">{{ t('categories.subCategory') }}</label>
          <select v-model="form.subCategory" class="w-2/3 modal-input-select">
            <option value="">
              {{ t('common.placeholders.selectOption') }}
            </option>
            <option v-for="subcategory in filteredSubcategories" :key="subcategory.name" :value="subcategory.name">
              {{ subcategory.option }}
            </option>
          </select>
        </div>

        <!-- 日期 -->
        <div class="flex items-center justify-between">
          <label class="mb-1 text-sm font-medium">{{ t('date.transactionDate') }}</label>
          <input v-model="form.date" type="date" class="w-2/3 modal-input-select" required>
        </div>

        <!-- 备注 -->
        <div class="mb-2">
          <textarea
            v-model="form.description" class="w-full modal-input-select" rows="3"
            :placeholder="`${t('common.misc.remark')}（${t('common.misc.optional')}）`"
          />
        </div>

        <!-- 按钮 -->
        <div class="flex justify-center gap-3 pt-4">
          <button type="button" class="modal-btn-x" @click="$emit('close')">
            <X class="wh-5" />
          </button>
          <button type="submit" class="modal-btn-check">
            <Check class="wh-5" />
          </button>
        </div>
      </form>
    </div>
  </div>
</template>
