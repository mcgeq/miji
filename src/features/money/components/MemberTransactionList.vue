<script setup lang="ts">
import { LucideArrowDown, LucideArrowUp, LucideFilter, LucideSearch } from 'lucide-vue-next';
import { MoneyDb } from '@/services/money/money';
import type { Transaction } from '@/schema/money';

interface Props {
  memberSerialNum: string;
}

const props = defineProps<Props>();

const transactions = ref<Transaction[]>([]);
const loading = ref(true);
const searchKeyword = ref('');
const filterType = ref<'all' | 'Income' | 'Expense'>('all');

// 加载交易记录
onMounted(async () => {
  await loadTransactions();
});

async function loadTransactions() {
  loading.value = true;
  try {
    // 获取所有交易，然后筛选包含该成员的交易
    const allTransactions = await MoneyDb.listTransactions();
    transactions.value = allTransactions.filter(transaction => {
      // 检查是否是该成员创建的或参与分摊的
      return transaction.splitMembers?.some(member => member.serialNum === props.memberSerialNum);
    });
  } catch (error) {
    console.error('Failed to load member transactions:', error);
  } finally {
    loading.value = false;
  }
}

// 筛选后的交易列表
const filteredTransactions = computed(() => {
  let result = transactions.value;

  // 按类型筛选
  if (filterType.value !== 'all') {
    result = result.filter(t => t.transactionType === filterType.value);
  }

  // 按关键词搜索
  if (searchKeyword.value) {
    const keyword = searchKeyword.value.toLowerCase();
    result = result.filter(t =>
      t.description?.toLowerCase().includes(keyword) ||
      t.category?.toLowerCase().includes(keyword),
    );
  }

  // 按日期倒序排序
  return result.sort((a, b) =>
    new Date(b.date).getTime() - new Date(a.date).getTime(),
  );
});

// 格式化日期
function formatDate(dateStr: string): string {
  const date = new Date(dateStr);
  return date.toLocaleDateString('zh-CN', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  });
}

// 格式化金额
function formatAmount(amount: number): string {
  return `¥${amount.toFixed(2)}`;
}

// 获取交易类型样式
function getTypeClass(type: string): string {
  return type === 'Income' ? 'income' : 'expense';
}

// 获取交易类型图标
function getTypeIcon(type: string) {
  return type === 'Income' ? LucideArrowDown : LucideArrowUp;
}
</script>

<template>
  <div class="member-transaction-list">
    <!-- 工具栏 -->
    <div class="toolbar">
      <div class="search-box">
        <LucideSearch class="search-icon" />
        <input
          v-model="searchKeyword"
          type="text"
          placeholder="搜索交易..."
          class="search-input"
        >
      </div>

      <div class="filter-group">
        <LucideFilter class="filter-icon" />
        <select v-model="filterType" class="filter-select">
          <option value="all">
            全部类型
          </option>
          <option value="Income">
            收入
          </option>
          <option value="Expense">
            支出
          </option>
        </select>
      </div>
    </div>

    <!-- 加载状态 -->
    <div v-if="loading" class="loading-state">
      <div class="spinner" />
      <span>加载中...</span>
    </div>

    <!-- 交易列表 -->
    <div v-else-if="filteredTransactions.length > 0" class="transaction-list">
      <div
        v-for="transaction in filteredTransactions"
        :key="transaction.serialNum"
        class="transaction-item"
      >
        <div class="transaction-icon" :class="getTypeClass(transaction.transactionType)">
          <component :is="getTypeIcon(transaction.transactionType)" class="icon" />
        </div>

        <div class="transaction-info">
          <div class="transaction-header">
            <h4 class="transaction-desc">
              {{ transaction.description }}
            </h4>
            <span class="transaction-amount" :class="getTypeClass(transaction.transactionType)">
              {{ transaction.transactionType === 'Income' ? '+' : '-' }}
              {{ formatAmount(transaction.amount) }}
            </span>
          </div>

          <div class="transaction-meta">
            <span class="transaction-date">{{ formatDate(transaction.date) }}</span>
            <span class="transaction-category">{{ transaction.category }}</span>
            <span v-if="transaction.splitMembers && transaction.splitMembers.length > 0" class="split-badge">
              分摊 {{ transaction.splitMembers.length }} 人
            </span>
          </div>
        </div>
      </div>
    </div>

    <!-- 空状态 -->
    <div v-else class="empty-state">
      <p>暂无交易记录</p>
    </div>

    <!-- 统计信息 -->
    <div v-if="!loading && filteredTransactions.length > 0" class="summary">
      <span>共 {{ filteredTransactions.length }} 笔交易</span>
    </div>
  </div>
</template>

<style scoped>
.member-transaction-list {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

/* 工具栏 */
.toolbar {
  display: flex;
  gap: 1rem;
  flex-wrap: wrap;
}

.search-box {
  flex: 1;
  min-width: 200px;
  position: relative;
  display: flex;
  align-items: center;
}

.search-icon {
  position: absolute;
  left: 0.75rem;
  width: 18px;
  height: 18px;
  color: var(--color-gray-400);
  pointer-events: none;
}

.search-input {
  width: 100%;
  padding: 0.5rem 0.75rem 0.5rem 2.5rem;
  border: 1px solid var(--color-base-300);
  border-radius: 8px;
  font-size: 0.875rem;
  transition: all 0.2s;
}

.search-input:focus {
  outline: none;
  border-color: var(--color-primary);
  box-shadow: 0 0 0 3px oklch(from var(--color-primary) l c h / 0.1);
}

.filter-group {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.filter-icon {
  width: 18px;
  height: 18px;
  color: var(--color-gray-500);
}

.filter-select {
  padding: 0.5rem 0.75rem;
  border: 1px solid var(--color-base-300);
  border-radius: 8px;
  font-size: 0.875rem;
  cursor: pointer;
  transition: all 0.2s;
}

.filter-select:hover {
  border-color: var(--color-primary);
}

/* 加载状态 */
.loading-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 0.5rem;
  padding: 3rem 0;
  color: var(--color-gray-500);
}

.spinner {
  width: 32px;
  height: 32px;
  border: 3px solid var(--color-base-300);
  border-top-color: var(--color-primary);
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

/* 交易列表 */
.transaction-list {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

.transaction-item {
  display: flex;
  align-items: center;
  gap: 1rem;
  padding: 1rem;
  background: var(--color-base-100);
  border: 1px solid var(--color-base-300);
  border-radius: 8px;
  transition: all 0.2s;
}

.transaction-item:hover {
  background: white;
  box-shadow: var(--shadow-sm);
  transform: translateY(-1px);
}

.transaction-icon {
  width: 40px;
  height: 40px;
  border-radius: 8px;
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
}

.transaction-icon.income {
  background: #d1fae5;
  color: #059669;
}

.transaction-icon.expense {
  background: #fee2e2;
  color: #dc2626;
}

.transaction-icon .icon {
  width: 20px;
  height: 20px;
}

.transaction-info {
  flex: 1;
  min-width: 0;
}

.transaction-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 1rem;
  margin-bottom: 0.5rem;
}

.transaction-desc {
  margin: 0;
  font-size: 1rem;
  font-weight: 500;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.transaction-amount {
  font-size: 1.125rem;
  font-weight: 600;
  white-space: nowrap;
}

.transaction-amount.income {
  color: #059669;
}

.transaction-amount.expense {
  color: #dc2626;
}

.transaction-meta {
  display: flex;
  gap: 1rem;
  flex-wrap: wrap;
  font-size: 0.875rem;
  color: var(--color-gray-500);
}

.transaction-category {
  padding: 0.125rem 0.5rem;
  background: var(--color-base-200);
  border-radius: 4px;
}

.split-badge {
  padding: 0.125rem 0.5rem;
  background: #dbeafe;
  color: #1e40af;
  border-radius: 4px;
  font-weight: 500;
}

/* 空状态 */
.empty-state {
  text-align: center;
  padding: 3rem 0;
  color: var(--color-gray-500);
}

/* 统计信息 */
.summary {
  padding: 0.75rem 1rem;
  background: var(--color-base-100);
  border-radius: 8px;
  text-align: center;
  font-size: 0.875rem;
  color: var(--color-gray-600);
}

/* 响应式 */
@media (max-width: 768px) {
  .transaction-header {
    flex-direction: column;
    align-items: flex-start;
  }

  .transaction-meta {
    gap: 0.5rem;
  }
}
</style>
