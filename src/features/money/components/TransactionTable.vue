<script setup lang="ts">
import {
  LucideEye,
  LucidePencil,
  LucideTrash2,
  LucideUsers,
  Repeat,
  TrendingDown,
  TrendingUp,
} from 'lucide-vue-next';
import { TransactionTypeSchema } from '@/schema/common';
import { lowercaseFirstLetter } from '@/utils/common';
import { DateUtils } from '@/utils/date';
import { formatCurrency } from '../utils/money';
import type { Transaction } from '@/schema/money';

interface Props {
  transactions: Transaction[];
  loading?: boolean;
  showActions?: boolean; // 是否显示操作按钮
  columns?: string[]; // 要显示的列
  compact?: boolean; // 紧凑模式
  emptyText?: string; // 空状态文案
  layout?: 'table' | 'card'; // 布局模式：table 表格 / card 卡片
  disabledEditTransactions?: Set<string>; // 禁用编辑的交易ID
  disabledDeleteTransactions?: Set<string>; // 禁用删除的交易ID
}

const props = withDefaults(defineProps<Props>(), {
  loading: false,
  showActions: false,
  columns: () => ['date', 'type', 'amount', 'account', 'category', 'description'],
  compact: false,
  emptyText: '暂无交易记录',
  layout: 'table',
  disabledEditTransactions: () => new Set(),
  disabledDeleteTransactions: () => new Set(),
});

const emit = defineEmits<{
  edit: [transaction: Transaction];
  delete: [transaction: Transaction];
  view: [transaction: Transaction];
  viewSplit: [transaction: Transaction];
}>();

const { t } = useI18n();

// 判断是否显示某列
const showColumn = (columnName: string) => props.columns.includes(columnName);

// 获取交易类型显示文本
function getTransactionTypeText(type: string) {
  const typeMap: Record<string, string> = {
    Expense: '支出',
    Income: '收入',
    Transfer: '转账',
  };
  return typeMap[type] || type;
}

// 获取交易类型样式类
function getTransactionTypeClass(type: string) {
  const classMap: Record<string, string> = {
    Expense: 'type-expense',
    Income: 'type-income',
    Transfer: 'type-transfer',
  };
  return classMap[type] || '';
}

// 格式化日期为 yyyy-MM-dd
function formatDate(dateString: string) {
  return new Date(dateString).toISOString().split('T')[0];
}

// 获取分类名称
function getCategoryName(category: string) {
  if (!category) return '—';
  return t(`common.categories.${lowercaseFirstLetter(category)}`);
}

// 获取子分类名称
function getSubCategoryName(subCategory: string | null | undefined) {
  if (!subCategory) return '';
  return t(`common.subCategories.${lowercaseFirstLetter(subCategory)}`);
}

// 获取交易类型图标（用于卡片布局）
function getTransactionTypeIcon(type: string) {
  const iconMap: Record<string, any> = {
    Income: TrendingUp,
    Expense: TrendingDown,
    Transfer: Repeat,
  };
  return iconMap[type] || TrendingUp;
}

// 获取交易类型名称（多语言）
function getTransactionTypeName(type: string) {
  const nameMap: Record<string, string> = {
    Income: t('financial.transaction.income'),
    Expense: t('financial.transaction.expense'),
    Transfer: t('financial.transaction.transfer'),
  };
  return nameMap[type] || t('financial.transaction.unknown');
}

// 获取金额样式类（用于卡片布局）
function getAmountClass(type: string) {
  const classMap: Record<string, string> = {
    Income: 'amount-income',
    Expense: 'amount-expense',
    Transfer: 'amount-transfer',
  };
  return classMap[type] || '';
}

// 检查交易是否有分摊
function hasSplit(_transaction: Transaction): boolean {
  // TODO: 根据实际数据结构判断
  // 暂时返回 false，等待后端 API 对接
  return false;
}

// 查看分摊详情
function viewSplitDetail(transaction: Transaction) {
  emit('viewSplit', transaction);
}
</script>

<template>
  <div class="transaction-wrapper" :class="[`layout-${layout}`]">
    <div v-if="loading" class="table-loading">
      <div class="spinner" />
      <span>加载中...</span>
    </div>

    <div v-else-if="transactions.length === 0" class="table-empty">
      <p>{{ emptyText }}</p>
    </div>

    <!-- Table 布局 -->
    <table v-else-if="layout === 'table'" class="transaction-table" :class="{ compact }">
      <thead>
        <tr>
          <th v-if="showColumn('date')">
            日期
          </th>
          <th v-if="showColumn('type')">
            类型
          </th>
          <th v-if="showColumn('category')">
            分类
          </th>
          <th v-if="showColumn('amount')">
            金额
          </th>
          <th v-if="showColumn('account')">
            账户
          </th>
          <th v-if="showColumn('description')">
            说明
          </th>
          <th class="split-column">
            分摊
          </th>
          <th v-if="showActions" class="actions-column">
            操作
          </th>
        </tr>
      </thead>
      <tbody>
        <tr
          v-for="transaction in transactions"
          :key="transaction.serialNum"
          @click="emit('view', transaction)"
        >
          <!-- 日期 -->
          <td v-if="showColumn('date')" class="date-cell">
            {{ formatDate(transaction.date) }}
          </td>

          <!-- 类型 -->
          <td v-if="showColumn('type')">
            <span class="type-badge" :class="getTransactionTypeClass(transaction.transactionType)">
              {{ getTransactionTypeText(transaction.transactionType) }}
            </span>
          </td>

          <!-- 分类 -->
          <td v-if="showColumn('category')" class="category-cell">
            <div class="category-content">
              <span class="category-main">{{ getCategoryName(transaction.category) }}</span>
              <span v-if="transaction.subCategory" class="category-sub">
                {{ getSubCategoryName(transaction.subCategory) }}
              </span>
            </div>
          </td>

          <!-- 金额 -->
          <td
            v-if="showColumn('amount')"
            class="amount-cell"
            :class="transaction.transactionType === 'Expense' ? 'negative' : 'positive'"
          >
            {{ transaction.transactionType === 'Expense' ? '-' : '' }}
            {{ formatCurrency(transaction.amount) }}
          </td>

          <!-- 账户 -->
          <td v-if="showColumn('account')" class="account-cell">
            {{ transaction.account?.name || '—' }}
          </td>

          <!-- 说明 -->
          <td v-if="showColumn('description')" class="description-cell">
            {{ transaction.description || '—' }}
          </td>

          <!-- 分摊标识 -->
          <td class="split-cell">
            <button
              v-if="hasSplit(transaction)"
              class="split-badge"
              @click.stop="viewSplitDetail(transaction)"
            >
              <LucideUsers class="split-icon" />
              <span>分摊</span>
            </button>
            <span v-else class="no-split">—</span>
          </td>

          <!-- 操作按钮 -->
          <td v-if="showActions" class="actions-cell">
            <div class="action-buttons">
              <button
                class="action-btn action-btn-edit"
                @click.stop="emit('edit', transaction)"
              >
                编辑
              </button>
              <button
                class="action-btn action-btn-delete"
                @click.stop="emit('delete', transaction)"
              >
                删除
              </button>
            </div>
          </td>
        </tr>
      </tbody>
    </table>

    <!-- Card 布局 -->
    <div v-else class="transaction-cards">
      <div
        v-for="transaction in transactions"
        :key="transaction.serialNum"
        class="transaction-card"
        @click="emit('view', transaction)"
      >
        <!-- 类型列 -->
        <div class="card-row">
          <span class="card-label">类型</span>
          <div class="card-type-content">
            <component :is="getTransactionTypeIcon(transaction.transactionType)" class="type-icon" />
            <span class="type-name">{{ getTransactionTypeName(transaction.transactionType) }}</span>
          </div>
        </div>

        <!-- 金额列 -->
        <div class="card-row">
          <span class="card-label">金额</span>
          <div class="card-amount" :class="getAmountClass(transaction.transactionType)">
            {{ transaction.transactionType === TransactionTypeSchema.enum.Expense ? '-' : '+' }}
            {{ formatCurrency(transaction.amount) }}
          </div>
        </div>

        <!-- 账户列 -->
        <div class="card-row">
          <span class="card-label">账户</span>
          <div class="card-content">
            <div class="card-account-name">
              {{ transaction.account.name }}
            </div>
            <div v-if="transaction.description" class="card-description">
              {{ transaction.description }}
            </div>
          </div>
        </div>

        <!-- 分类列 -->
        <div class="card-row">
          <span class="card-label">分类</span>
          <div class="card-content">
            <span class="card-category-main">
              {{ getCategoryName(transaction.category) }}
            </span>
            <div v-if="transaction.subCategory" class="card-category-sub">
              {{ getSubCategoryName(transaction.subCategory) }}
            </div>
          </div>
        </div>

        <!-- 时间列 -->
        <div class="card-row">
          <span class="card-label">时间</span>
          <div class="card-content">
            <div class="card-date">
              {{ DateUtils.formatForDisplay(transaction.date) }}
            </div>
          </div>
        </div>

        <!-- 操作列 -->
        <div v-if="showActions" class="card-row">
          <span class="card-label">操作</span>
          <div class="card-actions">
            <button
              class="card-action-btn"
              :title="t('common.actions.view')"
              @click.stop="emit('view', transaction)"
            >
              <LucideEye class="action-icon" />
            </button>
            <button
              class="card-action-btn"
              :title="t('common.actions.edit')"
              :disabled="disabledEditTransactions.has(transaction.serialNum)"
              :class="{
                'disabled-btn': disabledEditTransactions.has(transaction.serialNum),
              }"
              @click.stop="emit('edit', transaction)"
            >
              <LucidePencil class="action-icon" />
            </button>
            <button
              class="card-action-btn"
              :title="t('common.actions.delete')"
              :disabled="disabledDeleteTransactions.has(transaction.serialNum)"
              :class="{
                'disabled-btn': disabledDeleteTransactions.has(transaction.serialNum),
              }"
              @click.stop="emit('delete', transaction)"
            >
              <LucideTrash2 class="action-icon" />
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
/* 通用容器 */
.transaction-wrapper {
  margin-top: 16px;
}

/* Table 布局容器 */
.transaction-wrapper.layout-table {
  overflow-x: auto;
  border-radius: 12px;
  border: 1px solid var(--color-base-300);
  background: var(--color-base-50);
}

/* 加载状态 */
.table-loading {
  padding: 48px;
  text-align: center;
  color: var(--color-neutral);
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 12px;
}

.spinner {
  width: 32px;
  height: 32px;
  border: 3px solid var(--color-base-300);
  border-top-color: var(--color-primary);
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
}

/* 空状态 */
.table-empty {
  padding: 48px;
  text-align: center;
  color: var(--color-gray-400);
}

.table-empty p {
  margin: 0;
  font-size: 14px;
}

/* 表格基础样式 */
.transaction-table {
  width: 100%;
  border-collapse: separate;
  border-spacing: 0;
}

/* 表头 */
.transaction-table thead {
  background: linear-gradient(to bottom, var(--color-base-100), var(--color-base-200));
  border-bottom: 2px solid var(--color-base-300);
}

.transaction-table th {
  padding: 14px 16px;
  text-align: left;
  font-size: 11px;
  font-weight: 700;
  color: var(--color-neutral);
  text-transform: uppercase;
  letter-spacing: 0.5px;
  white-space: nowrap;
  border-bottom: 2px solid var(--color-base-300);
}

.transaction-table th.actions-column {
  text-align: center;
}

/* 表格行 */
.transaction-table tbody tr {
  transition: all 0.2s ease;
  border-bottom: 1px solid var(--color-base-200);
  cursor: pointer;
}

.transaction-table tbody tr:hover {
  background: var(--color-base-200);
  box-shadow: inset 0 0 0 1px var(--color-primary-soft);
}

.transaction-table tbody tr:last-child {
  border-bottom: none;
}

.transaction-table tbody tr:last-child td {
  border-bottom: none;
}

/* 表格单元格 */
.transaction-table td {
  padding: 14px 16px;
  font-size: 13px;
  color: var(--color-base-content);
  border-bottom: 1px solid var(--color-base-200);
}

/* 日期列 */
.date-cell {
  color: var(--color-neutral);
  font-weight: 500;
  font-variant-numeric: tabular-nums;
}

/* 类型徽章 */
.type-badge {
  display: inline-block;
  padding: 4px 10px;
  border-radius: 6px;
  font-size: 11px;
  font-weight: 600;
  letter-spacing: 0.3px;
  white-space: nowrap;
}

.type-badge.type-expense {
  background: oklch(from var(--color-error) l c h / 0.1);
  color: var(--color-error);
  border: 1px solid oklch(from var(--color-error) l c h / 0.2);
}

.type-badge.type-income {
  background: oklch(from var(--color-success) l c h / 0.1);
  color: var(--color-success);
  border: 1px solid oklch(from var(--color-success) l c h / 0.2);
}

.type-badge.type-transfer {
  background: oklch(from var(--color-info) l c h / 0.1);
  color: var(--color-info);
  border: 1px solid oklch(from var(--color-info) l c h / 0.2);
}

/* 分类列 */
.category-cell {
  min-width: 100px;
}

.category-content {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.category-main {
  font-weight: 500;
  color: var(--color-base-content);
}

.category-sub {
  font-size: 11px;
  color: var(--color-gray-500);
}

/* 金额列 */
.amount-cell {
  font-weight: 600;
  font-variant-numeric: tabular-nums;
}

.amount-cell.positive {
  color: var(--color-success);
}

.amount-cell.negative {
  color: var(--color-error);
}

/* 账户列 */
.account-cell {
  font-weight: 500;
}

/* 说明列 */
.description-cell {
  color: var(--color-gray-500);
  max-width: 200px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

/* 操作列 */
.actions-cell {
  text-align: center;
}

.action-buttons {
  display: flex;
  gap: 8px;
  justify-content: center;
  align-items: center;
}

.action-btn {
  padding: 4px 12px;
  border-radius: 6px;
  font-size: 12px;
  font-weight: 500;
  border: 1px solid;
  cursor: pointer;
  transition: all 0.2s ease;
}

.action-btn-edit {
  background: var(--color-base-100);
  border-color: var(--color-primary-soft);
  color: var(--color-primary);
}

.action-btn-edit:hover {
  background: var(--color-primary);
  color: var(--color-primary-content);
}

.action-btn-delete {
  background: var(--color-base-100);
  border-color: var(--color-error);
  color: var(--color-error);
}

.action-btn-delete:hover {
  background: var(--color-error);
  color: var(--color-error-content);
}

/* 紧凑模式 */
.transaction-table.compact th,
.transaction-table.compact td {
  padding: 10px 12px;
  font-size: 12px;
}

.transaction-table.compact .type-badge {
  padding: 3px 8px;
  font-size: 10px;
}

/* 移动端优化 */
@media (max-width: 768px) {
  .transaction-table th,
  .transaction-table td {
    padding: 10px 8px;
    font-size: 12px;
  }

  .transaction-table th {
    font-size: 10px;
  }

  .type-badge {
    padding: 3px 8px;
    font-size: 10px;
  }

  .description-cell {
    max-width: 120px;
  }

  .action-buttons {
    flex-direction: column;
    gap: 4px;
  }

  .action-btn {
    width: 100%;
  }
}

/* ==================== Card 布局样式 ==================== */
.transaction-cards {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.transaction-card {
  border: 1px solid var(--color-base-300);
  background: var(--color-base-50);
  border-radius: 8px;
  transition: all 0.2s ease;
  cursor: pointer;
  overflow: hidden;
}

.transaction-card:hover {
  background-color: var(--color-base-200);
  border-color: var(--color-primary-soft);
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.05);
}

.card-row {
  font-size: 0.875rem;
  padding: 0.5rem;
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
}

.card-label {
  display: inline-block;
  color: var(--color-gray-600);
  font-weight: 600;
  min-width: 80px;
  flex-shrink: 0;
}

.card-content {
  flex: 1;
  text-align: right;
}

/* 类型内容 */
.card-type-content {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 0.5rem;
}

.type-icon {
  width: 1rem;
  height: 1rem;
}

.type-name {
  font-weight: 500;
}

/* 金额样式 */
.card-amount {
  font-weight: 600;
  font-size: 1rem;
  text-align: right;
}

.card-amount.amount-income {
  color: var(--color-success);
}

.card-amount.amount-expense {
  color: var(--color-error);
}

.card-amount.amount-transfer {
  color: var(--color-info);
}

/* 账户名称 */
.card-account-name {
  font-weight: 500;
  color: var(--color-base-content);
}

.card-description {
  margin-top: 0.25rem;
  color: var(--color-gray-500);
  font-size: 0.75rem;
}

/* 分类 */
.card-category-main {
  color: var(--color-base-content);
  font-weight: 500;
}

.card-category-sub {
  font-size: 0.75rem;
  color: var(--color-gray-600);
  margin-top: 0.25rem;
}

/* 日期 */
.card-date {
  color: var(--color-base-content);
}

/* 操作按钮 */
.card-actions {
  display: flex;
  gap: 0.5rem;
  justify-content: flex-end;
}

.card-action-btn {
  padding: 0.375rem;
  border: 1px solid var(--color-base-300);
  background: var(--color-base-100);
  border-radius: 6px;
  cursor: pointer;
  transition: all 0.2s;
  display: flex;
  align-items: center;
  justify-content: center;
}

.card-action-btn:hover:not(.disabled-btn) {
  background: var(--color-primary);
  border-color: var(--color-primary);
  color: white;
}

.card-action-btn.disabled-btn {
  opacity: 0.5;
  cursor: not-allowed;
}

.action-icon {
  width: 1rem;
  height: 1rem;
}

/* 桌面端卡片布局 */
@media (min-width: 769px) {
  .transaction-card {
    display: grid;
    grid-template-columns: 120px 140px 180px 140px 140px 120px;
  }

  .card-row {
    align-items: center;
    justify-content: flex-end;
  }

  .card-label {
    display: none;
  }

  .card-content {
    text-align: right;
  }
}

@keyframes spin {
  from {
    transform: rotate(0deg);
  }
  to {
    transform: rotate(360deg);
  }
}
</style>
