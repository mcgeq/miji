<template>
  <div class="min-h-50">
    <div v-if="loading" class="flex-justify-center h-50 text-gray-600">
      加载中...
    </div>
    <div
      v-else-if="transactions.length === 0"
      class="flex-justify-center flex-col h-50 text-gray-400"
    >
      <div class="text-6xl mb-4 opacity-50">
        <i class="icon-list"></i>
      </div>
      <div class="text-base">暂无交易记录</div>
    </div>

    <div v-else class="border border-gray-200 rounded-lg overflow-hidden">
      <div
        class="hidden md:grid md:grid-cols-[120px_140px_180px_140px_140px_120px] bg-gray-100 border-b border-gray-200 font-semibold text-gray-800"
      >
        <div class="p-4 text-sm grid place-items-center">类型</div>
        <div class="p-4 text-sm grid place-items-center">金额</div>
        <div class="p-4 text-sm grid place-items-center">账户</div>
        <div class="p-4 text-sm grid place-items-center">分类</div>
        <div class="p-4 text-sm grid place-items-center">时间</div>
        <div class="p-4 text-sm grid place-items-center">操作</div>
      </div>

      <div
        v-for="transaction in transactions"
        :key="transaction.serialNum"
        class="grid grid-cols-1 md:grid-cols-[120px_140px_180px_140px_140px_120px] border-b border-gray-200 hover:bg-gray-50"
      >
        <!-- 类型列 -->
        <div class="p-4 text-sm flex justify-between md:justify-center md:items-center">
          <span class="md:hidden text-gray-600 font-semibold">类型</span>
          <div class="flex items-center gap-2">
            <component :is="getTransactionTypeIcon(transaction.transactionType)" class="w-4 h-4" />
            <span>{{ getTransactionTypeName(transaction.transactionType) }}</span>
          </div>
        </div>

        <!-- 金额列 -->
        <div class="p-4 text-sm flex justify-between md:justify-center md:items-center">
          <span class="md:hidden text-gray-600 font-semibold">金额</span>
          <div
            :class="[
              'font-semibold',
              transaction.transactionType === TransactionTypeSchema.enum.Income ? 'text-green-600' :
              transaction.transactionType === TransactionTypeSchema.enum.Expense ? 'text-red-500' :
              'text-blue-500'
            ]"
          >
            {{ transaction.transactionType === TransactionTypeSchema.enum.Expense ? '-' : '+' }}{{ formatCurrency(transaction.amount) }}
          </div>
        </div>

        <!-- 账户列 -->
        <div class="p-4 text-sm flex justify-between md:justify-center md:items-center">
          <span class="md:hidden text-gray-600 font-semibold">账户</span>
          <div class="md:text-center">
            <div class="font-medium text-gray-800">{{ transaction.account.name}}</div>
            <!-- <div v-if="transaction.toAccountName" class="text-xs text-gray-600">→ {{ transaction.toAccountName }}</div> -->
          </div>
        </div>

        <!-- 分类列 -->
        <div class="p-4 text-sm flex justify-between md:justify-center md:items-center">
          <span class="md:hidden text-gray-600 font-semibold">分类</span>
          <div class="md:text-center">
            <span class="font-medium text-gray-800">{{ transaction.category}}</span>
            <div v-if="transaction.subCategory" class="text-xs text-gray-600">/ {{ transaction.subCategory}}</div>
          </div>
        </div>

        <!-- 时间列 -->
        <div class="p-4 text-sm flex justify-between md:justify-center md:items-center">
          <span class="md:hidden text-gray-600 font-semibold">时间</span>
          <div class="md:text-center">
            <div class="font-medium text-gray-800">{{ formatDate(transaction.date) }}</div>
            <div class="text-xs text-gray-600 text-right">{{ formatTime(transaction.createdAt) }}</div>
          </div>
        </div>
        <!-- 操作列 - 始终靠右 -->
        <div class="p-4 text-sm flex justify-end gap-2">
          <button
            class="money-option-btn hover:(border-green-500 text-green-500)"
            @click="emit('view-details', transaction)"
            title="查看详情"
          >
            <Eye class="w-4 h-4" />
          </button>
          <button
            class=" money-option-btn hover:(border-blue-500 text-blue-500)"
            @click="emit('edit', transaction)"
            title="编辑"
          >
            <Edit class="w-4 h-4" />
          </button>
          <button
            class="money-option-btn hover:(border-red-500 text-red-500)"
            @click="emit('delete', transaction.serialNum)"
            title="删除"
          >
            <Trash class="w-4 h-4" />
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import {
  Trash,
  Edit,
  Eye,
  TrendingUp,
  TrendingDown,
  Repeat,
} from 'lucide-vue-next';
import { TransactionType, TransactionTypeSchema } from '@/schema/common';
import { TransactionWithAccount } from '@/schema/money';
import { formatDate } from '@/utils/date';

interface Props {
  transactions: TransactionWithAccount[];
  loading: boolean;
}

defineProps<Props>();

const emit = defineEmits<{
  edit: [transaction: TransactionWithAccount];
  delete: [serialNum: string];
  'view-details': [transaction: TransactionWithAccount];
}>();

const getTransactionTypeIcon = (type: TransactionType) => {
  const icons = {
    Income: TrendingUp,
    Expense: TrendingDown,
    Transfer: Repeat,
  };
  return icons[type] || 'icon-list';
};

const getTransactionTypeName = (type: TransactionType) => {
  const names = {
    Income: '收入',
    Expense: '支出',
    Transfer: '转账',
  };
  return names[type] || '未知';
};

const formatCurrency = (amount: string) => {
  const num = parseFloat(amount);
  return num.toLocaleString('zh-CN', {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  });
};

const formatTime = (dateStr: string) => {
  return new Date(dateStr).toLocaleTimeString('zh-CN', {
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
  });
};
</script>
