<script setup lang="ts">
import VChart from 'vue-echarts';
import Spinner from '@/components/ui/Spinner.vue';
import { chartUtils, defaultTheme, initECharts } from '@/utils/echarts';

const props = defineProps<Props>();

// 初始化ECharts
initECharts();

interface MonthlyTrend {
  month: string;
  income: number;
  expense: number;
}

interface WeeklyTrend {
  week: string;
  income: number;
  expense: number;
}

interface TopCategory {
  category: string;
  amount: number;
  count: number;
}

interface Props {
  monthlyTrends: MonthlyTrend[];
  weeklyTrends: WeeklyTrend[];
  topCategories: TopCategory[];
  topIncomeCategories?: TopCategory[];
  topTransferCategories?: TopCategory[];
  timeDimension: 'year' | 'month' | 'week';
  transactionType?: string;
  loading: boolean;
}

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

// 当前分类数据
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

// ECharts配置
const trendChartOption = computed(() => {
  const periods = currentTrends.value.map(trend => {
    if ('month' in trend) {
      return trend.month;
    } else {
      return trend.week;
    }
  });
  const incomeData = currentTrends.value.map(trend => trend.income);
  const expenseData = currentTrends.value.map(trend => trend.expense);

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
          result += `${param.marker}${param.seriesName}: ¥${param.value.toFixed(2)}<br/>`;
        });
        return result;
      },
    },
    legend: {
      data: ['收入', '支出'],
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
    series: [
      {
        name: '收入',
        type: 'bar',
        data: incomeData,
        itemStyle: {
          color: chartUtils.getColor(1),
        },
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
        type: 'bar',
        data: expenseData,
        itemStyle: {
          color: chartUtils.getColor(3),
        },
        emphasis: {
          itemStyle: {
            color: chartUtils.getColor(3),
            shadowBlur: 10,
            shadowColor: 'rgba(239, 68, 68, 0.3)',
          },
        },
        animationDelay: (idx: number) => idx * 100 + 50,
      },
    ],
    animation: true,
    animationDuration: 1000,
    animationEasing: 'cubicOut' as const,
  };
});

// 图表加载状态
const chartLoading = ref(false);
</script>

<template>
  <div class="mb-8 md:mb-8 w-full">
    <div class="grid grid-cols-1 gap-6 md:gap-6 w-full">
      <!-- 收支趋势图 -->
      <div class="bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg p-6 md:p-6 sm:p-4 shadow-sm w-full overflow-hidden">
        <div class="flex justify-between items-center mb-4 flex-wrap gap-2">
          <div>
            <h3 class="text-lg md:text-lg sm:text-base font-semibold text-gray-900 dark:text-white mb-1 break-words">
              收支趋势
            </h3>
            <div class="text-sm text-gray-500 dark:text-gray-400 break-words">
              {{ timeDimension === 'week' ? '周度' : timeDimension === 'year' ? '年度' : '月度' }}趋势分析
            </div>
          </div>
        </div>

        <div class="min-h-[400px] md:min-h-[300px] sm:min-h-[250px] w-full overflow-hidden">
          <div v-if="loading" class="flex flex-col items-center justify-center h-[400px] md:h-[300px] sm:h-[250px] gap-4">
            <Spinner size="lg" />
            <div class="text-gray-500 dark:text-gray-400 text-sm">
              加载中...
            </div>
          </div>

          <div v-else-if="currentTrends.length === 0" class="flex flex-col items-center justify-center h-[400px] md:h-[300px] sm:h-[250px] gap-4">
            <div class="text-5xl opacity-50">
              📊
            </div>
            <div class="text-gray-500 dark:text-gray-400 text-sm">
              暂无数据
            </div>
          </div>

          <VChart
            v-else
            :option="trendChartOption"
            :loading="chartLoading"
            class="w-full h-[400px] md:h-[300px] sm:h-[250px] max-w-full"
            autoresize
          />
        </div>
      </div>
    </div>
  </div>
</template>
