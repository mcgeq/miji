<script setup lang="ts">
import { computed, ref } from 'vue';
import VChart from 'vue-echarts';
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
  timeDimension: 'year' | 'month' | 'week';
  loading: boolean;
}

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
    title: {
      text: '收支趋势',
      left: 'center',
      subtext: `${props.timeDimension === 'week' ? '周度' : '月度'}趋势分析`,
    },
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

const categoryChartOption = computed(() => {
  const categories = props.topCategories.slice(0, 8).map(cat => cat.category);
  const amounts = props.topCategories.slice(0, 8).map(cat => cat.amount);
  const totalAmount = amounts.reduce((sum, amount) => sum + amount, 0);

  return {
    ...defaultTheme,
    title: {
      text: '分类统计',
      left: 'center',
      subtext: '支出分类占比',
    },
    tooltip: {
      trigger: 'item',
      formatter: (params: any) => {
        const percentage = ((params.value / totalAmount) * 100).toFixed(2);
        return `${params.name}<br/>金额: ¥${params.value.toFixed(2)}<br/>占比: ${percentage}%`;
      },
    },
    legend: {
      orient: 'vertical',
      left: 'left',
      top: 'middle',
      data: categories,
      itemWidth: 12,
      itemHeight: 12,
    },
    series: [
      {
        name: '支出分类',
        type: 'pie',
        radius: ['40%', '70%'],
        center: ['60%', '50%'],
        avoidLabelOverlap: false,
        itemStyle: {
          borderRadius: 8,
          borderColor: '#fff',
          borderWidth: 2,
        },
        label: {
          show: false,
          position: 'center',
        },
        emphasis: {
          label: {
            show: true,
            fontSize: '16',
            fontWeight: 'bold',
            formatter: '{b}\n{c}',
          },
          itemStyle: {
            shadowBlur: 10,
            shadowOffsetX: 0,
            shadowColor: 'rgba(0, 0, 0, 0.5)',
          },
        },
        labelLine: {
          show: false,
        },
        data: categories.map((category, index) => ({
          value: amounts[index],
          name: category,
          itemStyle: {
            color: chartUtils.getColor(index),
          },
        })),
        animationType: 'scale',
        animationEasing: 'elasticOut' as const,
        animationDelay: (_idx: number) => Math.random() * 200,
      },
    ],
  };
});

const categoryBarOption = computed(() => {
  const categories = props.topCategories.slice(0, 10).map(cat => cat.category);
  const amounts = props.topCategories.slice(0, 10).map(cat => cat.amount);
  const totalAmount = amounts.reduce((sum, amount) => sum + amount, 0);

  return {
    ...defaultTheme,
    title: {
      text: '分类支出排行',
      left: 'center',
      subtext: '支出金额排名',
    },
    tooltip: {
      trigger: 'axis',
      axisPointer: {
        type: 'shadow',
      },
      formatter: (params: any) => {
        const param = params[0];
        const percentage = ((param.value / totalAmount) * 100).toFixed(2);
        return `${param.name}<br/>金额: ¥${param.value.toFixed(2)}<br/>占比: ${percentage}%`;
      },
    },
    grid: {
      left: '3%',
      right: '4%',
      bottom: '3%',
      top: '20%',
      containLabel: true,
    },
    xAxis: {
      type: 'value',
      axisLabel: {
        formatter: chartUtils.formatAmount,
      },
      splitNumber: 4, // 设置合适的分割数
      minInterval: 1, // 设置最小间隔
    },
    yAxis: {
      type: 'category',
      data: categories,
      axisLabel: {
        formatter: (value: string) => {
          return value.length > 6 ? `${value.substring(0, 6)}...` : value;
        },
      },
    },
    series: [
      {
        name: '支出金额',
        type: 'bar',
        data: amounts.map((amount, index) => ({
          value: amount,
          itemStyle: {
            color: chartUtils.getColor(index),
          },
        })),
        barWidth: '60%',
        emphasis: {
          itemStyle: {
            shadowBlur: 10,
            shadowOffsetX: 0,
            shadowColor: 'rgba(0, 0, 0, 0.3)',
          },
        },
        animationDelay: (idx: number) => idx * 100,
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
  <div class="transaction-stats-charts">
    <div class="charts-grid">
      <!-- 收支趋势图 -->
      <div class="chart-card">
        <div class="chart-header">
          <h3 class="chart-title">
            收支趋势
          </h3>
          <div class="chart-subtitle">
            {{ timeDimension === 'week' ? '周度' : '月度' }}趋势分析
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
            :loading="chartLoading"
            class="chart"
            autoresize
          />
        </div>
      </div>

      <!-- 分类统计饼图 -->
      <div class="chart-card">
        <div class="chart-header">
          <h3 class="chart-title">
            分类统计
          </h3>
          <div class="chart-subtitle">
            支出分类占比
          </div>
        </div>

        <div class="chart-content">
          <div v-if="loading" class="chart-loading">
            <div class="loading-spinner" />
            <div class="loading-text">
              加载中...
            </div>
          </div>

          <div v-else-if="topCategories.length === 0" class="chart-empty">
            <div class="empty-icon">
              🥧
            </div>
            <div class="empty-text">
              暂无数据
            </div>
          </div>

          <VChart
            v-else
            :option="categoryChartOption"
            :loading="chartLoading"
            class="chart"
            autoresize
          />
        </div>
      </div>

      <!-- 分类支出排行 -->
      <div class="chart-card full-width">
        <div class="chart-header">
          <h3 class="chart-title">
            分类支出排行
          </h3>
          <div class="chart-subtitle">
            支出金额排名
          </div>
        </div>

        <div class="chart-content">
          <div v-if="loading" class="chart-loading">
            <div class="loading-spinner" />
            <div class="loading-text">
              加载中...
            </div>
          </div>

          <div v-else-if="topCategories.length === 0" class="chart-empty">
            <div class="empty-icon">
              📊
            </div>
            <div class="empty-text">
              暂无数据
            </div>
          </div>

          <VChart
            v-else
            :option="categoryBarOption"
            :loading="chartLoading"
            class="chart"
            autoresize
          />
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped lang="postcss">
.transaction-stats-charts {
  margin-bottom: 2rem;
}

.charts-grid {
  display: grid;
  grid-template-columns: 1fr;
  gap: 1.5rem;
}

@media (min-width: 1024px) {
  .charts-grid {
    grid-template-columns: 2fr 1fr;
  }
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
