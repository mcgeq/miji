<script setup lang="ts">
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

// 获取交易类型样式
function getTransactionTypeClass(type: string): string {
  const classes: Record<string, string> = {
    EXPENSE: 'type-expense',
    INCOME: 'type-income',
    TRANSFER: 'type-transfer',
  };
  return classes[type] || '';
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
  <div class="ledger-transaction-list">
    <div class="list-header">
      <h3 class="list-title">
        账本交易记录
      </h3>
      <div class="list-actions">
        <button class="btn-refresh" @click="loadTransactions">
          <LucideRefreshCw :class="{ spinning: loading }" />
        </button>
      </div>
    </div>

    <div v-if="loading" class="loading-state">
      <div class="loading-spinner" />
      <p>加载中...</p>
    </div>

    <div v-else-if="transactions.length === 0" class="empty-state">
      <LucideInbox class="empty-icon" />
      <p class="empty-text">
        暂无交易记录
      </p>
      <p class="empty-hint">
        在此账本中创建交易后将显示在这里
      </p>
    </div>

    <div v-else class="transaction-list">
      <div
        v-for="transaction in transactions"
        :key="transaction.serialNum"
        class="transaction-item"
        @click="handleTransactionClick(transaction)"
      >
        <div class="transaction-main">
          <div class="transaction-info">
            <div class="transaction-description">
              {{ transaction.description || '无描述' }}
            </div>
            <div class="transaction-meta">
              <span class="transaction-type" :class="[getTransactionTypeClass(transaction.transactionType)]">
                {{ getTransactionTypeLabel(transaction.transactionType) }}
              </span>
              <span class="transaction-category">
                {{ transaction.category }}
                <template v-if="transaction.subCategory">
                  / {{ transaction.subCategory }}
                </template>
              </span>
              <span class="transaction-date">
                {{ formatDate(transaction.date) }}
              </span>
            </div>
          </div>
          <div class="transaction-amount" :class="[getTransactionTypeClass(transaction.transactionType)]">
            {{ formatAmount(transaction.amount, typeof transaction.currency === 'string' ? transaction.currency : transaction.currency.code) }}
          </div>
        </div>
        <div v-if="transaction.notes" class="transaction-notes">
          {{ transaction.notes }}
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.ledger-transaction-list {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.list-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 1rem;
  background: var(--component-bg-primary);
  border-radius: var(--border-radius-md);
}

.list-title {
  font-size: 1.125rem;
  font-weight: 600;
  color: var(--text-primary);
  margin: 0;
}

.list-actions {
  display: flex;
  gap: 0.5rem;
}

.btn-refresh {
  padding: 0.5rem;
  background: transparent;
  border: 1px solid var(--border-color);
  border-radius: var(--border-radius-sm);
  cursor: pointer;
  transition: all 0.2s;
  color: var(--text-secondary);
}

.btn-refresh:hover {
  background: var(--component-bg-secondary);
  border-color: var(--primary-color);
  color: var(--primary-color);
}

.spinning {
  animation: spin 1s linear infinite;
}

@keyframes spin {
  from {
    transform: rotate(0deg);
  }
  to {
    transform: rotate(360deg);
  }
}

.loading-state,
.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 3rem 1rem;
  background: var(--component-bg-primary);
  border-radius: var(--border-radius-md);
  color: var(--text-secondary);
}

.loading-spinner {
  width: 2rem;
  height: 2rem;
  border: 3px solid var(--border-color);
  border-top-color: var(--primary-color);
  border-radius: 50%;
  animation: spin 1s linear infinite;
  margin-bottom: 1rem;
}

.empty-icon {
  width: 3rem;
  height: 3rem;
  color: var(--text-muted);
  margin-bottom: 1rem;
}

.empty-text {
  font-size: 1rem;
  font-weight: 500;
  margin: 0 0 0.5rem 0;
}

.empty-hint {
  font-size: 0.875rem;
  color: var(--text-muted);
  margin: 0;
}

.transaction-list {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.transaction-item {
  padding: 1rem;
  background: var(--component-bg-primary);
  border: 1px solid var(--border-color);
  border-radius: var(--border-radius-md);
  cursor: pointer;
  transition: all 0.2s;
}

.transaction-item:hover {
  border-color: var(--primary-color);
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
  transform: translateY(-1px);
}

.transaction-main {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 1rem;
}

.transaction-info {
  flex: 1;
  min-width: 0;
}

.transaction-description {
  font-size: 1rem;
  font-weight: 500;
  color: var(--text-primary);
  margin-bottom: 0.5rem;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.transaction-meta {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  font-size: 0.875rem;
  color: var(--text-secondary);
  flex-wrap: wrap;
}

.transaction-type {
  padding: 0.125rem 0.5rem;
  border-radius: var(--border-radius-sm);
  font-weight: 500;
  font-size: 0.75rem;
}

.type-expense {
  background: var(--error-bg);
  color: var(--error-color);
}

.type-income {
  background: var(--success-bg);
  color: var(--success-color);
}

.type-transfer {
  background: var(--info-bg);
  color: var(--info-color);
}

.transaction-category {
  color: var(--text-muted);
}

.transaction-date {
  color: var(--text-muted);
}

.transaction-amount {
  font-size: 1.125rem;
  font-weight: 600;
  white-space: nowrap;
}

.transaction-amount.type-expense {
  color: var(--error-color);
}

.transaction-amount.type-income {
  color: var(--success-color);
}

.transaction-amount.type-transfer {
  color: var(--info-color);
}

.transaction-notes {
  margin-top: 0.75rem;
  padding-top: 0.75rem;
  border-top: 1px solid var(--border-color);
  font-size: 0.875rem;
  color: var(--text-secondary);
  line-height: 1.5;
}
</style>
