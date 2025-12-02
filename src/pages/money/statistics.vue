<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import Button from '@/components/ui/Button.vue';
import Dropdown from '@/components/ui/Dropdown.vue';
import { useMoneyAuth } from '@/composables/useMoneyAuth';
import AdvancedTransactionCharts from '@/features/money/components/AdvancedTransactionCharts.vue';
import CategoryChartsSwitcher from '@/features/money/components/CategoryChartsSwitcher.vue';
import MemberContributionChart from '@/features/money/components/charts/MemberContributionChart.vue';
import DebtRelationChart from '@/features/money/components/DebtRelationChart.vue';
import PaymentMethodChartsSwitcher from '@/features/money/components/PaymentMethodChartsSwitcher.vue';
import { Permission } from '@/types/auth';
import type { DropdownOption } from '@/components/ui/Dropdown.vue';

definePage({
  name: 'statistics',
  meta: {
    requiresAuth: true,
    permissions: [Permission.STATS_VIEW],
    title: '家庭财务统计',
    icon: 'bar-chart',
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

// 导出选项
const exportOptions: DropdownOption[] = [
  { value: 'csv', label: 'CSV格式' },
  { value: 'excel', label: 'Excel格式' },
  { value: 'pdf', label: 'PDF报表' },
];

// 导出数据
function handleExport(format: string) {
  // eslint-disable-next-line no-console
  console.log('导出数据:', format);
  // TODO: 实现导出功能
}

onMounted(() => {
  loadStatistics();
});
</script>

<template>
  <div class="w-full min-h-screen p-4 sm:p-6 bg-gray-50 dark:bg-gray-900">
    <!-- 页面标题 -->
    <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 mb-6 bg-white dark:bg-gray-800 p-4 sm:p-5 rounded-xl shadow-sm">
      <div class="flex-1 min-w-0">
        <h1 class="text-2xl sm:text-3xl font-semibold text-gray-900 dark:text-white mb-2 truncate">
          家庭财务统计
        </h1>
        <p class="text-sm text-gray-600 dark:text-gray-400">
          数据可视化分析与报表
        </p>
      </div>
      <div class="flex flex-wrap items-center gap-3 shrink-0">
        <!-- 日期范围选择器 -->
        <div class="flex items-center gap-2">
          <input
            v-model="dateRange.start"
            type="date"
            class="px-3 py-2 text-sm border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-blue-500"
          >
          <span class="text-sm text-gray-600 dark:text-gray-400">至</span>
          <input
            v-model="dateRange.end"
            type="date"
            class="px-3 py-2 text-sm border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-blue-500"
          >
        </div>
        <Button variant="secondary" size="sm" @click="loadStatistics">
          刷新
        </Button>
        <Dropdown
          :options="exportOptions"
          label="导出"
          variant="default"
          size="sm"
          @select="handleExport"
        />
      </div>
    </div>

    <!-- 统计汇总卡片 -->
    <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4 mb-6">
      <!-- 总支出 -->
      <div class="bg-white dark:bg-gray-800 p-5 rounded-xl shadow-sm border-l-4 border-l-red-500">
        <div class="text-sm text-gray-600 dark:text-gray-400 mb-2">
          总支出
        </div>
        <div class="text-3xl font-semibold text-gray-900 dark:text-white mb-1">
          ¥{{ summary.totalExpense.toFixed(2) }}
        </div>
        <div class="text-xs text-gray-500 dark:text-gray-400">
          {{ summary.transactionCount }}笔交易
        </div>
      </div>

      <!-- 总收入 -->
      <div class="bg-white dark:bg-gray-800 p-5 rounded-xl shadow-sm border-l-4 border-l-green-500">
        <div class="text-sm text-gray-600 dark:text-gray-400 mb-2">
          总收入
        </div>
        <div class="text-3xl font-semibold text-gray-900 dark:text-white mb-1">
          ¥{{ summary.totalIncome.toFixed(2) }}
        </div>
        <div class="text-xs text-gray-500 dark:text-gray-400">
          本期收入
        </div>
      </div>

      <!-- 结余 -->
      <div class="bg-white dark:bg-gray-800 p-5 rounded-xl shadow-sm border-l-4" :class="summary.balance > 0 ? 'border-l-green-500' : summary.balance < 0 ? 'border-l-red-500' : 'border-l-blue-500'">
        <div class="text-sm text-gray-600 dark:text-gray-400 mb-2">
          结余
        </div>
        <div class="text-3xl font-semibold text-gray-900 dark:text-white mb-1">
          ¥{{ summary.balance.toFixed(2) }}
        </div>
        <div class="text-xs text-gray-500 dark:text-gray-400">
          {{ summary.balance > 0 ? '盈余' : '超支' }}
        </div>
      </div>
    </div>

    <!-- 图表网格 -->
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
      <!-- 分类图表 -->
      <div class="bg-white dark:bg-gray-800 p-6 rounded-xl shadow-sm">
        <CategoryChartsSwitcher
          :top-categories="topCategories"
          :top-income-categories="topIncomeCategories"
          :loading="loading"
        />
      </div>

      <!-- 支付方式图表 -->
      <div class="bg-white dark:bg-gray-800 p-6 rounded-xl shadow-sm">
        <PaymentMethodChartsSwitcher
          :top-payment-methods="paymentMethods"
          :loading="loading"
        />
      </div>

      <!-- 成员贡献图 -->
      <div class="bg-white dark:bg-gray-800 p-6 rounded-xl shadow-sm">
        <MemberContributionChart
          :data="memberData"
          title="成员支付贡献度"
          height="400px"
        />
      </div>

      <!-- 债务关系图 -->
      <div class="bg-white dark:bg-gray-800 p-6 rounded-xl shadow-sm">
        <DebtRelationChart
          :family-ledger-serial-num="_currentLedgerSerialNum"
        />
      </div>

      <!-- 高级交易图表 - 占满整行 -->
      <div class="bg-white dark:bg-gray-800 p-6 rounded-xl shadow-sm lg:col-span-2">
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
