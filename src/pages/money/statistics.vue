<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import Button from '@/components/ui/Button.vue';
import Dropdown from '@/components/ui/Dropdown.vue';
import { useMoneyAuth } from '@/composables/useMoneyAuth';
import { Permission } from '@/types/auth';
import type { DropdownOption } from '@/components/ui/Dropdown.vue';

// 懒加载重型图表组件 (Task 27: 大于50KB的组件使用动态导入)
const AdvancedTransactionCharts = defineAsyncComponent({
  loader: () => import('@/features/money/components/AdvancedTransactionCharts.vue'),
  loadingComponent: { template: '<div class="animate-pulse bg-gray-200 dark:bg-gray-700 rounded-lg h-64" />' },
  delay: 200,
});
const CategoryChartsSwitcher = defineAsyncComponent({
  loader: () => import('@/features/money/components/CategoryChartsSwitcher.vue'),
  loadingComponent: { template: '<div class="animate-pulse bg-gray-200 dark:bg-gray-700 rounded-lg h-48" />' },
  delay: 200,
});
const MemberContributionChart = defineAsyncComponent({
  loader: () => import('@/features/money/components/charts/MemberContributionChart.vue'),
  loadingComponent: { template: '<div class="animate-pulse bg-gray-200 dark:bg-gray-700 rounded-lg h-48" />' },
  delay: 200,
});
const DebtRelationChart = defineAsyncComponent({
  loader: () => import('@/features/money/components/DebtRelationChart.vue'),
  loadingComponent: { template: '<div class="animate-pulse bg-gray-200 dark:bg-gray-700 rounded-lg h-48" />' },
  delay: 200,
});
const PaymentMethodChartsSwitcher = defineAsyncComponent({
  loader: () => import('@/features/money/components/PaymentMethodChartsSwitcher.vue'),
  loadingComponent: { template: '<div class="animate-pulse bg-gray-200 dark:bg-gray-700 rounded-lg h-48" />' },
  delay: 200,
});

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

// 分类数据 - 从API加载
const topCategories = ref<{ category: string; amount: number; count: number; percentage: number }[]>([]);
const topIncomeCategories = ref<{ category: string; amount: number; count: number; percentage: number }[]>([]);

// 支付方式数据 - 从API加载
const paymentMethods = ref<{ paymentMethod: string; amount: number; count: number; percentage: number }[]>([]);

// 成员数据 - 从API加载
const memberData = ref<{ name: string; totalPaid: number; totalOwed: number; netBalance: number; color: string }[]>([]);

// 时间维度选择
const timeDimension = ref<'year' | 'month' | 'week'>('month');

// 月度趋势数据 - 从API加载
const monthlyTrends = ref<{ month: string; income: number; expense: number; netIncome: number }[]>([]);

// 周度趋势数据 - 从API加载
const weeklyTrends = ref<{ week: string; income: number; expense: number; netIncome: number }[]>([]);

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
  if (!_currentLedgerSerialNum.value) return;

  loading.value = true;
  try {
    // TODO: 实现统计数据API调用
    // const stats = await statisticsService.getFamilyStats({
    //   familyLedgerSerialNum: _currentLedgerSerialNum.value,
    //   startDate: dateRange.value.start,
    //   endDate: dateRange.value.end,
    // });
    // topCategories.value = stats.topCategories;
    // topIncomeCategories.value = stats.topIncomeCategories;
    // paymentMethods.value = stats.paymentMethods;
    // memberData.value = stats.memberData;
    // monthlyTrends.value = stats.monthlyTrends;
    // weeklyTrends.value = stats.weeklyTrends;
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
