<script setup lang="ts">
  import { MoneyDb } from '@/services/money/money';
  import type {
    TransactionStatsRequest,
    TransactionStatsResponse,
  } from '@/services/money/transactions';
  import { DateUtils } from '@/utils/date';

  // 懒加载重型图表组件 (Task 27: 大于50KB的组件使用动态导入)
  const AdvancedTransactionCharts = defineAsyncComponent({
    loader: () => import('@/features/money/components/AdvancedTransactionCharts.vue'),
    loadingComponent: {
      template: '<div class="animate-pulse bg-gray-200 dark:bg-gray-700 rounded-lg h-64" />',
    },
    delay: 200,
  });
  const CategoryChartsSwitcher = defineAsyncComponent({
    loader: () => import('@/features/money/components/CategoryChartsSwitcher.vue'),
    loadingComponent: {
      template: '<div class="animate-pulse bg-gray-200 dark:bg-gray-700 rounded-lg h-48" />',
    },
    delay: 200,
  });
  const PaymentMethodChartsSwitcher = defineAsyncComponent({
    loader: () => import('@/features/money/components/PaymentMethodChartsSwitcher.vue'),
    loadingComponent: {
      template: '<div class="animate-pulse bg-gray-200 dark:bg-gray-700 rounded-lg h-48" />',
    },
    delay: 200,
  });
  const TransactionStatsCharts = defineAsyncComponent({
    loader: () => import('@/features/money/components/TransactionStatsCharts.vue'),
    loadingComponent: {
      template: '<div class="animate-pulse bg-gray-200 dark:bg-gray-700 rounded-lg h-64" />',
    },
    delay: 200,
  });

  // 静态导入轻量组件
  import StatCard from '@/features/money/components/StatCard.vue';
  import TransactionStatsFilters from '@/features/money/components/TransactionStatsFilters.vue';
  import TransactionStatsTable from '@/features/money/components/TransactionStatsTable.vue';

  // 响应式数据
  const loading = ref(false);
  const useAdvancedCharts = ref(true);
  const statsData = ref({
    totalIncome: 0,
    totalExpense: 0,
    netIncome: 0,
    transactionCount: 0,
    averageTransaction: 0,
    topCategories: [] as Array<{
      category: string;
      amount: number;
      count: number;
      percentage: number;
    }>,
    topIncomeCategories: [] as Array<{
      category: string;
      amount: number;
      count: number;
      percentage: number;
    }>,
    topTransferCategories: [] as Array<{
      category: string;
      amount: number;
      count: number;
      percentage: number;
    }>,
    topPaymentMethods: [] as Array<{
      paymentMethod: string;
      amount: number;
      count: number;
      percentage: number;
    }>,
    topIncomePaymentMethods: [] as Array<{
      paymentMethod: string;
      amount: number;
      count: number;
      percentage: number;
    }>,
    topTransferPaymentMethods: [] as Array<{
      paymentMethod: string;
      amount: number;
      count: number;
      percentage: number;
    }>,
    monthlyTrends: [] as Array<{
      month: string;
      income: number;
      expense: number;
      netIncome: number;
    }>,
    weeklyTrends: [] as Array<{ week: string; income: number; expense: number; netIncome: number }>,
  });

  // 筛选条件
  const filters = ref({
    dateRange: {
      start: DateUtils.formatDateFromDate(DateUtils.getStartOfMonth(new Date())),
      end: DateUtils.formatDateFromDate(DateUtils.getEndOfMonth(new Date())),
    },
    timeDimension: 'month' as 'year' | 'month' | 'week',
    category: '',
    subCategory: '',
    accountSerialNum: '',
    transactionType: '',
    currency: '',
  });

  // 计算属性
  const currentPeriod = computed(() => {
    const { start } = filters.value.dateRange;
    const { timeDimension } = filters.value;

    const startDate = new Date(start);

    switch (timeDimension) {
      case 'year':
        return `${startDate.getFullYear()}年`;
      case 'month':
        return `${startDate.getFullYear()}年${startDate.getMonth() + 1}月`;
      case 'week':
        return `第${DateUtils.getWeekOfYear(startDate)}周`;
      default:
        return '';
    }
  });

  const netIncomeColor = computed(() => {
    return statsData.value.netIncome >= 0 ? 'success' : 'danger';
  });

  const netIncomeTrend = computed(() => {
    return statsData.value.netIncome >= 0 ? 'up' : 'down';
  });

  // 方法
  async function loadStatsData() {
    loading.value = true;
    try {
      const { start, end } = filters.value.dateRange;

      // 处理转账逻辑：如果选择转账，设置category为Transfer，transactionType为空
      let requestCategory = filters.value.category || undefined;
      let requestTransactionType = filters.value.transactionType || undefined;

      if (filters.value.transactionType === 'Transfer') {
        requestCategory = 'Transfer';
        requestTransactionType = undefined; // 转账时不需要设置transactionType
      }

      const request: TransactionStatsRequest = {
        startDate: start,
        endDate: end,
        timeDimension: filters.value.timeDimension,
        category: requestCategory,
        subCategory: filters.value.subCategory || undefined,
        accountSerialNum: filters.value.accountSerialNum || undefined,
        transactionType: requestTransactionType,
        currency: filters.value.currency || undefined,
      };

      const response: TransactionStatsResponse = await MoneyDb.getTransactionStats(request);

      // 更新统计数据
      statsData.value = {
        totalIncome: Number(response.summary.totalIncome) || 0,
        totalExpense: Number(response.summary.totalExpense) || 0,
        netIncome: Number(response.summary.netIncome) || 0,
        transactionCount: Number(response.summary.transactionCount) || 0,
        averageTransaction: Number(response.summary.averageTransaction) || 0,
        topCategories: response.topCategories.map(cat => ({
          category: cat.category,
          amount: Number(cat.amount) || 0,
          count: Number(cat.count) || 0,
          percentage: Number(cat.percentage) || 0,
        })),
        topIncomeCategories: response.topIncomeCategories.map(cat => ({
          category: cat.category,
          amount: Number(cat.amount) || 0,
          count: Number(cat.count) || 0,
          percentage: Number(cat.percentage) || 0,
        })),
        topTransferCategories: response.topTransferCategories.map(cat => ({
          category: cat.category,
          amount: Number(cat.amount) || 0,
          count: Number(cat.count) || 0,
          percentage: Number(cat.percentage) || 0,
        })),
        topPaymentMethods: response.topPaymentMethods.map(pm => ({
          paymentMethod: pm.paymentMethod,
          amount: Number(pm.amount) || 0,
          count: Number(pm.count) || 0,
          percentage: Number(pm.percentage) || 0,
        })),
        topIncomePaymentMethods: response.topIncomePaymentMethods.map(pm => ({
          paymentMethod: pm.paymentMethod,
          amount: Number(pm.amount) || 0,
          count: Number(pm.count) || 0,
          percentage: Number(pm.percentage) || 0,
        })),
        topTransferPaymentMethods: response.topTransferPaymentMethods.map(pm => ({
          paymentMethod: pm.paymentMethod,
          amount: Number(pm.amount) || 0,
          count: Number(pm.count) || 0,
          percentage: Number(pm.percentage) || 0,
        })),
        monthlyTrends: response.monthlyTrends.map(trend => ({
          month: trend.period,
          income: Number(trend.income) || 0,
          expense: Number(trend.expense) || 0,
          netIncome: Number(trend.netIncome) || 0,
        })),
        weeklyTrends: response.weeklyTrends.map(trend => ({
          week: trend.period,
          income: Number(trend.income) || 0,
          expense: Number(trend.expense) || 0,
          netIncome: Number(trend.netIncome) || 0,
        })),
      };
    } catch (error) {
      console.error('加载统计数据失败:', error);
    } finally {
      loading.value = false;
    }
  }

  function onFiltersChange(newFilters: typeof filters.value) {
    filters.value = { ...newFilters };
  }

  // 监听筛选条件变化
  watch(
    filters,
    () => {
      loadStatsData();
    },
    { deep: true },
  );

  // 生命周期
  onMounted(() => {
    loadStatsData();
  });
</script>

<template>
  <div class="max-w-7xl mx-auto p-4 sm:p-6 lg:p-8 w-full space-y-6">
    <!-- 筛选器 -->
    <TransactionStatsFilters v-model:filters="filters" @change="onFiltersChange" />

    <!-- 统计概览卡片 -->
    <div class="mb-8">
      <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-3 sm:gap-4">
        <StatCard
          title="总收入"
          :value="statsData.totalIncome.toFixed(2)"
          icon="trending-up"
          color="success"
          :loading="loading"
          :subtitle="currentPeriod"
        />
        <StatCard
          title="总支出"
          :value="statsData.totalExpense.toFixed(2)"
          icon="trending-down"
          color="danger"
          :loading="loading"
          :subtitle="currentPeriod"
        />
        <StatCard
          title="净收入"
          :value="statsData.netIncome.toFixed(2)"
          icon="wallet"
          :color="netIncomeColor"
          :trend-type="netIncomeTrend"
          :loading="loading"
          :subtitle="currentPeriod"
        />
        <StatCard
          title="交易笔数"
          :value="statsData.transactionCount.toString()"
          icon="credit-card"
          color="info"
          :loading="loading"
          :subtitle="`平均 ${statsData.averageTransaction.toFixed(2)}`"
        />
      </div>
    </div>

    <!-- 图表分析 -->
    <div class="mb-8">
      <div class="flex flex-row items-center justify-between mb-4">
        <h2 class="text-2xl sm:text-3xl font-semibold text-gray-900 dark:text-gray-100">
          数据分析
        </h2>
        <div class="flex items-center shrink-0">
          <label
            class="flex items-center gap-2 cursor-pointer text-sm text-gray-700 dark:text-gray-300"
          >
            <input
              v-model="useAdvancedCharts"
              type="checkbox"
              class="w-4 h-4 accent-blue-600 dark:accent-blue-500"
            />
            <span class="font-medium"> {{ useAdvancedCharts ? '高级图表' : '基础图表' }}</span>
          </label>
        </div>
      </div>
      <!-- 基础图表：收支趋势 + 分类图表切换器 -->
      <div v-if="!useAdvancedCharts" class="flex flex-col gap-6">
        <!-- 收支趋势图 -->
        <div class="w-full">
          <TransactionStatsCharts
            :monthly-trends="statsData.monthlyTrends"
            :weekly-trends="statsData.weeklyTrends"
            :top-categories="statsData.topCategories"
            :top-income-categories="statsData.topIncomeCategories"
            :top-transfer-categories="statsData.topTransferCategories"
            :time-dimension="filters.timeDimension"
            :transaction-type="filters.transactionType"
            :loading="loading"
          />
        </div>
        <!-- 分类图表切换器 -->
        <div class="w-full">
          <CategoryChartsSwitcher
            :top-categories="statsData.topCategories"
            :top-income-categories="statsData.topIncomeCategories"
            :top-transfer-categories="statsData.topTransferCategories"
            :transaction-type="filters.transactionType"
            :loading="loading"
          />
        </div>
        <!-- 支付渠道图表切换器 -->
        <div class="w-full mb-6">
          <PaymentMethodChartsSwitcher
            :top-payment-methods="statsData.topPaymentMethods"
            :top-income-payment-methods="statsData.topIncomePaymentMethods"
            :top-transfer-payment-methods="statsData.topTransferPaymentMethods"
            :transaction-type="filters.transactionType"
            :loading="loading"
          />
        </div>
      </div>
      <!-- 高级图表：收支趋势 + 分类图表切换器 -->
      <div v-else class="flex flex-col gap-6">
        <!-- 收支趋势图 -->
        <div class="w-full">
          <AdvancedTransactionCharts
            :monthly-trends="statsData.monthlyTrends"
            :weekly-trends="statsData.weeklyTrends"
            :top-categories="statsData.topCategories"
            :top-income-categories="statsData.topIncomeCategories"
            :top-transfer-categories="statsData.topTransferCategories"
            :time-dimension="filters.timeDimension"
            :transaction-type="filters.transactionType"
            :loading="loading"
          />
        </div>
        <!-- 分类图表切换器 -->
        <div class="w-full">
          <CategoryChartsSwitcher
            :top-categories="statsData.topCategories"
            :top-income-categories="statsData.topIncomeCategories"
            :top-transfer-categories="statsData.topTransferCategories"
            :transaction-type="filters.transactionType"
            :loading="loading"
          />
        </div>
        <!-- 支付渠道图表切换器 -->
        <div class="w-full mb-6">
          <PaymentMethodChartsSwitcher
            :top-payment-methods="statsData.topPaymentMethods"
            :top-income-payment-methods="statsData.topIncomePaymentMethods"
            :top-transfer-payment-methods="statsData.topTransferPaymentMethods"
            :transaction-type="filters.transactionType"
            :loading="loading"
          />
        </div>
      </div>
    </div>

    <!-- 详细统计表格 -->
    <div class="mb-8">
      <TransactionStatsTable
        :top-categories="statsData.topCategories"
        :top-income-categories="statsData.topIncomeCategories"
        :top-transfer-categories="statsData.topTransferCategories"
        :transaction-type="filters.transactionType"
        :loading="loading"
      />
    </div>
  </div>
</template>
