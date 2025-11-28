<script setup lang="ts">
import { Button, Card, Spinner } from '@/components/ui';
import { MoneyDb } from '@/services/money/money';
import { Lg } from '@/utils/debugLog';
import type { FamilyLedgerTransaction, Transaction } from '@/schema/money';

interface Props {
  ledgerSerialNum: string;
}

const props = defineProps<Props>();
const emit = defineEmits(['transactionClick', 'refresh']);

const loading = ref(false);
const transactions = ref<Transaction[]>([]);
const associations = ref<FamilyLedgerTransaction[]>([]);

// 加载账本关联的交易
async function loadTransactions() {
  loading.value = true;
  try {
    // 1. 获取账本的交易关联
    associations.value = await MoneyDb.listFamilyLedgerTransactionsByLedger(props.ledgerSerialNum);

    // 2. 获取交易详情
    const transactionPromises = associations.value.map(assoc =>
      MoneyDb.getTransaction(assoc.transactionSerialNum),
    );
    const results = await Promise.all(transactionPromises);
    transactions.value = results.filter(t => t !== null) as Transaction[];

    Lg.d('FamilyLedgerTransactionList', `Loaded ${transactions.value.length} transactions`);
  } catch (error) {
    Lg.e('FamilyLedgerTransactionList', 'Failed to load transactions:', error);
  } finally {
    loading.value = false;
  }
}

// 格式化金额
function formatAmount(amount: number, currency: string = 'CNY'): string {
  return new Intl.NumberFormat('zh-CN', {
    style: 'currency',
    currency,
  }).format(amount);
}

// 格式化日期
function formatDate(dateStr: string): string {
  const date = new Date(dateStr);
  return date.toLocaleDateString('zh-CN', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  });
}

// 获取交易类型标签
function getTransactionTypeLabel(type: string): string {
  const labels: Record<string, string> = {
    EXPENSE: '支出',
    INCOME: '收入',
    TRANSFER: '转账',
  };
  return labels[type] || type;
}

// 获取交易类型样式类
function getTransactionTypeBadgeClass(type: string): string {
  const classes: Record<string, string> = {
    EXPENSE: 'bg-red-100 dark:bg-red-900/30 text-red-600 dark:text-red-400',
    INCOME: 'bg-green-100 dark:bg-green-900/30 text-green-600 dark:text-green-400',
    TRANSFER: 'bg-blue-100 dark:bg-blue-900/30 text-blue-600 dark:text-blue-400',
  };
  return classes[type] || 'bg-gray-100 dark:bg-gray-800 text-gray-600 dark:text-gray-400';
}

// 获取金额颜色
function getAmountColorClass(type: string): string {
  const classes: Record<string, string> = {
    EXPENSE: 'text-red-600 dark:text-red-400',
    INCOME: 'text-green-600 dark:text-green-400',
    TRANSFER: 'text-blue-600 dark:text-blue-400',
  };
  return classes[type] || 'text-gray-900 dark:text-white';
}

// 处理交易点击
function handleTransactionClick(transaction: Transaction) {
  emit('transactionClick', transaction);
}

// 监听账本变化
watch(() => props.ledgerSerialNum, () => {
  loadTransactions();
}, { immediate: true });

// 暴露刷新方法
defineExpose({
  refresh: loadTransactions,
});
</script>

<template>
  <div class="flex flex-col gap-4">
    <Card padding="md">
      <div class="flex items-center justify-between">
        <h3 class="text-lg font-semibold text-gray-900 dark:text-white">
          账本交易记录
        </h3>
        <Button variant="secondary" size="sm" @click="loadTransactions">
          <LucideRefreshCw :size="16" :class="loading && 'animate-spin'" />
        </Button>
      </div>
    </Card>

    <Card v-if="loading" padding="lg">
      <div class="flex flex-col items-center justify-center py-12 text-gray-500 dark:text-gray-400">
        <Spinner size="lg" />
        <p class="mt-4">
          加载中...
        </p>
      </div>
    </Card>

    <Card v-else-if="transactions.length === 0" padding="lg">
      <div class="flex flex-col items-center justify-center py-12 text-center">
        <LucideInbox :size="48" class="text-gray-400 dark:text-gray-600 mb-4" />
        <p class="text-base font-medium text-gray-900 dark:text-white mb-2">
          暂无交易记录
        </p>
        <p class="text-sm text-gray-500 dark:text-gray-400">
          在此账本中创建交易后将显示在这里
        </p>
      </div>
    </Card>

    <div v-else class="flex flex-col gap-3">
      <Card
        v-for="transaction in transactions"
        :key="transaction.serialNum"
        padding="md"
        hoverable
        class="cursor-pointer transition-all duration-200 hover:-translate-y-0.5"
        @click="handleTransactionClick(transaction)"
      >
        <div class="flex items-center justify-between gap-4 mb-3">
          <div class="flex-1 min-w-0">
            <div class="font-medium text-gray-900 dark:text-white mb-2 overflow-hidden text-ellipsis whitespace-nowrap">
              {{ transaction.description || '无描述' }}
            </div>
            <div class="flex items-center gap-3 text-sm text-gray-600 dark:text-gray-400 flex-wrap">
              <span class="px-2 py-0.5 rounded text-xs font-medium" :class="getTransactionTypeBadgeClass(transaction.transactionType)">
                {{ getTransactionTypeLabel(transaction.transactionType) }}
              </span>
              <span class="text-gray-500 dark:text-gray-500">
                {{ transaction.category }}
                <template v-if="transaction.subCategory">
                  / {{ transaction.subCategory }}
                </template>
              </span>
              <span class="text-gray-500 dark:text-gray-500">
                {{ formatDate(transaction.date) }}
              </span>
            </div>
          </div>
          <div class="text-lg font-semibold whitespace-nowrap" :class="getAmountColorClass(transaction.transactionType)">
            {{ formatAmount(transaction.amount, typeof transaction.currency === 'string' ? transaction.currency : transaction.currency.code) }}
          </div>
        </div>
        <div v-if="transaction.notes" class="mt-3 pt-3 border-t border-gray-200 dark:border-gray-700 text-sm text-gray-600 dark:text-gray-400 leading-relaxed">
          {{ transaction.notes }}
        </div>
      </Card>
    </div>
  </div>
</template>
