<script setup lang="ts">
import { BarChart3 } from 'lucide-vue-next';
import VChart from 'vue-echarts';
import { Card, Spinner, Switch } from '@/components/ui';
import { chartUtils, defaultTheme, initECharts } from '@/utils/echarts';

const props = defineProps<Props>();

// 初始化ECharts
initECharts();

interface ChartData {
  month?: string;
  week?: string;
  income: number;
  expense: number;
  netIncome: number;
}

interface CategoryData {
  category: string;
  amount: number;
  count: number;
  percentage: number;
}

interface Props {
  monthlyTrends: ChartData[];
  weeklyTrends: ChartData[];
  topCategories: CategoryData[];
  topIncomeCategories?: CategoryData[];
  topTransferCategories?: CategoryData[];
  timeDimension: 'year' | 'month' | 'week';
  transactionType?: string;
  loading: boolean;
}

// 图表类型切换
const chartType = ref<'bar' | 'line' | 'area'>('bar');
const showNetIncome = ref(true);

// 分类类型切换
const categoryType = ref<'expense' | 'income' | 'transfer'>('expense');

// 监听transactionType变化，自动同步categoryType
watch(() => props.transactionType, newTransactionType => {
  if (newTransactionType === 'Income') {
    categoryType.value = 'income';
  } else if (newTransactionType === 'Transfer') {
    categoryType.value = 'transfer';
  } else if (newTransactionType === 'Expense') {
    categoryType.value = 'expense';
  } else {
    // 如果transactionType为空或'全部'，重置为默认值'支出'
    categoryType.value = 'expense';
  }
}, { immediate: true });

// 计算属性
const currentTrends = computed(() => {
  switch (props.timeDimension) {
    case 'week':
      return props.weeklyTrends;
    case 'month':
    case 'year':
    default:
      return props.monthlyTrends;
  }
});

// 根据分类类型获取相应的分类数据
// const currentCategories = computed(() => {
//   switch (categoryType.value) {
//     case 'income':
//       return props.topIncomeCategories || [];
//     case 'transfer':
//       return props.topTransferCategories || [];
//     case 'expense':
//     default:
//       return props.topCategories;
//   }
// });
//
// // 获取分类类型的显示名称
// const categoryTypeName = computed(() => {
//   switch (categoryType.value) {
//     case 'income':
//       return '收入';
//     case 'transfer':
//       return '转账';
//     case 'expense':
//     default:
//       return '支出';
//   }
// });

// 趋势图配置
const trendChartOption = computed(() => {
  const periods = currentTrends.value.map(trend => trend.month || trend.week || '');
  const incomeData = currentTrends.value.map(trend => trend.income);
  const expenseData = currentTrends.value.map(trend => trend.expense);
  const netIncomeData = currentTrends.value.map(trend => trend.netIncome);

  const series = [
    {
      name: '收入',
      type: chartType.value === 'area' ? 'line' : chartType.value,
      data: incomeData,
      smooth: true, // 添加平滑曲线
      symbol: 'circle', // 确保显示数据点
      symbolSize: 6, // 数据点大小
      lineStyle: {
        width: 2,
        color: chartUtils.getColor(1),
      },
      itemStyle: {
        color: chartUtils.getColor(1),
      },
      areaStyle: chartType.value === 'area'
        ? {
            color: {
              type: 'linear',
              x: 0,
              y: 0,
              x2: 0,
              y2: 1,
              colorStops: [
                { offset: 0, color: chartUtils.getColor(1) },
                { offset: 1, color: `${chartUtils.getColor(1)}20` },
              ],
            },
          }
        : undefined,
      emphasis: {
        itemStyle: {
          color: chartUtils.getColor(1),
          shadowBlur: 10,
          shadowColor: 'rgba(16, 185, 129, 0.3)',
        },
      },
      animationDelay: (idx: number) => idx * 100,
    },
    {
      name: '支出',
      type: chartType.value === 'area' ? 'line' : chartType.value,
      data: expenseData,
      smooth: true, // 添加平滑曲线
      symbol: 'circle', // 确保显示数据点
      symbolSize: 6, // 数据点大小
      lineStyle: {
        width: 2,
        color: chartUtils.getColor(3),
      },
      itemStyle: {
        color: chartUtils.getColor(3),
      },
      areaStyle: chartType.value === 'area'
        ? {
            color: {
              type: 'linear',
              x: 0,
              y: 0,
              x2: 0,
              y2: 1,
              colorStops: [
                { offset: 0, color: chartUtils.getColor(3) },
                { offset: 1, color: `${chartUtils.getColor(3)}20` },
              ],
            },
          }
        : undefined,
      emphasis: {
        itemStyle: {
          color: chartUtils.getColor(3),
          shadowBlur: 10,
          shadowColor: 'rgba(239, 68, 68, 0.3)',
        },
      },
      animationDelay: (idx: number) => idx * 100 + 50,
    },
  ];

  if (showNetIncome.value) {
    series.push({
      name: '净收入',
      type: 'line',
      data: netIncomeData,
      smooth: true, // 添加平滑曲线
      symbol: 'circle', // 确保显示数据点
      symbolSize: 6, // 数据点大小
      lineStyle: {
        width: 2,
        color: chartUtils.getColor(0),
      },
      itemStyle: {
        color: chartUtils.getColor(0),
      },
      areaStyle: chartType.value === 'area'
        ? {
            color: {
              type: 'linear',
              x: 0,
              y: 0,
              x2: 0,
              y2: 1,
              colorStops: [
                { offset: 0, color: chartUtils.getColor(0) },
                { offset: 1, color: `${chartUtils.getColor(0)}20` },
              ],
            },
          }
        : undefined,
      emphasis: {
        itemStyle: {
          color: chartUtils.getColor(0),
          shadowBlur: 10,
          shadowColor: 'rgba(59, 130, 246, 0.3)',
        },
      },
      animationDelay: (_idx: number) => 100,
    });
  }

  return {
    ...defaultTheme,
    tooltip: {
      trigger: 'axis',
      axisPointer: {
        type: 'cross',
        crossStyle: {
          color: '#999',
        },
      },
      formatter: (params: any) => {
        let result = `${params[0].axisValue}<br/>`;
        params.forEach((param: any) => {
          const value = param.value >= 0 ? `+¥${param.value.toFixed(2)}` : `-¥${Math.abs(param.value).toFixed(2)}`;
          result += `${param.marker}${param.seriesName}: ${value}<br/>`;
        });
        return result;
      },
    },
    legend: {
      data: showNetIncome.value ? ['收入', '支出', '净收入'] : ['收入', '支出'],
      top: 30,
    },
    grid: {
      left: '3%',
      right: '4%',
      bottom: '3%',
      top: '20%',
      containLabel: true,
    },
    xAxis: {
      type: 'category',
      data: periods,
      axisPointer: {
        type: 'shadow',
      },
    },
    yAxis: {
      type: 'value',
      axisLabel: {
        formatter: chartUtils.formatAmount,
      },
      splitNumber: 4, // 设置合适的分割数
      minInterval: 1, // 设置最小间隔
    },
    series,
    animation: true,
    animationDuration: 1000,
    animationEasing: 'cubicOut' as const,
  };
});
</script>

<template>
  <div class="mb-8">
    <Card shadow="md" padding="lg">
      <!-- 图表头部 -->
      <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4 mb-6">
        <h3 class="text-lg font-semibold text-gray-900 dark:text-white">
          收支趋势分析
        </h3>

        <!-- 控制面板 -->
        <div class="flex flex-col sm:flex-row gap-4 items-start sm:items-center">
          <!-- 图表类型选择 -->
          <div class="flex items-center gap-2">
            <label class="text-sm text-gray-600 dark:text-gray-400">图表类型:</label>
            <select
              v-model="chartType"
              class="px-3 py-1.5 text-sm rounded-lg border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
            >
              <option value="bar">
                柱状图
              </option>
              <option value="line">
                折线图
              </option>
              <option value="area">
                面积图
              </option>
            </select>
          </div>

          <!-- 净收入开关 -->
          <Switch
            v-model="showNetIncome"
            label="显示净收入"
          />
        </div>
      </div>

      <!-- 图表内容 -->
      <div class="min-h-[300px] sm:min-h-[400px]">
        <!-- 加载状态 -->
        <div v-if="loading" class="flex flex-col items-center justify-center h-[300px] sm:h-[400px] gap-4">
          <Spinner size="lg" />
          <div class="text-sm text-gray-500 dark:text-gray-400">
            加载中...
          </div>
        </div>

        <!-- 空状态 -->
        <div v-else-if="currentTrends.length === 0" class="flex flex-col items-center justify-center h-[300px] sm:h-[400px] gap-4">
          <BarChart3 :size="48" class="text-gray-400 dark:text-gray-500 opacity-50" />
          <div class="text-sm text-gray-500 dark:text-gray-400">
            暂无数据
          </div>
        </div>

        <!-- 图表 -->
        <VChart
          v-else
          :option="trendChartOption"
          class="w-full h-[300px] sm:h-[400px]"
          autoresize
        />
      </div>
    </Card>
  </div>
</template>
