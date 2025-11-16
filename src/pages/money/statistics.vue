<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { useMoneyAuth } from '@/composables/useMoneyAuth';
import AdvancedTransactionCharts from '@/features/money/components/AdvancedTransactionCharts.vue';
import CategoryChartsSwitcher from '@/features/money/components/CategoryChartsSwitcher.vue';
import MemberContributionChart from '@/features/money/components/charts/MemberContributionChart.vue';
import DebtRelationChart from '@/features/money/components/DebtRelationChart.vue';
import PaymentMethodChartsSwitcher from '@/features/money/components/PaymentMethodChartsSwitcher.vue';

definePage({
  name: 'statistics',
  meta: {
    requiresAuth: true,
    title: '家庭财务统计',
  },
});

const { currentLedgerSerialNum: _currentLedgerSerialNum } = useMoneyAuth();

// 加载状态
const loading = ref(false);

// 时间范围选择
const dateRange = ref({
  start: new Date(new Date().getFullYear(), new Date().getMonth(), 1).toISOString().split('T')[0],
  end: new Date().toISOString().split('T')[0],
});

// 分类数据（示例）
const topCategories = ref([
  { category: 'Food', amount: 3500, count: 45, percentage: 35 },
  { category: 'Transport', amount: 1500, count: 30, percentage: 15 },
  { category: 'Shopping', amount: 2000, count: 20, percentage: 20 },
  { category: 'Entertainment', amount: 1000, count: 15, percentage: 10 },
  { category: 'Healthcare', amount: 800, count: 8, percentage: 8 },
  { category: 'Education', amount: 600, count: 6, percentage: 6 },
  { category: 'Housing', amount: 400, count: 4, percentage: 4 },
  { category: 'Other', amount: 200, count: 2, percentage: 2 },
]);

const topIncomeCategories = ref([
  { category: 'Salary', amount: 15000, count: 2, percentage: 75 },
  { category: 'Bonus', amount: 3000, count: 1, percentage: 15 },
  { category: 'Investment', amount: 2000, count: 5, percentage: 10 },
]);

// 支付方式数据（示例）
const paymentMethods = ref([
  { paymentMethod: 'Alipay', amount: 5000, count: 50, percentage: 50 },
  { paymentMethod: 'WeChat', amount: 3000, count: 30, percentage: 30 },
  { paymentMethod: 'Cash', amount: 1000, count: 15, percentage: 10 },
  { paymentMethod: 'BankCard', amount: 1000, count: 5, percentage: 10 },
]);

// 成员数据（示例）
const memberData = ref([
  { name: '张三', totalPaid: 5000, totalOwed: 3000, netBalance: 2000, color: '#3b82f6' },
  { name: '李四', totalPaid: 4000, totalOwed: 4500, netBalance: -500, color: '#10b981' },
  { name: '王五', totalPaid: 3000, totalOwed: 2500, netBalance: 500, color: '#f59e0b' },
]);

// 时间维度选择
const timeDimension = ref<'year' | 'month' | 'week'>('month');

// 月度趋势数据（示例）
const monthlyTrends = ref([
  { month: '1月', income: 20000, expense: 8000, netIncome: 12000 },
  { month: '2月', income: 18000, expense: 9000, netIncome: 9000 },
  { month: '3月', income: 22000, expense: 8500, netIncome: 13500 },
  { month: '4月', income: 21000, expense: 9500, netIncome: 11500 },
  { month: '5月', income: 23000, expense: 10000, netIncome: 13000 },
  { month: '6月', income: 25000, expense: 11000, netIncome: 14000 },
]);

// 周度趋势数据（示例）
const weeklyTrends = ref([
  { week: '第1周', income: 5000, expense: 2000, netIncome: 3000 },
  { week: '第2周', income: 4500, expense: 2200, netIncome: 2300 },
  { week: '第3周', income: 5500, expense: 2500, netIncome: 3000 },
  { week: '第4周', income: 6000, expense: 2800, netIncome: 3200 },
]);

// 统计汇总
const summary = computed(() => ({
  totalExpense: topCategories.value.reduce((sum, cat) => sum + cat.amount, 0),
  totalIncome: topIncomeCategories.value.reduce((sum, cat) => sum + cat.amount, 0),
  transactionCount: topCategories.value.reduce((sum, cat) => sum + cat.count, 0),
  balance: topIncomeCategories.value.reduce((sum, cat) => sum + cat.amount, 0) -
    topCategories.value.reduce((sum, cat) => sum + cat.amount, 0),
}));

// 加载数据
async function loadStatistics() {
  loading.value = true;
  try {
    // TODO: 调用实际的API获取统计数据
    // const stats = await statisticsService.getFamilyStats({
    //   familyLedgerSerialNum: _currentLedgerSerialNum.value,
    //   startDate: dateRange.value.start,
    //   endDate: dateRange.value.end,
    // });

    await new Promise(resolve => setTimeout(resolve, 500));
  } catch (error) {
    console.error('加载统计数据失败:', error);
  } finally {
    loading.value = false;
  }
}

// 导出数据
function handleExport(format: 'csv' | 'excel' | 'pdf') {
  // eslint-disable-next-line no-console
  console.log('导出数据:', format);
  // TODO: 实现导出功能
}

onMounted(() => {
  loadStatistics();
});
</script>

<template>
  <div class="statistics-page">
    <!-- 页面标题 -->
    <div class="page-header">
      <div class="header-left">
        <h1 class="page-title">
          家庭财务统计
        </h1>
        <p class="page-subtitle">
          数据可视化分析与报表
        </p>
      </div>
      <div class="header-right">
        <div class="date-range-picker">
          <input v-model="dateRange.start" type="date" class="date-input">
          <span class="date-separator">至</span>
          <input v-model="dateRange.end" type="date" class="date-input">
        </div>
        <button class="btn-secondary" @click="loadStatistics">
          刷新
        </button>
        <div class="export-dropdown">
          <button class="btn-primary">
            导出
          </button>
          <div class="dropdown-menu">
            <button @click="handleExport('csv')">
              CSV格式
            </button>
            <button @click="handleExport('excel')">
              Excel格式
            </button>
            <button @click="handleExport('pdf')">
              PDF报表
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- 统计汇总卡片 -->
    <div class="summary-cards">
      <div class="summary-card expense">
        <div class="card-label">
          总支出
        </div>
        <div class="card-value">
          ¥{{ summary.totalExpense.toFixed(2) }}
        </div>
        <div class="card-hint">
          {{ summary.transactionCount }}笔交易
        </div>
      </div>
      <div class="summary-card income">
        <div class="card-label">
          总收入
        </div>
        <div class="card-value">
          ¥{{ summary.totalIncome.toFixed(2) }}
        </div>
        <div class="card-hint">
          本期收入
        </div>
      </div>
      <div class="summary-card balance" :class="{ positive: summary.balance > 0, negative: summary.balance < 0 }">
        <div class="card-label">
          结余
        </div>
        <div class="card-value">
          ¥{{ summary.balance.toFixed(2) }}
        </div>
        <div class="card-hint">
          {{ summary.balance > 0 ? '盈余' : '超支' }}
        </div>
      </div>
    </div>

    <!-- 图表网格 -->
    <div class="charts-grid">
      <!-- 分类图表 -->
      <div class="chart-card">
        <CategoryChartsSwitcher
          :top-categories="topCategories"
          :top-income-categories="topIncomeCategories"
          :loading="loading"
        />
      </div>

      <!-- 支付方式图表 -->
      <div class="chart-card">
        <PaymentMethodChartsSwitcher
          :top-payment-methods="paymentMethods"
          :loading="loading"
        />
      </div>

      <!-- 成员贡献图 -->
      <div class="chart-card">
        <MemberContributionChart
          :data="memberData"
          title="成员支付贡献度"
          height="400px"
        />
      </div>

      <!-- 债务关系图 -->
      <div class="chart-card">
        <DebtRelationChart
          :family-ledger-serial-num="_currentLedgerSerialNum"
        />
      </div>

      <!-- 高级交易图表 -->
      <div class="chart-card full-width">
        <AdvancedTransactionCharts
          :monthly-trends="monthlyTrends"
          :weekly-trends="weeklyTrends"
          :top-categories="topCategories"
          :top-income-categories="topIncomeCategories"
          :time-dimension="timeDimension"
          :loading="loading"
        />
      </div>
    </div>
  </div>
</template>

<style scoped>
.statistics-page {
  width: 100%;
  min-height: 100vh;
  padding: 24px;
  background-color: #f9fafb;
}

.page-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 24px;
  background: white;
  padding: 20px;
  border-radius: 12px;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
}

.header-left {
  flex: 1;
}

.page-title {
  font-size: 24px;
  font-weight: 600;
  color: #1f2937;
  margin: 0 0 8px 0;
}

.page-subtitle {
  font-size: 14px;
  color: #6b7280;
  margin: 0;
}

.header-right {
  display: flex;
  gap: 12px;
  align-items: center;
}

.date-range-picker {
  display: flex;
  align-items: center;
  gap: 8px;
}

.date-input {
  padding: 8px 12px;
  border: 1px solid #d1d5db;
  border-radius: 6px;
  font-size: 14px;
}

.date-separator {
  color: #6b7280;
  font-size: 14px;
}

.btn-primary,
.btn-secondary {
  padding: 8px 16px;
  border: none;
  border-radius: 6px;
  font-size: 14px;
  cursor: pointer;
  transition: all 0.2s;
}

.btn-primary {
  background-color: #3b82f6;
  color: white;
}

.btn-primary:hover {
  background-color: #2563eb;
}

.btn-secondary {
  background-color: #f3f4f6;
  color: #374151;
  border: 1px solid #d1d5db;
}

.btn-secondary:hover {
  background-color: #e5e7eb;
}

.export-dropdown {
  position: relative;
}

.export-dropdown:hover .dropdown-menu {
  display: block;
}

.dropdown-menu {
  display: none;
  position: absolute;
  top: 100%;
  right: 0;
  margin-top: 4px;
  background: white;
  border: 1px solid #d1d5db;
  border-radius: 6px;
  box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
  z-index: 10;
  min-width: 150px;
}

.dropdown-menu button {
  width: 100%;
  padding: 10px 16px;
  text-align: left;
  border: none;
  background: none;
  cursor: pointer;
  font-size: 14px;
  color: #374151;
}

.dropdown-menu button:hover {
  background-color: #f3f4f6;
}

.summary-cards {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
  gap: 16px;
  margin-bottom: 24px;
}

.summary-card {
  background: white;
  padding: 20px;
  border-radius: 12px;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
  border-left: 4px solid;
}

.summary-card.expense {
  border-left-color: #ef4444;
}

.summary-card.income {
  border-left-color: #10b981;
}

.summary-card.balance {
  border-left-color: #3b82f6;
}

.summary-card.balance.positive {
  border-left-color: #10b981;
}

.summary-card.balance.negative {
  border-left-color: #ef4444;
}

.card-label {
  font-size: 14px;
  color: #6b7280;
  margin-bottom: 8px;
}

.card-value {
  font-size: 28px;
  font-weight: 600;
  color: #1f2937;
  margin-bottom: 4px;
}

.card-hint {
  font-size: 12px;
  color: #9ca3af;
}

.charts-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(500px, 1fr));
  gap: 24px;
}

.chart-card {
  background: white;
  padding: 24px;
  border-radius: 12px;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
}

.chart-card.full-width {
  grid-column: 1 / -1;
}

@media (max-width: 768px) {
  .statistics-page {
    padding: 16px;
  }

  .page-header {
    flex-direction: column;
    align-items: flex-start;
    gap: 16px;
  }

  .header-right {
    width: 100%;
    flex-wrap: wrap;
  }

  .charts-grid {
    grid-template-columns: 1fr;
  }
}
</style>
