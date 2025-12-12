<script setup lang="ts">
  import FilterBar from '@/components/common/FilterBar.vue';
  import { EmptyState, LoadingState, Pagination } from '@/components/ui';
  import type { PageQuery, SortOptions } from '@/schema/common';
  import { SortDirection, TransactionTypeSchema } from '@/schema/common';
  import type { Account, Transaction } from '@/schema/money';
  import type { TransactionFilters } from '@/services/money/transactions';
  import { useTransactionStore } from '@/stores/money';
  import { Lg } from '@/utils/debugLog';
  import { lowercaseFirstLetter } from '@/utils/string';
  import { isInstallmentTransaction } from '@/utils/transaction';
  import TransactionTable from './TransactionTable.vue';

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
        .filter(
          t =>
            t.transactionType === TransactionTypeSchema.enum.Expense && t.category === 'Transfer',
        )
        .map(t => t.serialNum),
    );
  });

  // 禁用分期交易的编辑和删除按钮
  const disabledInstallmentTransactions = computed(() => {
    return new Set(
      transactions.value.filter(t => isInstallmentTransaction(t)).map(t => t.serialNum),
    );
  });

  // 禁用编辑按钮的交易（只包含转账交易）
  const disabledEditTransactions = computed(() => {
    return new Set([...disabledTransferTransactions.value]);
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
      category: '',
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
    const categories = transactions.value.map(transaction => transaction.category).filter(Boolean);
    return [...new Set(categories)].map(category => ({
      type: category,
      option: t(`common.categories.${lowercaseFirstLetter(category)}`),
    }));
  });

  // 辅助函数：构建过滤器对象
  function buildTransactionFilters(): TransactionFilters {
    return {
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
    };
  }

  // 辅助函数：构建排序选项
  function buildSortOptions() {
    return {
      customOrderBy: sortOptions.value.customOrderBy || undefined,
      sortBy: sortOptions.value.sortBy || undefined,
      desc: sortOptions.value.desc,
      sortDir: sortOptions.value.sortDir || SortDirection.Desc,
    };
  }

  // 加载交易数据
  async function loadTransactions() {
    loading.value = true;
    try {
      const params: PageQuery<TransactionFilters> = {
        currentPage: pagination.value.currentPage,
        pageSize: pagination.value.pageSize,
        sortOptions: buildSortOptions(),
        filter: buildTransactionFilters(),
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
  <div class="space-y-4 w-full">
    <!-- 过滤器区域 -->
    <FilterBar
      :show-more-filters="showMoreFilters"
      @toggle-filters="toggleFilters"
      @reset="resetFilters"
    >
      <template #primary>
        <!-- 交易类型过滤 -->
        <select
          v-model="filters.transactionType"
          class="px-3 py-1.5 text-sm rounded-lg border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
        >
          <option value="">{{ t('common.actions.all') }}</option>
          <option value="Income">{{ t('financial.transaction.income') }}</option>
          <option value="Expense">{{ t('financial.transaction.expense') }}</option>
          <option value="Transfer">{{ t('financial.transaction.transfer') }}</option>
        </select>
      </template>

      <template #secondary>
        <select
          v-model="filters.accountSerialNum"
          class="px-3 py-1.5 text-sm rounded-lg border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
        >
          <option value="">
            {{ t('common.actions.all') }}
            {{ t('financial.account.account') }}
          </option>
          <option
            v-for="account in props.accounts"
            :key="account.serialNum"
            :value="account.serialNum"
          >
            {{ account.name }}
          </option>
        </select>

        <select
          v-model="filters.category"
          class="px-3 py-1.5 text-sm rounded-lg border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
        >
          <option value="">{{ t('categories.allCategory') }}</option>
          <option v-for="category in uniqueCategories" :key="category.type" :value="category.type">
            {{ category.option }}
          </option>
        </select>

        <input
          v-model="filters.dateStart"
          type="date"
          class="px-3 py-1.5 text-sm rounded-lg border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
        />

        <input
          v-model="filters.dateEnd"
          type="date"
          class="px-3 py-1.5 text-sm rounded-lg border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
        />
      </template>
    </FilterBar>

    <!-- 加载状态 -->
    <LoadingState v-if="loading" :message="t('common.loading')" />

    <!-- 空状态 -->
    <EmptyState v-else-if="transactions.length === 0" icon="📝" message="暂无交易记录" />

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
    <div
      v-if="pagination.totalItems > pagination.pageSize"
      class="mt-4 flex justify-center md:mb-0 mb-16 pb-4"
    >
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
