<script setup lang="ts">
import { Pagination } from '@/components/ui';
import { SortDirection, TransactionTypeSchema } from '@/schema/common';
import { useTransactionStore } from '@/stores/money';
import { lowercaseFirstLetter } from '@/utils/common';
import { Lg } from '@/utils/debugLog';
import { isInstallmentTransaction } from '@/utils/transaction';
import TransactionTable from './TransactionTable.vue';
import type { PageQuery, SortOptions } from '@/schema/common';
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
const transactionStore = useTransactionStore();
const mediaQueries = useMediaQueriesStore();
// 数据状态
const loading = ref(false);
const showMoreFilters = ref(!mediaQueries.isMobile);

// 切换过滤器显示状态
function toggleFilters() {
  showMoreFilters.value = !showMoreFilters.value;
}
const transactions = computed<Transaction[]>(() => transactionStore.transactionsPaged.rows);

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
  sortBy: 'updated_at',
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
    sortBy: 'updated_at',
    sortDir: SortDirection.Desc,
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
    await transactionStore.fetchTransactionsPaged(params);
    const result = transactionStore.transactionsPaged;

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
    <TransactionTable
      v-else
      :transactions="transactions"
      :loading="loading"
      :show-actions="true"
      layout="card"
      :disabled-edit-transactions="disabledEditTransactions"
      :disabled-delete-transactions="disabledDeleteTransactions"
      @edit="emit('edit', $event)"
      @delete="emit('delete', $event)"
      @view="emit('viewDetails', $event)"
    />

    <!-- 分页组件 - 移动端优化版 -->
    <div v-if="pagination.totalItems > pagination.pageSize" class="pagination-container">
      <!-- 桌面端完整分页 -->
      <Pagination
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
  padding: 0.5rem 0.75rem;
  border: 2px solid var(--color-base-300);
  border-radius: 0.5rem;
  color: var(--color-neutral);
  background-color: var(--color-base-100);
  transition: all 0.2s ease;
  font-weight: 500;
  cursor: pointer;
}

.money-option-btn:hover {
  color: var(--color-primary);
  border-color: var(--color-primary);
  background-color: var(--color-primary-soft);
  transform: translateY(-1px);
  box-shadow: var(--shadow-sm);
}

.money-option-btn:active {
  transform: translateY(0);
}

.empty-state {
  padding: 4rem 1rem;
  text-align: center;
  color: var(--color-neutral);
  background: linear-gradient(to bottom, var(--color-base-100), var(--color-base-200));
  border-radius: 1rem;
  border: 2px dashed var(--color-base-300);
  margin: 1rem 0;
}

.empty-state .text-6xl {
  font-size: 3rem;
  margin-bottom: 1rem;
  opacity: 0.3;
}

.empty-state .text-base {
  font-size: 1rem;
  font-weight: 500;
  color: var(--color-neutral);
}

.loading-state {
  padding: 4rem 1rem;
  text-align: center;
  color: var(--color-neutral);
  background: linear-gradient(to bottom, var(--color-base-100), var(--color-base-200));
  border-radius: 1rem;
  border: 2px solid var(--color-base-300);
  margin: 1rem 0;
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 1rem;
}

.loading-state::before {
  content: '';
  width: 3rem;
  height: 3rem;
  border: 3px solid var(--color-base-300);
  border-top-color: var(--color-primary);
  border-radius: 50%;
  animation: spin 0.8s linear infinite;
}

@keyframes spin {
  to { transform: rotate(360deg); }
}

.loading-wrapper {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
  align-items: center;
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

/* 移动端分页组件底部安全间距 */
@media (max-width: 768px) {
  .pagination-container {
    margin-bottom: 4rem; /* 为底部导航栏预留空间 */
    padding-bottom: 1rem; /* 额外的底部内边距 */
  }
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
