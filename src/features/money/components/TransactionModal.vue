<script setup lang="ts">
import { Check, X } from 'lucide-vue-next';
import { CURRENCY_CNY } from '@/constants/moneyConst';
import {
  CategorySchema,
  SubCategorySchema,
  TransactionTypeSchema,
} from '@/schema/common';
import { AccountTypeSchema } from '@/schema/money';
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

const selectAccounts = computed(() => {
  if (props.type === TransactionTypeSchema.enum.Income) {
    return props.accounts.filter(account => account.type !== AccountTypeSchema.enum.CreditCard && account.isActive);
  }
  return props.accounts.filter(account => account.isActive);
});

// 假设 t 函数已经通过 useI18n 或类似方式注入
const { t } = useI18n();

const form = ref<TransactionWithAccount & { toAccountSerialNum?: string }>({
  serialNum: props.transaction?.serialNum || '',
  transactionType: props.type,
  category: '' as any, // or default from CategorySchema.enum
  subCategory: '' as any,
  amount: '',
  currency: props.transaction?.currency ?? CURRENCY_CNY,
  date: new Date().toISOString().split('T')[0],
  description: '',
  notes: null,
  accountSerialNum: '',
  toAccountSerialNum: '', // 临时字段，用于界面显示
  tags: [],
  paymentMethod: 'Cash', // replace with default from PaymentMethodSchema.enum
  actualPayerAccount: 'Bank', // replace with default from AccountTypeSchema.enum
  transactionStatus: 'Completed',
  createdAt: new Date().toISOString(),
  updatedAt: null,
  account: props.accounts[0] || ({} as Account),
});

function mapSubToCategory(sub: string): string {
  if (['Restaurant', 'Groceries', 'Snacks'].includes(sub))
    return 'Food';
  if (['Bus', 'Taxi', 'Fuel'].includes(sub))
    return 'Transport';
  if (['Movies', 'Concerts'].includes(sub))
    return 'Entertainment';
  if (['MonthlySalary', 'Bonus'].includes(sub))
    return 'Salary';
  return 'Others';
}

// 模拟分类数据
const categories = ref(
  CategorySchema.options.map(name => ({
    name,
    type: ['Salary', 'Investment', 'Transfer'].includes(name) ? 'Income' : 'Expense',
  })),
);

const subcategories = ref(
  SubCategorySchema.options.map(name => ({
    name,
    category: mapSubToCategory(name),
  })),
);

const filteredCategories = computed(() => {
  return categories.value.filter(c => c.type === form.value.transactionType);
});

const filteredSubcategories = computed(() => {
  return subcategories.value.filter(s => s.category === form.value.category);
});

// 为转入账户过滤掉已选择的转出账户
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
  if (form.value.transactionType === TransactionTypeSchema.enum.Transfer) {
    // 处理转账：创建两条交易记录
    const fromAccount = props.accounts.find(acc => acc.serialNum === form.value.accountSerialNum);
    const toAccount = props.accounts.find(acc => acc.serialNum === form.value.toAccountSerialNum);

    if (!fromAccount || !toAccount) {
      console.error('转账账户未找到');
      return;
    }

    // 转出交易（支出）
    const fromTransaction: TransactionWithAccount = {
      serialNum: props.transaction?.serialNum || '',
      transactionType: 'Expense' as TransactionType,
      amount: form.value.amount,
      accountSerialNum: form.value.accountSerialNum,
      category: 'Transfer' as any, // 需要在 CategorySchema 中定义 Transfer 分类
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

    // 转入交易（收入）
    const toTransaction: TransactionWithAccount = {
      serialNum: '', // 新的交易记录
      transactionType: 'Income' as TransactionType,
      amount: form.value.amount,
      accountSerialNum: form.value.toAccountSerialNum!,
      category: 'Transfer' as any, // 需要在 CategorySchema 中定义 Transfer 分类
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
    // 普通收入/支出交易
    const transaction: TransactionWithAccount = {
      ...form.value,
      serialNum: props.transaction?.serialNum || '',
      updatedAt: new Date().toISOString(),
      createdAt: props.transaction?.createdAt || new Date().toISOString(),
    };

    // 移除临时字段
    delete (transaction as any).toAccountSerialNum;

    emit('save', transaction);
  }
}

// 监听分类变化，清空子分类
watch(
  () => form.value.category,
  () => {
    form.value.subCategory = SubCategorySchema.enum.Other;
  },
);

// 监听交易类型变化，清空分类
watch(
  () => form.value.transactionType,
  () => {
    form.value.category = CategorySchema.enum.Others;
    form.value.subCategory = SubCategorySchema.enum.Other;
  },
);

// 监听转出账户变化，如果与转入账户相同则清空转入账户
watch(
  () => form.value.accountSerialNum,
  newAccountSerialNum => {
    if (newAccountSerialNum === form.value.toAccountSerialNum) {
      form.value.toAccountSerialNum = '';
    }
  },
);

// 初始化表单数据
watch(
  () => props.transaction,
  transaction => {
    if (transaction) {
      form.value = {
        ...transaction,
        serialNum: transaction.serialNum,
        transactionType: transaction.transactionType,
        amount: transaction.amount,
        accountSerialNum: transaction.accountSerialNum,
        toAccountSerialNum: '', // 编辑时暂时不支持转账，所以为空
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
        amount: '',
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
            v-model="form.amount" type="number" class="w-2/3 modal-input-select"
            :placeholder="t('common.placeholders.enterAmount')" step="0.01" min="0" required
          >
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

        <!-- 分类 -->
        <div class="flex items-center justify-between">
          <label class="mb-1 block text-sm font-medium">{{ t('categories.category') }}</label>
          <select v-model="form.category" class="w-2/3 modal-input-select" required>
            <option value="">
              {{ t('common.placeholders.selectCategory') }}
            </option>
            <option v-for="category in filteredCategories" :key="category.name" :value="category.name">
              {{ category.name }}
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
              {{ subcategory.name }}
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
