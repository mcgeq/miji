<script setup lang="ts">
import { computed, ref } from 'vue';
import { useMoneyStore } from '@/stores/moneyStore';
import { lowercaseFirstLetter } from '@/utils/common';
import type { Category } from '@/schema/money/category';

interface TopCategory {
  category: string;
  amount: number;
  count: number;
  percentage: number;
}

interface Props {
  topCategories: TopCategory[];
  topIncomeCategories?: TopCategory[];
  topTransferCategories?: TopCategory[];
  loading: boolean;
}

const props = defineProps<Props>();

const { t } = useI18n();
const moneyStore = useMoneyStore();

// 分类类型切换
const categoryType = ref<'expense' | 'income' | 'transfer'>('expense');

// 根据分类类型获取相应的分类数据
const currentCategories = computed(() => {
  switch (categoryType.value) {
    case 'income':
      return props.topIncomeCategories || [];
    case 'transfer':
      return props.topTransferCategories || [];
    case 'expense':
    default:
      return props.topCategories;
  }
});

// 获取分类类型的显示名称
const categoryTypeName = computed(() => {
  switch (categoryType.value) {
    case 'income':
      return '收入';
    case 'transfer':
      return '转账';
    case 'expense':
    default:
      return '支出';
  }
});

// 计算属性
const sortedCategories = computed(() => {
  return [...currentCategories.value].sort((a, b) => b.amount - a.amount);
});

const totalAmount = computed(() => {
  return currentCategories.value.reduce((sum, category) => sum + category.amount, 0);
});

const totalCount = computed(() => {
  return currentCategories.value.reduce((sum, category) => sum + category.count, 0);
});

// 方法
function formatAmount(amount: number) {
  return amount.toFixed(2);
}

function formatPercentage(amount: number) {
  if (totalAmount.value === 0) return '0.00';
  return ((amount / totalAmount.value) * 100).toFixed(2);
}

function getCategoryIcon(category: string) {
  // 从MoneyStore中获取分类数据，转换为Record<string, string>格式
  const iconMap: Record<string, string> = moneyStore.categories.reduce((acc, categoryItem: Category) => {
    acc[categoryItem.name] = categoryItem.icon;
    return acc;
  }, {} as Record<string, string>);

  return iconMap[category] || '📦';
}
</script>

<template>
  <div class="transaction-stats-table">
    <div class="table-header">
      <h3 class="table-title">
        {{ categoryTypeName }}分类详细统计
      </h3>
      <div class="table-controls">
        <div class="control-group">
          <label class="control-label">分类类型:</label>
          <select v-model="categoryType" class="control-select">
            <option value="expense">
              支出
            </option>
            <option value="income">
              收入
            </option>
            <option value="transfer">
              转账
            </option>
          </select>
        </div>
      </div>
      <div class="table-summary">
        <div class="summary-item">
          <span class="summary-label">总金额:</span>
          <span class="summary-value">¥{{ formatAmount(totalAmount) }}</span>
        </div>
        <div class="summary-item">
          <span class="summary-label">总笔数:</span>
          <span class="summary-value">{{ totalCount }}笔</span>
        </div>
      </div>
    </div>

    <div class="table-content">
      <div v-if="loading" class="table-loading">
        <div class="loading-spinner" />
        <div class="loading-text">
          加载中...
        </div>
      </div>

      <div v-else-if="currentCategories.length === 0" class="table-empty">
        <div class="empty-icon">
          📊
        </div>
        <div class="empty-text">
          暂无统计数据
        </div>
      </div>

      <div v-else class="table-wrapper">
        <table class="stats-table">
          <thead>
            <tr>
              <th class="col-rank">
                排名
              </th>
              <th class="col-category">
                分类
              </th>
              <th class="col-amount">
                金额
              </th>
              <th class="col-percentage">
                占比
              </th>
              <th class="col-count">
                笔数
              </th>
              <th class="col-average">
                平均
              </th>
              <th class="col-trend">
                趋势
              </th>
            </tr>
          </thead>
          <tbody>
            <tr
              v-for="(category, index) in sortedCategories"
              :key="category.category"
              class="table-row"
            >
              <td class="col-rank">
                <div class="rank-badge" :class="`rank-${index + 1}`">
                  {{ index + 1 }}
                </div>
              </td>
              <td class="col-category">
                <div class="category-cell">
                  <span class="category-icon">
                    {{ getCategoryIcon(category.category) }}
                  </span>
                  <span class="category-name">
                    {{ t(`common.categories.${lowercaseFirstLetter(category.category)}`) }}
                  </span>
                </div>
              </td>
              <td class="col-amount">
                <div class="amount-cell">
                  <span class="amount-value">
                    ¥{{ formatAmount(category.amount) }}
                  </span>
                </div>
              </td>
              <td class="col-percentage">
                <div class="percentage-cell">
                  <div class="percentage-bar">
                    <div
                      class="percentage-fill"
                      :style="{ width: `${formatPercentage(category.amount)}%` }"
                    />
                  </div>
                  <span class="percentage-text">
                    {{ formatPercentage(category.amount) }}%
                  </span>
                </div>
              </td>
              <td class="col-count">
                <div class="count-cell">
                  <span class="count-value">
                    {{ category.count }}
                  </span>
                  <span class="count-unit">
                    笔
                  </span>
                </div>
              </td>
              <td class="col-average">
                <div class="average-cell">
                  <span class="average-value">
                    ¥{{ formatAmount(category.amount / category.count) }}
                  </span>
                </div>
              </td>
              <td class="col-trend">
                <div class="trend-cell">
                  <div class="trend-indicator">
                    <div class="trend-bar">
                      <div
                        class="trend-fill"
                        :style="{ width: `${(category.amount / totalAmount) * 100}%` }"
                      />
                    </div>
                  </div>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <!-- 导出功能 -->
    <div class="table-actions">
      <button class="export-btn">
        📊 导出数据
      </button>
      <button class="export-btn">
        📈 生成报告
      </button>
    </div>
  </div>
</template>

<style scoped lang="postcss">
.transaction-stats-table {
  background: var(--color-base-100);
  border: 1px solid var(--color-base-300);
  border-radius: 0.5rem;
  overflow: hidden;
}

.table-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 1rem 1.5rem;
  background: var(--color-base-200);
  border-bottom: 1px solid var(--color-base-300);
}

.table-title {
  font-size: 1.125rem;
  font-weight: 600;
  color: var(--color-accent-content);
}

.table-controls {
  display: flex;
  align-items: center;
  gap: 1rem;
}

.control-group {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.control-label {
  font-size: 0.875rem;
  color: var(--color-neutral);
  font-weight: 500;
}

.control-select {
  padding: 0.375rem 0.75rem;
  border: 1px solid var(--color-base-300);
  border-radius: 0.25rem;
  background: var(--color-base-100);
  color: var(--color-accent-content);
  font-size: 0.875rem;
  cursor: pointer;
  transition: all 0.2s ease;
}

.control-select:hover {
  border-color: var(--color-primary);
}

.control-select:focus {
  outline: none;
  border-color: var(--color-primary);
  box-shadow: 0 0 0 2px var(--color-primary-light);
}

.table-summary {
  display: flex;
  gap: 1rem;
}

.summary-item {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.summary-label {
  font-size: 0.875rem;
  color: var(--color-neutral);
}

.summary-value {
  font-size: 0.875rem;
  font-weight: 600;
  color: var(--color-accent-content);
}

.table-content {
  min-height: 400px;
}

.table-loading {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  height: 400px;
  gap: 1rem;
}

.loading-spinner {
  width: 40px;
  height: 40px;
  border: 3px solid var(--color-base-300);
  border-top: 3px solid var(--color-primary);
  border-radius: 50%;
  animation: spin 1s linear infinite;
}

@keyframes spin {
  0% { transform: rotate(0deg); }
  100% { transform: rotate(360deg); }
}

.loading-text {
  color: var(--color-neutral);
  font-size: 0.875rem;
}

.table-empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  height: 400px;
  gap: 1rem;
}

.empty-icon {
  font-size: 3rem;
  opacity: 0.5;
}

.empty-text {
  color: var(--color-neutral);
  font-size: 0.875rem;
}

.table-wrapper {
  overflow-x: auto;
}

.stats-table {
  width: 100%;
  border-collapse: collapse;
}

.stats-table th {
  background: var(--color-base-200);
  color: var(--color-neutral);
  font-size: 0.875rem;
  font-weight: 600;
  text-align: left;
  padding: 0.75rem 1rem;
  border-bottom: 1px solid var(--color-base-300);
}

.stats-table td {
  padding: 0.75rem 1rem;
  border-bottom: 1px solid var(--color-base-200);
  vertical-align: middle;
}

.table-row:hover {
  background: var(--color-base-50);
}

.table-row:last-child td {
  border-bottom: none;
}

/* 排名列 */
.col-rank {
  width: 60px;
  text-align: center;
}

.rank-badge {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 24px;
  height: 24px;
  border-radius: 50%;
  font-size: 0.75rem;
  font-weight: 600;
  color: white;
}

.rank-1 {
  background: #ffd700;
}

.rank-2 {
  background: #c0c0c0;
}

.rank-3 {
  background: #cd7f32;
}

.rank-badge:not(.rank-1):not(.rank-2):not(.rank-3) {
  background: var(--color-base-300);
  color: var(--color-neutral);
}

/* 分类列 */
.col-category {
  min-width: 120px;
}

.category-cell {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.category-icon {
  font-size: 1rem;
}

.category-name {
  font-size: 0.875rem;
  color: var(--color-accent-content);
  font-weight: 500;
}

/* 金额列 */
.col-amount {
  text-align: right;
  min-width: 100px;
}

.amount-value {
  font-size: 0.875rem;
  font-weight: 600;
  color: var(--color-accent-content);
}

/* 占比列 */
.col-percentage {
  min-width: 120px;
}

.percentage-cell {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.percentage-bar {
  flex: 1;
  height: 6px;
  background: var(--color-base-200);
  border-radius: 3px;
  overflow: hidden;
}

.percentage-fill {
  height: 100%;
  background: var(--color-primary);
  border-radius: 3px;
  transition: width 0.3s ease;
}

.percentage-text {
  font-size: 0.75rem;
  color: var(--color-neutral);
  min-width: 40px;
  text-align: right;
}

/* 笔数列 */
.col-count {
  text-align: center;
  min-width: 80px;
}

.count-cell {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.25rem;
}

.count-value {
  font-size: 0.875rem;
  font-weight: 600;
  color: var(--color-accent-content);
}

.count-unit {
  font-size: 0.75rem;
  color: var(--color-neutral);
}

/* 平均列 */
.col-average {
  text-align: right;
  min-width: 100px;
}

.average-value {
  font-size: 0.875rem;
  color: var(--color-neutral);
}

/* 趋势列 */
.col-trend {
  min-width: 80px;
}

.trend-cell {
  display: flex;
  align-items: center;
  justify-content: center;
}

.trend-indicator {
  width: 100%;
}

.trend-bar {
  height: 4px;
  background: var(--color-base-200);
  border-radius: 2px;
  overflow: hidden;
}

.trend-fill {
  height: 100%;
  background: linear-gradient(90deg, var(--color-primary), var(--color-secondary));
  border-radius: 2px;
  transition: width 0.3s ease;
}

/* 表格操作 */
.table-actions {
  display: flex;
  justify-content: flex-end;
  gap: 1rem;
  padding: 1rem 1.5rem;
  background: var(--color-base-200);
  border-top: 1px solid var(--color-base-300);
}

.export-btn {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.5rem 1rem;
  background: var(--color-primary);
  color: white;
  border: none;
  border-radius: 0.25rem;
  font-size: 0.875rem;
  cursor: pointer;
  transition: all 0.2s ease;
}

.export-btn:hover {
  background: var(--color-primary-dark);
}

@media (max-width: 768px) {
  .table-header {
    flex-direction: column;
    gap: 1rem;
    align-items: flex-start;
  }

  .table-controls {
    width: 100%;
    justify-content: flex-start;
  }

  .table-summary {
    flex-direction: column;
    gap: 0.5rem;
  }

  .stats-table th,
  .stats-table td {
    padding: 0.5rem;
  }

  .table-actions {
    flex-direction: column;
  }

  .export-btn {
    justify-content: center;
  }
}
</style>
