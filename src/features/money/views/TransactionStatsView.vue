<script setup lang="ts">
import AdvancedTransactionCharts from '@/features/money/components/AdvancedTransactionCharts.vue';
import StatCard from '@/features/money/components/StatCard.vue';
import TransactionStatsCharts from '@/features/money/components/TransactionStatsCharts.vue';
import TransactionStatsFilters from '@/features/money/components/TransactionStatsFilters.vue';
import TransactionStatsTable from '@/features/money/components/TransactionStatsTable.vue';
import { MoneyDb } from '@/services/money/money';
import { DateUtils } from '@/utils/date';
import type {
  TransactionStatsRequest,
  TransactionStatsResponse,
} from '@/services/money/transactions';

// 响应式数据
const loading = ref(false);
const useAdvancedCharts = ref(true);
const statsData = ref({
  totalIncome: 0,
  totalExpense: 0,
  netIncome: 0,
  transactionCount: 0,
  averageTransaction: 0,
  topCategories: [] as Array<{ category: string; amount: number; count: number; percentage: number }>,
  topIncomeCategories: [] as Array<{ category: string; amount: number; count: number; percentage: number }>,
  topTransferCategories: [] as Array<{ category: string; amount: number; count: number; percentage: number }>,
  monthlyTrends: [] as Array<{ month: string; income: number; expense: number; netIncome: number }>,
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
watch(filters, () => {
  loadStatsData();
}, { deep: true });

// 生命周期
onMounted(() => {
  loadStatsData();
});
</script>

<template>
  <div class="transaction-stats-view">
    <!-- 筛选器 -->
    <TransactionStatsFilters
      v-model:filters="filters"
      @change="onFiltersChange"
    />

    <!-- 统计概览卡片 -->
    <div class="stats-overview">
      <div class="stats-grid">
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
    <div class="charts-section">
      <div class="charts-header">
        <h2 class="charts-title">
          数据分析
        </h2>
        <div class="charts-toggle">
          <label class="toggle-label">
            <input
              v-model="useAdvancedCharts"
              type="checkbox"
              class="toggle-input"
            >
            <span class="toggle-text">
              {{ useAdvancedCharts ? '高级图表' : '基础图表' }}
            </span>
          </label>
        </div>
      </div>
      <TransactionStatsCharts
        v-if="!useAdvancedCharts"
        :monthly-trends="statsData.monthlyTrends"
        :weekly-trends="statsData.weeklyTrends"
        :top-categories="statsData.topCategories"
        :top-income-categories="statsData.topIncomeCategories"
        :top-transfer-categories="statsData.topTransferCategories"
        :time-dimension="filters.timeDimension"
        :transaction-type="filters.transactionType"
        :loading="loading"
      />
      <AdvancedTransactionCharts
        v-else
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

    <!-- 详细统计表格 -->
    <div class="table-section">
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

<style scoped lang="postcss">
.transaction-stats-view {
  max-width: 1200px;
  margin: 0 auto;
  padding: 1rem;
  width: 100%;
  box-sizing: border-box;
}

.transaction-stats-view > * + * {
  margin-top: 1.5rem;
}

.stats-overview {
  margin-bottom: 2rem;
}

.stats-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  gap: 0.75rem;
}

.charts-section {
  margin-bottom: 2rem;
}

.charts-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1rem;
}

.charts-title {
  font-size: 1.5rem;
  font-weight: 600;
  color: var(--color-accent-content);
}

.charts-toggle {
  display: flex;
  align-items: center;
}

.toggle-label {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  cursor: pointer;
  font-size: 0.875rem;
  color: var(--color-neutral);
}

.toggle-input {
  width: 1rem;
  height: 1rem;
  accent-color: var(--color-primary);
}

.toggle-text {
  font-weight: 500;
}

.table-section {
  margin-bottom: 2rem;
}

/* 移动端优化 */
@media (max-width: 768px) {
  .transaction-stats-view {
    padding: 0.5rem;
    max-width: 100%;
    margin: 0;
  }

  .stats-grid {
    grid-template-columns: 1fr;
    gap: 0.5rem;
  }

  .charts-header {
    flex-direction: column;
    gap: 1rem;
    align-items: flex-start;
  }

  .charts-title {
    font-size: 1.25rem;
  }

  .charts-toggle {
    width: 100%;
    justify-content: flex-start;
  }
}

/* 超小屏幕优化 */
@media (max-width: 480px) {
  .transaction-stats-view {
    padding: 0.25rem;
  }

  .stats-grid {
    gap: 0.25rem;
  }

  .charts-title {
    font-size: 1.125rem;
  }
}
</style>
