<script setup lang="ts">
import VChart from 'vue-echarts';
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
      outerBounds: true,
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
  <div class="advanced-charts">
    <div class="charts-grid">
      <!-- 趋势图控制面板 -->
      <div class="chart-card full-width">
        <div class="chart-header">
          <h3 class="chart-title">
            收支趋势分析
          </h3>
          <div class="chart-controls">
            <div class="control-group">
              <label class="control-label">图表类型:</label>
              <select v-model="chartType" class="control-select">
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
            <div class="control-group">
              <label class="control-label">
                <input v-model="showNetIncome" type="checkbox" class="control-checkbox">
                显示净收入
              </label>
            </div>
          </div>
        </div>

        <div class="chart-content">
          <div v-if="loading" class="chart-loading">
            <div class="loading-spinner" />
            <div class="loading-text">
              加载中...
            </div>
          </div>

          <div v-else-if="currentTrends.length === 0" class="chart-empty">
            <div class="empty-icon">
              📊
            </div>
            <div class="empty-text">
              暂无数据
            </div>
          </div>

          <VChart
            v-else
            :option="trendChartOption"
            class="chart"
            autoresize
          />
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped lang="postcss">
.advanced-charts {
  margin-bottom: 2rem;
}

.charts-grid {
  display: grid;
  grid-template-columns: 1fr;
  gap: 1.5rem;
}

.chart-card {
  background: var(--color-base-100);
  border: 1px solid var(--color-base-300);
  border-radius: 0.5rem;
  padding: 1.5rem;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
}

.chart-card.full-width {
  grid-column: 1 / -1;
}

.chart-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1rem;
}

.chart-title {
  font-size: 1.125rem;
  font-weight: 600;
  color: var(--color-accent-content);
  margin-bottom: 0.25rem;
}

.chart-subtitle {
  font-size: 0.875rem;
  color: var(--color-neutral);
}

.chart-controls {
  display: flex;
  gap: 1rem;
  align-items: center;
}

.control-group {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.control-label {
  font-size: 0.875rem;
  color: var(--color-neutral);
  display: flex;
  align-items: center;
  gap: 0.25rem;
}

.control-select {
  padding: 0.25rem 0.5rem;
  border: 1px solid var(--color-base-300);
  border-radius: 0.25rem;
  background: var(--color-base-100);
  color: var(--color-accent-content);
  font-size: 0.875rem;
}

.control-checkbox {
  margin: 0;
}

.chart-content {
  min-height: 400px;
}

.chart {
  width: 100%;
  height: 400px;
}

.chart-loading {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  height: 400px;
  gap: 1rem;
}

.loading-spinner {
  width: 40px;
  height: 40px;
  border: 3px solid var(--color-base-300);
  border-top: 3px solid var(--color-primary);
  border-radius: 50%;
  animation: spin 1s linear infinite;
}

@keyframes spin {
  0% { transform: rotate(0deg); }
  100% { transform: rotate(360deg); }
}

.loading-text {
  color: var(--color-neutral);
  font-size: 0.875rem;
}

.chart-empty {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  height: 400px;
  gap: 1rem;
}

.empty-icon {
  font-size: 3rem;
  opacity: 0.5;
}

.empty-text {
  color: var(--color-neutral);
  font-size: 0.875rem;
}

@media (max-width: 768px) {
  .chart-card {
    padding: 1rem;
  }

  .chart-controls {
    flex-direction: column;
    align-items: flex-start;
    gap: 0.5rem;
  }

  .chart-content {
    min-height: 300px;
  }

  .chart {
    height: 300px;
  }

  .chart-loading,
  .chart-empty {
    height: 300px;
  }
}
</style>
