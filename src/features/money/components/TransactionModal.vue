<template>
  <div v-if="visible" class="fixed inset-0 bg-black/50 flex items-center justify-center z-1000" @click="handleOverlayClick">
    <div class="bg-white dark:bg-gray-800 rounded-lg w-11/12 max-w-xl max-h-[80vh] overflow-y-auto p-6" @click.stop>
      <div class="flex justify-between items-center mb-4 border-b pb-2">
        <h2 class="text-lg font-semibold text-gray-800 dark:text-gray-100">{{ getModalTitle() }}</h2>
        <button class="text-gray-500 hover:text-red-500 transition" @click="$emit('close')">
          <i class="i-lucide-x w-5 h-5"></i>
        </button>
      </div>

      <form class="space-y-4" @submit.prevent="handleSubmit">
        <!-- 交易类型 -->
        <div>
          <label class="block text-sm font-medium mb-1">交易类型</label>
          <select v-model="form.transactionType" class="form-select w-full" required>
            <option value="Income">收入</option>
            <option value="Expense">支出</option>
            <option value="Transfer">转账</option>
          </select>
        </div>

        <!-- 金额 -->
        <div>
          <label class="block text-sm font-medium mb-1">金额</label>
          <input
            type="number"
            v-model="form.amount"
            class="form-input w-full"
            placeholder="请输入金额"
            step="0.01"
            min="0"
            required
          />
        </div>

        <!-- 账户 -->
        <div>
          <label class="block text-sm font-medium mb-1">
            {{ form.transactionType === TransactionTypeSchema.enum.Transfer ? '转出账户' : '账户' }}
          </label>
          <select v-model="form.accountSerialNum" class="form-select w-full" required>
            <option value="">请选择账户</option>
            <option
              v-for="account in accounts"
              :key="account.serialNum"
              :value="account.serialNum"
            >
              {{ account.name }} ({{ formatCurrency(account.balance) }})
            </option>
          </select>
        </div>

        <!-- 分类 -->
        <div>
          <label class="block text-sm font-medium mb-1">分类</label>
          <select v-model="form.category" class="form-select w-full" required>
            <option value="">请选择分类</option>
            <option
              v-for="category in filteredCategories"
              :key="category.name"
              :value="category.name"
            >
              {{ category.name }}
            </option>
          </select>
        </div>

        <!-- 子分类 -->
        <div v-if="filteredSubcategories.length > 0">
          <label class="block text-sm font-medium mb-1">子分类</label>
          <select v-model="form.subCategory" class="form-select w-full">
            <option value="">请选择子分类</option>
            <option
              v-for="subcategory in filteredSubcategories"
              :key="subcategory.name"
              :value="subcategory.name"
            >
              {{ subcategory.name }}
            </option>
          </select>
        </div>
        <!-- 日期 -->
        <div>
          <label class="block text-sm font-medium mb-1">交易日期</label>
          <input type="date" v-model="form.date" class="form-input w-full" required />
        </div>

        <!-- 备注 -->
        <div>
          <label class="block text-sm font-medium mb-1">备注</label>
          <textarea
            v-model="form.description"
            class="form-textarea w-full"
            rows="3"
            placeholder="请输入备注信息（可选）"
          ></textarea>
        </div>

        <!-- 按钮 -->
        <div class="flex justify-end gap-3 pt-4 border-t">
          <button type="button" class="btn px-4 py-2 border border-gray-300 rounded-md hover:bg-gray-100 dark:hover:bg-gray-700" @click="$emit('close')">
            取消
          </button>
          <button type="submit" class="btn px-4 py-2 bg-blue-600 text-white rounded-md hover:bg-blue-700">
            保存
          </button>
        </div>
      </form>
    </div>
  </div>
</template>

<script setup lang="ts">
import {
  CategorySchema,
  SubCategorySchema,
  TransactionType,
  TransactionTypeSchema,
} from '@/schema/common';
import { Account, TransactionWithAccount } from '@/schema/money';

interface Props {
  visible: boolean;
  type: TransactionType;
  transaction?: TransactionWithAccount | null;
  accounts: Account[];
}

const props = defineProps<Props>();
const form = ref<TransactionWithAccount>({
  serialNum: props.transaction?.serialNum || '',
  transactionType: props.type,
  category: '' as any, // or default from CategorySchema.enum
  subCategory: '' as any,
  amount: '',
  currency: 'CNY',
  date: new Date().toISOString().split('T')[0],
  description: '',
  notes: null,
  accountSerialNum: '',
  tags: [],
  paymentMethod: 'Cash', // replace with default from PaymentMethodSchema.enum
  actualPayerAccount: 'Bank', // replace with default from AccountTypeSchema.enum
  transactionStatus: 'Completed',
  createdAt: new Date().toISOString(),
  updatedAt: null,
  account: props.accounts[0] || ({} as Account),
});

const emit = defineEmits<{
  close: [];
  save: [transaction: TransactionWithAccount];
}>();

// 模拟分类数据
const categories = ref(
  CategorySchema.options.map((name) => ({
    name,
    type: ['Salary', 'Investment'].includes(name) ? 'Income' : 'Expense',
  })),
);

const subcategories = ref(
  SubCategorySchema.options.map((name) => ({
    name,
    category: mapSubToCategory(name),
  })),
);

const mapSubToCategory = (sub: string): string => {
  if (['Restaurant', 'Groceries', 'Snacks'].includes(sub)) return 'Food';
  if (['Bus', 'Taxi', 'Fuel'].includes(sub)) return 'Transport';
  if (['Movies', 'Concerts'].includes(sub)) return 'Entertainment';
  if (['MonthlySalary', 'Bonus'].includes(sub)) return 'Salary';
  return 'Others';
};

const filteredCategories = computed(() => {
  return categories.value.filter((c) => c.type === form.value.transactionType);
});

const filteredSubcategories = computed(() => {
  return subcategories.value.filter((s) => s.category === form.value.category);
});

const getModalTitle = () => {
  const titles = {
    Income: '记录收入',
    Expense: '记录支出',
    Transfer: '转账记录',
  };
  return props.transaction ? '编辑交易' : titles[props.type];
};

const handleOverlayClick = () => {
  emit('close');
};

const handleSubmit = () => {
  const transaction: TransactionWithAccount = {
    ...form.value,
    serialNum: props.transaction?.serialNum || '',

    // 防止未填写的字段导致类型错误
    updatedAt: new Date().toISOString(),
    createdAt: props.transaction?.createdAt || new Date().toISOString(),
  };

  emit('save', transaction);
};

const formatCurrency = (amount: string) => {
  const num = parseFloat(amount);
  return num.toLocaleString('zh-CN', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
};

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

// 初始化表单数据
watch(
  () => props.transaction,
  (transaction) => {
    if (transaction) {
      form.value = {
        serialNum: transaction.serialNum,
        transactionType: transaction.transactionType,
        amount: transaction.amount,
        accountSerialNum: transaction.accountSerialNum,
        category: transaction.category,
        subCategory: transaction.subCategory || SubCategorySchema.enum.Other,
        currency: transaction.currency || 'CNY',
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
    } else {
      form.value = {
        serialNum: '',
        transactionType: props.type,
        amount: '',
        accountSerialNum: '',
        category: CategorySchema.enum.Others,
        subCategory: SubCategorySchema.enum.Other,
        currency: 'CNY',
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
