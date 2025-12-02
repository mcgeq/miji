<script setup lang="ts">
import { AlertCircle, BarChart3, PieChart, TrendingUp, X } from 'lucide-vue-next';
import VChart from 'vue-echarts';
import { useRouter } from 'vue-router';
import { Button, Card, Spinner } from '@/components/ui';
import { useBudgetStats } from '@/composables/useBudgetStats';
import { initECharts } from '@/utils/echarts';

const router = useRouter();

// 使用预算统计 composable
const {
  state,
  filters,
  hasData,
  isHealthy,
  needsAttention,
  loadAllStats,
  resetFilters,
} = useBudgetStats();

// 显示状态
const showFilters = ref(false);
const showStats = ref(false);

// 初始化ECharts
initECharts();

// 图表类型切换
const chartType = ref<'trend' | 'category' | 'overview'>('trend');
const trendChartType = ref<'line' | 'bar' | 'area'>('line');
const categoryChartType = ref<'pie' | 'bar' | 'radar'>('pie');

// 图表唯一标识，用于强制重新创建实例
const chartKey = computed(() => `${chartType.value}-${trendChartType.value}-${categoryChartType.value}`);

// 图表实例引用
const chartRef = ref();

// 确保图表在下一个 tick 中正确渲染
async function ensureChartRender() {
  await nextTick();
  // 等待 DOM 更新完成
  await new Promise(resolve => setTimeout(resolve, 100));
  if (chartRef.value) {
    try {
      // 检查容器是否有有效尺寸
      const container = chartRef.value.$el;
      if (container && container.clientWidth > 0 && container.clientHeight > 0) {
        chartRef.value.resize();
      } else {
        // 如果容器尺寸为0，延迟重试
        setTimeout(() => {
          if (chartRef.value) {
            chartRef.value.resize();
          }
        }, 200);
      }
    } catch (error) {
      console.warn('图表渲染失败:', error);
    }
  }
}

// 监听数据变化，确保图表正确渲染
watch(
  [() => state.value.trends, () => state.value.categoryStats, () => chartType.value],
  async () => {
    if (hasData.value && !state.value.loading) {
      await ensureChartRender();
    }
  },
  { deep: true },
);

// 组件销毁时清理
onUnmounted(() => {
  // 清理可能的定时器或监听器
});

// 计算属性
const statusColor = computed(() => {
  if (needsAttention.value) return 'text-red-500';
  if (isHealthy.value) return 'text-green-500';
  return 'text-gray-500';
});

const statusText = computed(() => {
  if (needsAttention.value) return '需要关注';
  if (isHealthy.value) return '健康';
  return '未知';
});

const statusIcon = computed(() => {
  if (needsAttention.value) return '!';
  if (isHealthy.value) return '✅';
  return '❓';
});

// 方法
function toggleFilters() {
  showFilters.value = !showFilters.value;
};

function handleResetFilters() {
  resetFilters();
};

// 监听筛选条件变化
watch(filters, () => {
  if (showStats.value) {
    loadAllStats();
  }
}, { deep: true });

// 格式化货币
function formatCurrency(amount: number) {
  return new Intl.NumberFormat('zh-CN', {
    style: 'currency',
    currency: 'CNY',
  }).format(amount);
}

// 格式化百分比
function formatPercentage(value: number) {
  return `${value.toFixed(1)}%`;
}

// 跳转到预算列表页面
function goToBudgetList() {
  router.push('/money');
}

// 创建测试数据
async function createTestData() {
  try {
    // 这里可以调用后端 API 创建测试预算数据
    // 创建完成后刷新数据
    await loadAllStats();
  } catch (error) {
    console.error('创建测试数据失败:', error);
    // eslint-disable-next-line no-alert
    alert('创建测试数据失败，请手动创建预算数据。');
  }
}

// 图表配置
const trendChartOption = computed(() => {
  if (!state.value.trends.length) {
    return {
      title: {
        text: '暂无趋势数据',
        left: 'center',
        top: 'middle',
        textStyle: {
          color: '#999',
          fontSize: 16,
        },
      },
    };
  }

  const periods = state.value.trends.map(item => item.period);
  const totalBudgets = state.value.trends.map(item => item.totalBudget);
  const usedAmounts = state.value.trends.map(item => item.usedAmount);
  const remainingAmounts = state.value.trends.map(item => item.remainingAmount);

  const baseOption = {
    tooltip: {
      trigger: 'axis',
      axisPointer: {
        type: 'cross',
      },
    },
    legend: {
      data: ['总预算', '已使用', '剩余'],
      top: 30,
    },
    xAxis: {
      type: 'category',
      data: periods,
      axisLabel: {
        rotate: 45,
      },
    },
    yAxis: {
      type: 'value',
      axisLabel: {
        formatter: '¥{value}',
      },
    },
    series: [
      {
        name: '总预算',
        type: trendChartType.value,
        data: totalBudgets,
        itemStyle: { color: '#3b82f6' },
        areaStyle: trendChartType.value === 'area' ? { opacity: 0.3 } : undefined,
      },
      {
        name: '已使用',
        type: trendChartType.value,
        data: usedAmounts,
        itemStyle: { color: '#ef4444' },
        areaStyle: trendChartType.value === 'area' ? { opacity: 0.3 } : undefined,
      },
      {
        name: '剩余',
        type: trendChartType.value,
        data: remainingAmounts,
        itemStyle: { color: '#10b981' },
        areaStyle: trendChartType.value === 'area' ? { opacity: 0.3 } : undefined,
      },
    ],
  };

  return baseOption;
});

const categoryChartOption = computed(() => {
  if (!state.value.categoryStats.length) {
    return {
      title: {
        text: '暂无分类数据',
        left: 'center',
        top: 'middle',
        textStyle: {
          color: '#999',
          fontSize: 16,
        },
      },
    };
  }

  const categories = state.value.categoryStats.map(item => item.category);
  const budgets = state.value.categoryStats.map(item => item.totalBudget);
  const usedAmounts = state.value.categoryStats.map(item => item.usedAmount);

  if (categoryChartType.value === 'pie') {
    return {
      tooltip: {
        trigger: 'item',
        formatter: '{a} <br/>{b}: ¥{c} ({d}%)',
      },
      series: [
        {
          name: '预算金额',
          type: 'pie',
          radius: '50%',
          data: categories.map((category, index) => ({
            value: budgets[index],
            name: category,
          })),
          emphasis: {
            itemStyle: {
              shadowBlur: 10,
              shadowOffsetX: 0,
              shadowColor: 'rgba(0, 0, 0, 0.5)',
            },
          },
        },
      ],
    };
  }

  return {
    tooltip: {
      trigger: 'axis',
      axisPointer: {
        type: 'shadow',
      },
    },
    xAxis: {
      type: 'category',
      data: categories,
      axisLabel: {
        rotate: 45,
      },
    },
    yAxis: {
      type: 'value',
      axisLabel: {
        formatter: '¥{value}',
      },
    },
    series: [
      {
        name: '总预算',
        type: categoryChartType.value === 'radar' ? 'radar' : 'bar',
        data: budgets,
        itemStyle: { color: '#3b82f6' },
      },
      {
        name: '已使用',
        type: categoryChartType.value === 'radar' ? 'radar' : 'bar',
        data: usedAmounts,
        itemStyle: { color: '#ef4444' },
      },
    ],
  };
});

const currentChartOption = computed(() => {
  switch (chartType.value) {
    case 'trend':
      return trendChartOption.value;
    case 'category':
      return categoryChartOption.value;
    default:
      return trendChartOption.value;
  }
});
</script>

<template>
  <div class="space-y-6">
    <!-- 加载状态 -->
    <div v-if="state.loading" class="flex flex-col items-center justify-center py-10">
      <Spinner size="lg" />
      <div class="text-sm text-gray-500 dark:text-gray-400 mt-4">
        加载统计数据中...
      </div>
    </div>

    <!-- 空状态 -->
    <div v-else-if="!hasData" class="flex flex-col items-center justify-center py-10 text-gray-500 dark:text-gray-400">
      <div class="text-5xl mb-4">
        📊
      </div>
      <div class="text-base font-medium mb-2">
        暂无统计数据
      </div>
      <div class="text-sm text-center max-w-md mb-4">
        <p class="my-1">
          系统中还没有预算数据，无法进行统计分析。
        </p>
        <p class="my-1">
          请先创建一些预算，然后再查看统计结果。
        </p>
      </div>
      <div class="bg-gray-100 dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg p-3 my-4 text-xs text-gray-600 dark:text-gray-400 text-left max-w-xs">
        <p class="my-1">
          调试信息:
        </p>
        <p class="my-1">
          Loading: {{ state.loading }}
        </p>
        <p class="my-1">
          Has Data: {{ hasData }}
        </p>
        <p class="my-1">
          Overview: {{ state.overview ? `有数据 (${state.overview.budgetCount} 个预算)` : '无数据' }}
        </p>
        <p class="my-1">
          Error: {{ state.error || '无错误' }}
        </p>
      </div>
      <div class="flex gap-3 justify-center flex-wrap">
        <Button variant="primary" @click="goToBudgetList">
          去创建预算
        </Button>
        <Button variant="secondary" @click="loadAllStats">
          刷新数据
        </Button>
        <Button variant="success" @click="createTestData">
          创建测试数据
        </Button>
      </div>
    </div>

    <!-- 统计概览卡片 -->
    <div v-if="state.overview" class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-4">
      <!-- 总预算 -->
      <Card padding="md" hoverable>
        <div class="flex items-center">
          <div class="mr-3 shrink-0">
            <PieChart :size="24" class="text-blue-500" />
          </div>
          <div class="flex-1">
            <div class="text-sm text-gray-600 dark:text-gray-400 mb-1">
              总预算
            </div>
            <div class="text-xl font-bold text-gray-900 dark:text-white">
              {{ formatCurrency(state.overview.totalBudgetAmount) }}
            </div>
          </div>
        </div>
      </Card>

      <!-- 已使用 -->
      <Card padding="md" hoverable>
        <div class="flex items-center">
          <div class="mr-3 shrink-0">
            <TrendingUp :size="24" class="text-green-500" />
          </div>
          <div class="flex-1">
            <div class="text-sm text-gray-600 dark:text-gray-400 mb-1">
              已使用
            </div>
            <div class="text-xl font-bold text-gray-900 dark:text-white">
              {{ formatCurrency(state.overview.usedAmount) }}
            </div>
          </div>
        </div>
      </Card>

      <!-- 剩余金额 -->
      <Card padding="md" hoverable>
        <div class="flex items-center">
          <div class="mr-3 shrink-0">
            <BarChart3 :size="24" class="text-orange-500" />
          </div>
          <div class="flex-1">
            <div class="text-sm text-gray-600 dark:text-gray-400 mb-1">
              剩余金额
            </div>
            <div class="text-xl font-bold text-gray-900 dark:text-white">
              {{ formatCurrency(state.overview.remainingAmount) }}
            </div>
          </div>
        </div>
      </Card>

      <!-- 完成率 -->
      <Card padding="md" hoverable>
        <div class="flex items-center">
          <div class="w-6 h-6 flex items-center justify-center mr-3 shrink-0">
            <span class="text-lg">{{ statusIcon }}</span>
          </div>
          <div class="flex-1">
            <div class="text-sm text-gray-600 dark:text-gray-400 mb-1">
              完成率
            </div>
            <div class="text-xl font-bold" :class="statusColor">
              {{ formatPercentage(state.overview.completionRate) }}
            </div>
            <div class="text-xs mt-1" :class="statusColor">
              {{ statusText }}
            </div>
          </div>
        </div>
      </Card>

      <!-- 预算数量 -->
      <Card padding="md" hoverable>
        <div class="flex items-center">
          <div class="w-6 h-6 flex items-center justify-center mr-3 shrink-0">
            <span class="text-lg">📊</span>
          </div>
          <div class="flex-1">
            <div class="text-sm text-gray-600 dark:text-gray-400 mb-1">
              预算数量
            </div>
            <div class="text-xl font-bold text-gray-900 dark:text-white">
              {{ state.overview.budgetCount }}
            </div>
          </div>
        </div>
      </Card>

      <!-- 超预算数量 -->
      <Card v-if="state.overview.overBudgetCount > 0" padding="md" hoverable class="bg-red-50 dark:bg-red-900/20 border-red-200 dark:border-red-800">
        <div class="flex items-center">
          <div class="w-6 h-6 flex items-center justify-center mr-3 shrink-0">
            <span class="text-lg">!</span>
          </div>
          <div class="flex-1">
            <div class="text-sm text-gray-600 dark:text-gray-400 mb-1">
              超预算
            </div>
            <div class="text-xl font-bold text-red-600 dark:text-red-400">
              {{ state.overview.overBudgetCount }}
            </div>
            <div class="text-xs mt-1 text-red-600 dark:text-red-400">
              超预算金额: {{ formatCurrency(state.overview.overBudgetAmount) }}
            </div>
          </div>
        </div>
      </Card>
    </div>

    <!-- 筛选器 -->
    <Card v-if="showFilters" padding="lg">
      <div class="flex justify-between items-center mb-4">
        <h3 class="text-lg font-semibold text-gray-900 dark:text-white">
          筛选条件
        </h3>
        <button
          class="p-2 hover:bg-gray-100 dark:hover:bg-gray-700 rounded-lg transition-colors"
          @click="toggleFilters"
        >
          <X :size="20" class="text-gray-500 dark:text-gray-400" />
        </button>
      </div>
      <div class="space-y-4">
        <div class="flex flex-col sm:flex-row sm:items-center gap-2">
          <label class="text-sm font-medium text-gray-700 dark:text-gray-300 sm:w-24">
            基础货币
          </label>
          <select
            v-model="filters.baseCurrency"
            class="flex-1 px-3 py-2 text-sm rounded-lg border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
          >
            <option value="CNY">
              人民币 (CNY)
            </option>
            <option value="USD">
              美元 (USD)
            </option>
            <option value="EUR">
              欧元 (EUR)
            </option>
            <option value="JPY">
              日元 (JPY)
            </option>
          </select>
        </div>

        <div class="flex flex-col sm:flex-row sm:items-center gap-2">
          <label class="text-sm font-medium text-gray-700 dark:text-gray-300 sm:w-24">计算日期</label>
          <input
            v-model="filters.calculationDate"
            type="date"
            class="flex-1 px-3 py-2 text-sm rounded-lg border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
          >
        </div>

        <div class="flex items-center gap-2">
          <input
            v-model="filters.includeInactive"
            type="checkbox"
            class="w-4 h-4 text-blue-600 bg-gray-100 border-gray-300 rounded focus:ring-blue-500 dark:focus:ring-blue-600 dark:ring-offset-gray-800 focus:ring-2 dark:bg-gray-700 dark:border-gray-600"
          >
          <label class="text-sm text-gray-700 dark:text-gray-300">
            包含非激活预算
          </label>
        </div>

        <div class="flex flex-col gap-2">
          <label class="text-sm font-medium text-gray-700 dark:text-gray-300">时间范围</label>
          <div class="flex items-center gap-2">
            <input
              v-model="filters.timeRange.startDate"
              type="date"
              class="flex-1 px-3 py-2 text-sm rounded-lg border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
            >
            <span class="text-sm text-gray-500 dark:text-gray-400">至</span>
            <input
              v-model="filters.timeRange.endDate"
              type="date"
              class="flex-1 px-3 py-2 text-sm rounded-lg border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
            >
          </div>
        </div>

        <div class="flex flex-col sm:flex-row sm:items-center gap-2">
          <label class="text-sm font-medium text-gray-700 dark:text-gray-300 sm:w-24">时间维度</label>
          <select
            v-model="filters.period"
            class="flex-1 px-3 py-2 text-sm rounded-lg border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
          >
            <option value="month">
              按月
            </option>
            <option value="week">
              按周
            </option>
          </select>
        </div>

        <div class="flex gap-3 justify-end">
          <Button variant="secondary" @click="handleResetFilters">
            重置
          </Button>
          <Button variant="primary" @click="toggleFilters">
            应用
          </Button>
        </div>
      </div>
    </Card>

    <div v-if="state.error" class="flex items-center p-4 bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-lg">
      <AlertCircle :size="20" class="text-red-600 dark:text-red-400 mr-3" />
      <div class="text-sm text-red-600 dark:text-red-400">
        {{ state.error }}
      </div>
    </div>

    <!-- 图表区域 -->
    <Card v-if="hasData" padding="lg">
      <div class="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-4 mb-5">
        <h3 class="text-lg font-semibold text-gray-900 dark:text-white m-0">
          图表分析
        </h3>
        <div class="flex gap-2 flex-wrap">
          <button
            class="flex items-center justify-center px-3 py-2 min-w-10 min-h-10 rounded-lg border border-gray-300 dark:border-gray-600 text-gray-600 dark:text-gray-400 transition-all"
            :class="chartType === 'trend' ? 'bg-blue-500 border-blue-500 text-white' : 'bg-gray-100 dark:bg-gray-700 hover:bg-blue-100 dark:hover:bg-blue-900/30 hover:border-blue-500 hover:text-blue-600 dark:hover:text-blue-400'"
            title="趋势分析"
            @click="chartType = 'trend'"
          >
            <TrendingUp :size="16" />
          </button>
          <button
            class="flex items-center justify-center px-3 py-2 min-w-10 min-h-10 rounded-lg border border-gray-300 dark:border-gray-600 text-gray-600 dark:text-gray-400 transition-all"
            :class="chartType === 'category' ? 'bg-blue-500 border-blue-500 text-white' : 'bg-gray-100 dark:bg-gray-700 hover:bg-blue-100 dark:hover:bg-blue-900/30 hover:border-blue-500 hover:text-blue-600 dark:hover:text-blue-400'"
            title="分类分析"
            @click="chartType = 'category'"
          >
            <PieChart :size="16" />
          </button>
        </div>
      </div>

      <!-- 图表容器 -->
      <div class="w-full h-96 relative">
        <VChart
          v-if="!state.loading && hasData"
          ref="chartRef"
          :key="chartKey"
          :option="currentChartOption"
          class="w-full h-full"
          autoresize
          :loading="false"
          @finished="ensureChartRender"
        />
        <div v-else-if="state.loading" class="flex flex-col items-center justify-center h-full">
          <Spinner size="lg" />
          <div class="text-sm text-gray-500 dark:text-gray-400 mt-4">
            加载中...
          </div>
        </div>
        <div v-else class="flex items-center justify-center h-full text-gray-500 dark:text-gray-400">
          <div class="text-sm">
            暂无图表数据
          </div>
        </div>
      </div>
    </Card>
  </div>
</template>
