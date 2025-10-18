<script setup lang="ts">
import {
  Repeat,
  TrendingDown,
  TrendingUp,
} from 'lucide-vue-next';
import SimplePagination from '@/components/common/SimplePagination.vue';
import { SortDirection, TransactionTypeSchema } from '@/schema/common';
import { lowercaseFirstLetter } from '@/utils/common';
import { DateUtils } from '@/utils/date';
import { Lg } from '@/utils/debugLog';
import { formatCurrency } from '../utils/money';
import type { PageQuery, SortOptions, TransactionType } from '@/schema/common';
import type { Account, Transaction } from '@/schema/money';
import type { TransactionFilters } from '@/services/money/transactions';

interface Props {
  accounts: Account[];
}

const props = defineProps<Props>();

const emit = defineEmits<{
  edit: [transaction: Transaction];
  delete: [transaction: Transaction];
  viewDetails: [transaction: Transaction];
}>();

const { t } = useI18n();
const moneyStore = useMoneyStore();
const mediaQueries = useMediaQueriesStore();
// 数据状态
const loading = ref(false);
const showMoreFilters = ref(!mediaQueries.isMobile);

// 切换过滤器显示状态
function toggleFilters() {
  showMoreFilters.value = !showMoreFilters.value;
}
const transactions = computed<Transaction[]>(() => moneyStore.transactions);

// 检测是否为分期交易（基于notes字段的正则表达式）
function isInstallmentTransaction(transaction: Transaction): boolean {
  // 检查基本条件：交易类型为支出，且有relatedTransactionSerialNum
  if (transaction.transactionType !== 'Expense' || !transaction.relatedTransactionSerialNum) {
    return false;
  }
  // 检查notes字段是否包含分期计划模式
  if (!transaction.notes) {
    return false;
  }
  // 正则表达式匹配：分期计划:序列号,第X/Y期
  const installmentPattern = /分期计划:\s*\d+,\s*第\d+\/\d+期/;
  return installmentPattern.test(transaction.notes);
}

// 禁用转账交易的编辑和删除按钮
const disabledTransferTransactions = computed(() => {
  return new Set(
    transactions.value
      .filter(t => t.transactionType === TransactionTypeSchema.enum.Expense && t.category === 'Transfer')
      .map(t => t.serialNum),
  );
});

// 禁用分期交易的编辑和删除按钮
const disabledInstallmentTransactions = computed(() => {
  return new Set(
    transactions.value
      .filter(t => isInstallmentTransaction(t))
      .map(t => t.serialNum),
  );
});

// 禁用编辑按钮的交易（只包含转账交易）
const disabledEditTransactions = computed(() => {
  return new Set([
    ...disabledTransferTransactions.value,
  ]);
});

// 禁用删除按钮的交易（包含转账交易和分期交易）
const disabledDeleteTransactions = computed(() => {
  return new Set([
    ...disabledTransferTransactions.value,
    ...disabledInstallmentTransactions.value,
  ]);
});

// 分页状态
const pagination = ref({
  currentPage: 1,
  totalPages: 1,
  totalItems: 0,
  pageSize: 20,
});

// 过滤器状态
const filters = ref<TransactionFilters>({
  transactionType: '',
  transactionStatus: '',
  dateStart: undefined,
  dateEnd: undefined,
  amountMin: undefined,
  amountMax: undefined,
  currency: undefined,
  accountSerialNum: '',
  category: '',
  subCategory: undefined,
  paymentMethod: undefined,
  actualPayerAccount: undefined,
  isDeleted: false,
});

// 排序选项状态
const sortOptions = ref<SortOptions>({
  customOrderBy: undefined,
  sortBy: undefined,
  sortDir: SortDirection.Desc,
  desc: true,
});

// 重置过滤器
function resetFilters() {
  filters.value = {
    transactionType: '',
    transactionStatus: '',
    dateStart: undefined,
    dateEnd: undefined,
    amountMin: undefined,
    amountMax: undefined,
    currency: undefined,
    accountSerialNum: '',
    category: undefined,
    subCategory: undefined,
    paymentMethod: undefined,
    actualPayerAccount: undefined,
    isDeleted: false,
  };
  pagination.value.currentPage = 1;
  sortOptions.value = {
    customOrderBy: undefined,
    sortBy: undefined,
    sortDir: undefined,
    desc: true,
  };
  loadTransactions();
}

// 获取唯一分类
const uniqueCategories = computed(() => {
  const categories = transactions.value.map(
    transaction => transaction.category,
  ).filter(Boolean);
  return [...new Set(categories)].map(category => ({
    type: category,
    option: t(`common.categories.${lowercaseFirstLetter(category)}`),
  }));
});

// 加载交易数据
async function loadTransactions() {
  loading.value = true;
  try {
    const params: PageQuery<TransactionFilters> = {
      currentPage: pagination.value.currentPage,
      pageSize: pagination.value.pageSize,
      sortOptions: {
        customOrderBy: sortOptions.value.customOrderBy || undefined,
        sortBy: sortOptions.value.sortBy || undefined,
        desc: sortOptions.value.desc,
        sortDir: sortOptions.value.sortDir || SortDirection.Desc,
      },
      filter: {
        transactionType: filters.value.transactionType || undefined,
        transactionStatus: filters.value.transactionStatus || undefined,
        dateStart: filters.value.dateStart || undefined,
        dateEnd: filters.value.dateEnd || undefined,
        amountMin: filters.value.amountMin || undefined,
        amountMax: filters.value.amountMax || undefined,
        currency: filters.value.currency || undefined,
        accountSerialNum: filters.value.accountSerialNum || undefined,
        category: filters.value.category || undefined,
        subCategory: filters.value.subCategory || undefined,
        paymentMethod: filters.value.paymentMethod || undefined,
        actualPayerAccount: filters.value.actualPayerAccount || undefined,
        isDeleted: filters.value.isDeleted ?? false,
      },
    };
    const result = await moneyStore.getPagedTransactions(params);

    pagination.value.totalItems = result.totalCount;
    pagination.value.totalPages = result.totalPages;
  } catch (error) {
    pagination.value.totalItems = 0;
    pagination.value.totalPages = 0;
    Lg.e('Transaction', error);
  } finally {
    loading.value = false;
  }
}

// 处理页码变化
function handlePageChange(page: number) {
  pagination.value.currentPage = page;
  loadTransactions();
}

// 处理页面大小变化
function handlePageSizeChange(pageSize: number) {
  pagination.value.pageSize = pageSize;
  pagination.value.currentPage = 1; // 重置到第一页
  loadTransactions();
}

// 监听过滤器变化，重置到第一页并重新加载数据
watch(
  filters,
  () => {
    pagination.value.currentPage = 1;
    loadTransactions();
  },
  { deep: true },
);

// 原有的方法
function getTransactionTypeIcon(type: TransactionType) {
  const icons = {
    Income: TrendingUp,
    Expense: TrendingDown,
    Transfer: Repeat,
  };
  return icons[type] || 'icon-list';
}

function getTransactionTypeName(type: TransactionType) {
  const names = {
    Income: t('financial.transaction.income'),
    Expense: t('financial.transaction.expense'),
    Transfer: t('financial.transaction.transfer'),
  };
  return names[type] || t('financial.transaction.unknown');
}

// 组件挂载时加载数据
onMounted(() => {
  loadTransactions();
});

// 暴露刷新方法给父组件
defineExpose({
  refresh: loadTransactions,
});
</script>

<template>
  <div class="money-tab-25">
    <!-- 过滤器区域 -->
    <div class="screening-filtering">
      <div class="filter-flex-wrap">
        <select
          v-model="filters.transactionType"
          class="screening-filtering-select"
        >
          <option value="">
            {{ t('common.actions.all') }}
          </option>
          <option value="Income">
            {{ t('financial.transaction.income') }}
          </option>
          <option value="Expense">
            {{ t('financial.transaction.expense') }}
          </option>
          <option value="Transfer">
            {{ t('financial.transaction.transfer') }}
          </option>
        </select>
      </div>

      <template v-if="showMoreFilters">
        <div class="filter-flex-wrap">
          <select
            v-model="filters.accountSerialNum"
            class="screening-filtering-select"
          >
            <option value="">
              {{ t('common.actions.all') }}{{ t('financial.account.account') }}
            </option>
            <option v-for="account in props.accounts" :key="account.serialNum" :value="account.serialNum">
              {{ account.name }}
            </option>
          </select>
        </div>

        <div class="filter-flex-wrap">
          <select
            v-model="filters.category"
            class="screening-filtering-select"
          >
            <option value="">
              {{ t('categories.allCategory') }}
            </option>
            <option v-for="category in uniqueCategories" :key="category.type" :value="category.type">
              {{ category.option }}
            </option>
          </select>
        </div>

        <div class="filter-flex-wrap">
          <input
            v-model="filters.dateStart" type="date"
            class="screening-filtering-select"
          >
        </div>

        <div class="filter-flex-wrap">
          <input
            v-model="filters.dateEnd" type="date"
            class="screening-filtering-select"
          >
        </div>
      </template>

      <div class="filter-button-group">
        <button
          class="screening-filtering-select"
          @click="toggleFilters"
        >
          <LucideMoreHorizontal class="wh-4 mr-1" />
        </button>
        <button
          class="screening-filtering-select"
          @click="resetFilters"
        >
          <LucideRotateCcw class="wh-4 mr-1" />
        </button>
      </div>
    </div>

    <!-- 加载状态 -->
    <div v-if="loading" class="loading-state">
      {{ t('common.loading') }}
    </div>

    <!-- 空状态 -->
    <div v-else-if="transactions.length === 0" class="empty-state">
      <div class="text-6xl mb-4 opacity-50">
        <i class="icon-list" />
      </div>
      <div class="text-base">
        暂无交易记录
      </div>
    </div>

    <!-- 交易列表 -->
    <div v-else class="transaction-table-title">
      <!-- 表头 - 桌面版 -->
      <div
        class="transaction-table-title-desktop"
      >
        <div class="table-title-option">
          {{ t('common.misc.types') }}
        </div>
        <div class="table-title-option">
          {{ t('financial.money') }}
        </div>
        <div class="table-title-option">
          {{ t('financial.account.account') }}
        </div>
        <div class="table-title-option">
          {{ t('categories.category') }}
        </div>
        <div class="table-title-option">
          {{ t('date.date') }}
        </div>
        <div class="table-title-option">
          {{ t('common.misc.options') }}
        </div>
      </div>

      <!-- 交易行 -->
      <div
        v-for="transaction in transactions" :key="transaction.serialNum"
        class="transaction-rows"
      >
        <!-- 类型列 -->
        <div class="transaction-rows-item">
          <span class="transaction-rows-item-span">{{ t('categories.category') }}</span>
          <div class="transaction-type-content">
            <component :is="getTransactionTypeIcon(transaction.transactionType)" class="wh-4" />
            <span class="font-medium">{{ getTransactionTypeName(transaction.transactionType) }}</span>
          </div>
        </div>

        <!-- 金额列 -->
        <div class="transaction-rows-item">
          <span class="transaction-rows-item-span">{{ t('financial.money') }}</span>
          <div
            class="transaction-amount" :class="[
              transaction.transactionType === TransactionTypeSchema.enum.Income ? 'amount-income'
              : transaction.transactionType === TransactionTypeSchema.enum.Expense ? 'amount-expense'
                : 'amount-transfer',
            ]"
          >
            {{ transaction.transactionType === TransactionTypeSchema.enum.Expense ? '-' : '+' }}{{
              formatCurrency(transaction.amount) }}
          </div>
        </div>

        <!-- 账户列 -->
        <div class="transaction-rows-item">
          <span class="transaction-rows-item-span">{{ t('financial.account.account') }}</span>
          <div class="transaction-rows-item-span-md">
            <div class="transaction-account-name">
              {{ transaction.account.name }}
            </div>
            <div v-if="transaction.description" class="transaction-description">
              {{ transaction.description }}
            </div>
          </div>
        </div>

        <!-- 分类列 -->
        <div class="transaction-rows-item">
          <span class="transaction-rows-item-span">{{ t('categories.category') }}</span>
          <div class="transaction-rows-item-span-md">
            <span class="transaction-category-main">{{ t(`common.categories.${lowercaseFirstLetter(transaction.category)}`) }}</span>
            <div v-if="transaction.subCategory" class="transaction-category-sub">
              {{ t(`common.subCategories.${lowercaseFirstLetter(transaction.subCategory)}`) }}
            </div>
          </div>
        </div>

        <!-- 时间列 -->
        <div class="transaction-rows-item">
          <span class="transaction-rows-item-span">{{ t('date.date') }}</span>
          <div class="transaction-rows-item-span-md">
            <div class="transaction-date">
              {{ DateUtils.formatForDisplay(transaction.date) }}
            </div>
          </div>
        </div>

        <!-- 操作列 -->
        <div class="transaction-rows-item">
          <span class="transaction-rows-item-span">{{ t('common.misc.options') }}</span>
          <div class="transaction-action-buttons">
            <button
              class="money-option-btn"
              :title="t('common.actions.view')" @click="emit('viewDetails', transaction)"
            >
              <LucideEye class="wh-4" />
            </button>
            <button
              class="money-option-btn" :title="t('common.actions.edit')"
              :disabled="disabledEditTransactions.has(transaction.serialNum)"
              :class="{
                'disabled-btn': disabledEditTransactions.has(transaction.serialNum),
              }"
              @click="emit('edit', transaction)"
            >
              <LucideEdit class="wh-4" />
            </button>
            <button
              class="money-option-btn"
              :title="t('common.actions.delete')"
              :disabled="disabledDeleteTransactions.has(transaction.serialNum)"
              @click="emit('delete', transaction)"
            >
              <LucideTrash class="wh-4" />
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- 分页组件 - 移动端优化版 -->
    <div v-if="pagination.totalItems > pagination.pageSize" class="pagination-container">
      <!-- 桌面端完整分页 -->
      <SimplePagination
        :current-page="pagination.currentPage"
        :total-pages="pagination.totalPages"
        :total-items="pagination.totalItems"
        :page-size="pagination.pageSize"
        :show-page-size="true"
        :page-size-options="[10, 20, 50, 100]"
        :compact="false"
        :responsive="false"
        :show-total="false"
        :show-jump="true"
        :show-first-last="true"
        @page-change="handlePageChange"
        @page-size-change="handlePageSizeChange"
      />
    </div>
  </div>
</template>

<style scoped lang="postcss">
.money-option-btn {
  padding: 0.375rem;
  border: 1px solid #d1d5db;
  border-radius: 0.375rem;
  color: #4b5563;
  background-color: transparent;
  transition: background-color 0.2s;
}

.money-option-btn:hover {
  color: var(--color-neutral);
  border-color: var(--color-neutral);
}

.transaction-table-title {
  margin-bottom: 1.5rem;
  border: 1px solid #e5e7eb;
  border-radius: 0.5rem;
  overflow: hidden;
}

.transaction-table-title-desktop {
  color: #1f2937;
  font-weight: 600;
  display: none;
  background-color: var(--color-base-100);
  border: 1px solid var(--color-base-300);
}

.transaction-rows {
  border: 1px solid var(--color-base-300);
margin-bottom: 0.1rem;
  display: grid;
  grid-template-columns: 1fr;
  transition: background-color 0.2s;
}

.transaction-rows:hover {
  background-color: var(--color-base-300);
}

.transaction-rows-item {
  font-size: 0.875rem;
  padding: 0.5rem;
  display: flex;
  justify-content: space-between;
}

.transaction-rows-item-span {
  color: #4b5563;
  font-weight: 600;
}

.table-title-option {
  font-size: 0.875rem;
  padding: 1rem;
  display: grid;
  place-items: end;
}

@media (min-width: 768px) {
  .transaction-table-title-desktop{
    display: grid;
    grid-template-columns: 120px 140px 180px 140px 140px 120px;
  }
  .transaction-rows {
    grid-template-columns: 120px 140px 180px 140px 140px 120px;
  }

  .transaction-rows-item {
    align-items: center;
    justify-content: flex-end;
  }
  .transaction-rows-item-span {
    display: none;
  }
  .transaction-rows-item-span-md {
    text-align: right;
  }
}

/* Transaction specific styles */
.filter-button-group {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.loading-state {
  color: #4b5563;
  height: 6.25rem;
  display: flex;
  justify-content: center;
  align-items: center;
}

.empty-state {
  color: #999;
  display: flex;
  flex-direction: column;
  height: 6.25rem;
  justify-content: center;
  align-items: center;
}

.transaction-type-content {
  display: flex;
  gap: 0.5rem;
  align-items: center;
}

.transaction-action-buttons {
  display: flex;
  gap: 0.25rem;
}

.transaction-amount {
  font-size: 1.125rem;
  font-weight: 600;
}

.amount-income {
  color: #16a34a;
}

.amount-expense {
  color: #ef4444;
}

.amount-transfer {
  color: #3b82f6;
}

.transaction-description {
  font-size: 0.75rem;
  color: #4b5563;
  margin-top: 0.25rem;
}

.transaction-category-main {
  color: #1f2937;
  font-weight: 500;
}

.transaction-category-sub {
  font-size: 0.75rem;
  color: #4b5563;
}

.transaction-date {
  font-size: 0.75rem;
  color: #4b5563;
}

.transaction-account-name {
  color: #1f2937;
  font-weight: 500;
}

.filter-button-group {
  display: flex;
  gap: 0.25rem;
}

.pagination-container {
  margin-top: 1rem;
  display: flex;
  justify-content: center;
}

.disabled-btn {
  color: #6b7280 !important;
  background-color: #e5e7eb !important;
  cursor: not-allowed !important;
  opacity: 0.6 !important;
}

.disabled-btn:hover {
  color: #6b7280 !important;
  background-color: #e5e7eb !important;
  transform: none !important;
  box-shadow: none !important;
}

.money-option-btn:disabled {
  color: #6b7280 !important;
  background-color: #e5e7eb !important;
  cursor: not-allowed !important;
  opacity: 0.6 !important;
}

.money-option-btn:disabled:hover {
  color: #6b7280 !important;
  background-color: #e5e7eb !important;
  transform: none !important;
  box-shadow: none !important;
}
</style>
