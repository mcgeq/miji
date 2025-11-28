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
import Badge from '@/components/ui/Badge.vue';
import Button from '@/components/ui/Button.vue';
import Spinner from '@/components/ui/Spinner.vue';
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
function getTransactionTypeBadgeVariant(type: string): 'danger' | 'success' | 'info' | 'default' {
  const variantMap: Record<string, 'danger' | 'success' | 'info' | 'default'> = {
    Expense: 'danger',
    Income: 'success',
    Transfer: 'info',
  };
  return variantMap[type] || 'default';
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
  <div class="mt-4" :class="layout === 'table' ? 'overflow-x-auto rounded-xl border-2 border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-800 shadow-sm' : ''">
    <div v-if="loading" class="flex flex-col items-center gap-3 p-12 text-gray-500 dark:text-gray-400">
      <Spinner size="md" />
      <span class="text-sm">加载中...</span>
    </div>

    <div v-else-if="transactions.length === 0" class="flex items-center justify-center p-16 text-center text-gray-500 dark:text-gray-400 bg-gradient-to-b from-white to-gray-50 dark:from-gray-800 dark:to-gray-900 rounded-xl mx-4">
      <p class="m-0 text-base font-medium">
        {{ emptyText }}
      </p>
    </div>

    <!-- Table 布局 -->
    <table v-else-if="layout === 'table'" class="w-full border-separate border-spacing-0">
      <thead class="bg-gradient-to-b from-white to-gray-50 dark:from-gray-800 dark:to-gray-700 border-b-2 border-gray-200 dark:border-gray-600">
        <tr>
          <th v-if="showColumn('date')" :class="compact ? 'px-3 py-2.5 text-[10px]' : 'px-4 py-3.5 text-[11px]'" class="text-left font-bold text-gray-500 dark:text-gray-400 uppercase tracking-wider whitespace-nowrap border-b-2 border-gray-200 dark:border-gray-600">
            日期
          </th>
          <th v-if="showColumn('type')" :class="compact ? 'px-3 py-2.5 text-[10px]' : 'px-4 py-3.5 text-[11px]'" class="text-left font-bold text-gray-500 dark:text-gray-400 uppercase tracking-wider whitespace-nowrap border-b-2 border-gray-200 dark:border-gray-600">
            类型
          </th>
          <th v-if="showColumn('category')" :class="compact ? 'px-3 py-2.5 text-[10px]' : 'px-4 py-3.5 text-[11px]'" class="text-left font-bold text-gray-500 dark:text-gray-400 uppercase tracking-wider whitespace-nowrap border-b-2 border-gray-200 dark:border-gray-600">
            分类
          </th>
          <th v-if="showColumn('amount')" :class="compact ? 'px-3 py-2.5 text-[10px]' : 'px-4 py-3.5 text-[11px]'" class="text-left font-bold text-gray-500 dark:text-gray-400 uppercase tracking-wider whitespace-nowrap border-b-2 border-gray-200 dark:border-gray-600">
            金额
          </th>
          <th v-if="showColumn('account')" :class="compact ? 'px-3 py-2.5 text-[10px]' : 'px-4 py-3.5 text-[11px]'" class="text-left font-bold text-gray-500 dark:text-gray-400 uppercase tracking-wider whitespace-nowrap border-b-2 border-gray-200 dark:border-gray-600">
            账户
          </th>
          <th v-if="showColumn('description')" :class="compact ? 'px-3 py-2.5 text-[10px]' : 'px-4 py-3.5 text-[11px]'" class="text-left font-bold text-gray-500 dark:text-gray-400 uppercase tracking-wider whitespace-nowrap border-b-2 border-gray-200 dark:border-gray-600">
            说明
          </th>
          <th :class="compact ? 'px-3 py-2.5 text-[10px]' : 'px-4 py-3.5 text-[11px]'" class="text-left font-bold text-gray-500 dark:text-gray-400 uppercase tracking-wider whitespace-nowrap border-b-2 border-gray-200 dark:border-gray-600">
            分摆
          </th>
          <th v-if="showActions" :class="compact ? 'px-3 py-2.5 text-[10px]' : 'px-4 py-3.5 text-[11px]'" class="text-center font-bold text-gray-500 dark:text-gray-400 uppercase tracking-wider whitespace-nowrap border-b-2 border-gray-200 dark:border-gray-600">
            操作
          </th>
        </tr>
      </thead>
      <tbody>
        <tr
          v-for="transaction in transactions"
          :key="transaction.serialNum"
          class="transition-all duration-200 border-b border-gray-100 dark:border-gray-700 cursor-pointer hover:bg-gray-50 dark:hover:bg-gray-700/50 last:border-b-0"
          @click="emit('view', transaction)"
        >
          <!-- 日期 -->
          <td v-if="showColumn('date')" :class="compact ? 'px-3 py-2.5 text-xs' : 'px-4 py-3.5 text-[13px]'" class="text-gray-500 dark:text-gray-400 font-medium tabular-nums border-b border-gray-100 dark:border-gray-700">
            {{ formatDate(transaction.date) }}
          </td>

          <!-- 类型 -->
          <td v-if="showColumn('type')" :class="compact ? 'px-3 py-2.5' : 'px-4 py-3.5'" class="border-b border-gray-100 dark:border-gray-700">
            <Badge :variant="getTransactionTypeBadgeVariant(transaction.transactionType)" size="sm">
              {{ getTransactionTypeText(transaction.transactionType) }}
            </Badge>
          </td>

          <!-- 分类 -->
          <td v-if="showColumn('category')" :class="compact ? 'px-3 py-2.5' : 'px-4 py-3.5'" class="min-w-[100px] border-b border-gray-100 dark:border-gray-700">
            <div class="flex flex-col gap-0.5">
              <span class="font-medium text-gray-900 dark:text-white text-[13px]">{{ getCategoryName(transaction.category) }}</span>
              <span v-if="transaction.subCategory" class="text-[11px] text-gray-500 dark:text-gray-400">
                {{ getSubCategoryName(transaction.subCategory) }}
              </span>
            </div>
          </td>

          <!-- 金额 -->
          <td
            v-if="showColumn('amount')"
            :class="[
              compact ? 'px-3 py-2.5 text-xs' : 'px-4 py-3.5 text-[13px]',
              transaction.transactionType === 'Expense' ? 'text-red-600 dark:text-red-400' : 'text-green-600 dark:text-green-400',
            ]"
            class="font-semibold tabular-nums border-b border-gray-100 dark:border-gray-700"
          >
            {{ transaction.transactionType === 'Expense' ? '-' : '' }}
            {{ formatCurrency(transaction.amount) }}
          </td>

          <!-- 账户 -->
          <td v-if="showColumn('account')" :class="compact ? 'px-3 py-2.5 text-xs' : 'px-4 py-3.5 text-[13px]'" class="font-medium text-gray-900 dark:text-white border-b border-gray-100 dark:border-gray-700">
            {{ transaction.account?.name || '—' }}
          </td>

          <!-- 说明 -->
          <td v-if="showColumn('description')" :class="compact ? 'px-3 py-2.5 text-xs' : 'px-4 py-3.5 text-[13px]'" class="text-gray-500 dark:text-gray-400 max-w-[200px] md:max-w-[120px] overflow-hidden text-ellipsis whitespace-nowrap border-b border-gray-100 dark:border-gray-700">
            {{ transaction.description || '—' }}
          </td>

          <!-- 分摆标识 -->
          <td :class="compact ? 'px-3 py-2.5' : 'px-4 py-3.5'" class="border-b border-gray-100 dark:border-gray-700">
            <button
              v-if="hasSplit(transaction)"
              class="inline-flex items-center gap-1.5 px-2 py-1 bg-blue-50 dark:bg-blue-900/20 text-blue-600 dark:text-blue-400 border border-blue-200 dark:border-blue-800 rounded-md text-xs font-medium hover:bg-blue-100 dark:hover:bg-blue-900/30 transition-colors"
              @click.stop="viewSplitDetail(transaction)"
            >
              <LucideUsers class="w-3 h-3" />
              <span>分摆</span>
            </button>
            <span v-else class="text-gray-400 dark:text-gray-500">—</span>
          </td>

          <!-- 操作按钮 -->
          <td v-if="showActions" :class="compact ? 'px-3 py-2.5' : 'px-4 py-3.5'" class="text-center border-b border-gray-100 dark:border-gray-700">
            <div class="flex gap-2 justify-center items-center md:flex-col md:gap-1">
              <Button
                variant="secondary"
                size="xs"
                class="md:w-full"
                @click.stop="emit('edit', transaction)"
              >
                编辑
              </Button>
              <Button
                variant="danger"
                size="xs"
                class="md:w-full"
                @click.stop="emit('delete', transaction)"
              >
                删除
              </Button>
            </div>
          </td>
        </tr>
      </tbody>
    </table>

    <!-- Card 布局 -->
    <div v-else class="flex flex-col gap-3 py-2">
      <div
        v-for="transaction in transactions"
        :key="transaction.serialNum"
        class="border-2 border-gray-200 dark:border-gray-700 bg-gradient-to-b from-white to-gray-50 dark:from-gray-800 dark:to-gray-700 rounded-xl transition-all duration-300 cursor-pointer overflow-hidden shadow-sm relative hover:border-blue-500/60 dark:hover:border-blue-400/60 hover:shadow-lg hover:-translate-y-0.5 active:translate-y-0 before:absolute before:top-0 before:left-0 before:w-1 before:h-full before:bg-blue-500 before:opacity-0 hover:before:opacity-80 lg:grid lg:grid-cols-[120px_140px_180px_140px_140px_1fr] lg:items-center"
        @click="emit('view', transaction)"
      >
        <!-- 类型列 -->
        <div class="text-sm px-4 py-3 flex justify-between items-center border-b border-gray-200/50 dark:border-gray-600/50 transition-colors gap-4 lg:border-b-0 lg:py-3 lg:px-2 lg:justify-end hover:bg-gray-100/50 dark:hover:bg-gray-700/50 lg:hover:bg-transparent">
          <span class="inline-block text-gray-500 dark:text-gray-400 font-bold text-xs uppercase tracking-wider min-w-[80px] flex-shrink-0 opacity-80 lg:hidden">类型</span>
          <div class="flex items-center justify-end gap-2">
            <component :is="getTransactionTypeIcon(transaction.transactionType)" class="w-4 h-4" />
            <span class="font-medium">{{ getTransactionTypeName(transaction.transactionType) }}</span>
          </div>
        </div>

        <!-- 金额列 -->
        <div class="text-sm px-4 py-3 flex justify-between items-center border-b border-gray-200/50 dark:border-gray-600/50 transition-colors gap-4 lg:border-b-0 lg:py-3 lg:px-2 lg:justify-end hover:bg-gray-100/50 dark:hover:bg-gray-700/50 lg:hover:bg-transparent">
          <span class="inline-block text-gray-500 dark:text-gray-400 font-bold text-xs uppercase tracking-wider min-w-[80px] flex-shrink-0 opacity-80 lg:hidden">金额</span>
          <div
            class="font-bold text-lg text-right tabular-nums -tracking-tight" :class="[
              transaction.transactionType === 'Income' ? 'text-green-600 dark:text-green-400'
              : transaction.transactionType === 'Expense' ? 'text-red-600 dark:text-red-400'
                : 'text-blue-600 dark:text-blue-400',
            ]"
          >
            {{ transaction.transactionType === TransactionTypeSchema.enum.Expense ? '-' : '+' }}
            {{ formatCurrency(transaction.amount) }}
          </div>
        </div>

        <!-- 账户列 -->
        <div class="text-sm px-4 py-3 flex justify-between items-center border-b border-gray-200/50 dark:border-gray-600/50 transition-colors gap-4 lg:border-b-0 lg:py-3 lg:px-2 hover:bg-gray-100/50 dark:hover:bg-gray-700/50 lg:hover:bg-transparent">
          <span class="inline-block text-gray-500 dark:text-gray-400 font-bold text-xs uppercase tracking-wider min-w-[80px] flex-shrink-0 opacity-80 lg:hidden">账户</span>
          <div class="flex-1 text-right min-w-0 break-words lg:text-right">
            <div class="font-medium text-gray-900 dark:text-white">
              {{ transaction.account.name }}
            </div>
            <div v-if="transaction.description" class="mt-1 text-gray-500 dark:text-gray-400 text-xs">
              {{ transaction.description }}
            </div>
          </div>
        </div>

        <!-- 分类列 -->
        <div class="text-sm px-4 py-3 flex justify-between items-center border-b border-gray-200/50 dark:border-gray-600/50 transition-colors gap-4 lg:border-b-0 lg:py-3 lg:px-2 hover:bg-gray-100/50 dark:hover:bg-gray-700/50 lg:hover:bg-transparent">
          <span class="inline-block text-gray-500 dark:text-gray-400 font-bold text-xs uppercase tracking-wider min-w-[80px] flex-shrink-0 opacity-80 lg:hidden">分类</span>
          <div class="flex-1 text-right min-w-0 break-words lg:text-right">
            <span class="text-gray-900 dark:text-white font-medium">
              {{ getCategoryName(transaction.category) }}
            </span>
            <div v-if="transaction.subCategory" class="text-xs text-gray-600 dark:text-gray-400 mt-1">
              {{ getSubCategoryName(transaction.subCategory) }}
            </div>
          </div>
        </div>

        <!-- 时间列 -->
        <div class="text-sm px-4 py-3 flex justify-between items-center border-b border-gray-200/50 dark:border-gray-600/50 transition-colors gap-4 lg:border-b-0 lg:py-3 lg:px-2 hover:bg-gray-100/50 dark:hover:bg-gray-700/50 lg:hover:bg-transparent">
          <span class="inline-block text-gray-500 dark:text-gray-400 font-bold text-xs uppercase tracking-wider min-w-[80px] flex-shrink-0 opacity-80 lg:hidden">时间</span>
          <div class="flex-1 text-right min-w-0 break-words lg:text-right">
            <div class="text-gray-900 dark:text-white">
              {{ DateUtils.formatForDisplay(transaction.date) }}
            </div>
          </div>
        </div>

        <!-- 操作列 -->
        <div v-if="showActions" class="text-sm px-4 py-2 pb-3 flex justify-end items-center gap-2 flex-shrink-0 lg:py-3 lg:pr-4 lg:px-2">
          <button
            class="p-2 border-2 border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 rounded-lg cursor-pointer transition-all duration-200 flex items-center justify-center min-w-[2.5rem] min-h-[2.5rem] hover:bg-blue-500 hover:border-blue-500 hover:text-white dark:hover:bg-blue-600 dark:hover:border-blue-600 hover:-translate-y-0.5 hover:shadow-md active:translate-y-0 disabled:opacity-40 disabled:cursor-not-allowed disabled:bg-gray-200 dark:disabled:bg-gray-700"
            :title="t('common.actions.view')"
            @click.stop="emit('view', transaction)"
          >
            <LucideEye class="w-4 h-4" />
          </button>
          <button
            class="p-2 border-2 border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 rounded-lg cursor-pointer transition-all duration-200 flex items-center justify-center min-w-[2.5rem] min-h-[2.5rem] hover:bg-blue-500 hover:border-blue-500 hover:text-white dark:hover:bg-blue-600 dark:hover:border-blue-600 hover:-translate-y-0.5 hover:shadow-md active:translate-y-0 disabled:opacity-40 disabled:cursor-not-allowed disabled:bg-gray-200 dark:disabled:bg-gray-700"
            :title="t('common.actions.edit')"
            :disabled="disabledEditTransactions.has(transaction.serialNum)"
            @click.stop="emit('edit', transaction)"
          >
            <LucidePencil class="w-4 h-4" />
          </button>
          <button
            class="p-2 border-2 border-gray-200 dark:border-gray-600 bg-white dark:bg-gray-800 rounded-lg cursor-pointer transition-all duration-200 flex items-center justify-center min-w-[2.5rem] min-h-[2.5rem] hover:bg-blue-500 hover:border-blue-500 hover:text-white dark:hover:bg-blue-600 dark:hover:border-blue-600 hover:-translate-y-0.5 hover:shadow-md active:translate-y-0 disabled:opacity-40 disabled:cursor-not-allowed disabled:bg-gray-200 dark:disabled:bg-gray-700"
            :title="t('common.actions.delete')"
            :disabled="disabledDeleteTransactions.has(transaction.serialNum)"
            @click.stop="emit('delete', transaction)"
          >
            <LucideTrash2 class="w-4 h-4" />
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
