<script setup lang="ts">
import { computed, ref } from 'vue';
import VChart from 'vue-echarts';
import { lowercaseFirstLetter } from '@/utils/common';
import { chartUtils, defaultTheme, initECharts } from '@/utils/echarts';

const props = defineProps<Props>();

const { t } = useI18n();

// 初始化ECharts
initECharts();

interface TopPaymentMethod {
  paymentMethod: string;
  amount: number;
  count: number;
  percentage: number;
}

interface Props {
  topPaymentMethods: TopPaymentMethod[];
  topIncomePaymentMethods?: TopPaymentMethod[];
  topTransferPaymentMethods?: TopPaymentMethod[];
  transactionType?: string;
  loading: boolean;
}

// 图表类型切换
const chartViewType = ref<'pie' | 'bar' | 'radar'>('pie');

// 支付渠道类型切换
const paymentMethodType = ref<'expense' | 'income' | 'transfer'>('expense');

// 监听transactionType变化，自动同步paymentMethodType
watch(() => props.transactionType, newTransactionType => {
  if (newTransactionType === 'Income') {
    paymentMethodType.value = 'income';
  } else if (newTransactionType === 'Transfer') {
    paymentMethodType.value = 'transfer';
  } else if (newTransactionType === 'Expense') {
    paymentMethodType.value = 'expense';
  } else {
    // 如果transactionType为空或'全部'，重置为默认值'支出'
    paymentMethodType.value = 'expense';
  }
}, { immediate: true });

// 根据支付渠道类型获取相应的支付渠道数据
const currentPaymentMethods = computed(() => {
  switch (paymentMethodType.value) {
    case 'income':
      return props.topIncomePaymentMethods || [];
    case 'transfer':
      return props.topTransferPaymentMethods || [];
    case 'expense':
    default:
      return props.topPaymentMethods;
  }
});

// 获取支付渠道类型的显示名称
const paymentMethodTypeName = computed(() => {
  switch (paymentMethodType.value) {
    case 'income':
      return '收入';
    case 'transfer':
      return '转账';
    case 'expense':
    default:
      return '支出';
  }
});

// 获取图表类型的显示名称
const chartViewTypeName = computed(() => {
  switch (chartViewType.value) {
    case 'pie':
      return '支付渠道占比';
    case 'bar':
      return '支付渠道排行';
    case 'radar':
      return '支付渠道雷达图';
    default:
      return '支付渠道占比';
  }
});

// 饼图配置
const pieChartOption = computed(() => {
  const paymentMethods = currentPaymentMethods.value.slice(0, 8).map(pm => pm.paymentMethod);
  const amounts = currentPaymentMethods.value.slice(0, 8).map(pm => pm.amount);
  const totalAmount = amounts.reduce((sum, amount) => sum + amount, 0);

  // 国际化支付渠道名称
  const internationalizedPaymentMethods = paymentMethods.map(paymentMethod =>
    t(`financial.paymentMethods.${paymentMethod.toLocaleLowerCase()}`),
  );

  return {
    ...defaultTheme,
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
      data: internationalizedPaymentMethods,
      itemWidth: 12,
      itemHeight: 12,
    },
    series: [
      {
        name: `${paymentMethodTypeName.value}金额`,
        type: 'pie',
        radius: ['40%', '70%'],
        center: ['60%', '50%'],
        data: amounts.map((amount, index) => ({
          value: amount,
          name: internationalizedPaymentMethods[index],
          itemStyle: {
            color: chartUtils.getColor(index),
          },
        })),
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

// 柱状图配置
const barChartOption = computed(() => {
  const paymentMethods = currentPaymentMethods.value.slice(0, 8).map(pm => pm.paymentMethod);
  const amounts = currentPaymentMethods.value.slice(0, 8).map(pm => pm.amount);
  const totalAmount = amounts.reduce((sum, amount) => sum + amount, 0);

  // 国际化支付渠道名称
  const internationalizedPaymentMethods = paymentMethods.map(paymentMethod =>
    t(`financial.paymentMethods.${lowercaseFirstLetter(paymentMethod)}`),
  );

  return {
    ...defaultTheme,
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
      splitNumber: 4,
      minInterval: 1,
    },
    yAxis: {
      type: 'category',
      data: internationalizedPaymentMethods,
      axisLabel: {
        formatter: (value: string) => {
          return value.length > 6 ? `${value.substring(0, 6)}...` : value;
        },
      },
    },
    series: [
      {
        name: `${paymentMethodTypeName.value}金额`,
        type: 'bar',
        data: amounts.map((amount, index) => ({
          value: amount,
          name: internationalizedPaymentMethods[index],
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

// 雷达图配置
const radarChartOption = computed(() => {
  const paymentMethods = currentPaymentMethods.value.slice(0, 6).map(pm => pm.paymentMethod);
  const amounts = currentPaymentMethods.value.slice(0, 6).map(pm => pm.amount);

  // 国际化支付渠道名称
  const internationalizedPaymentMethods = paymentMethods.map(paymentMethod =>
    t(`financial.paymentMethods.${lowercaseFirstLetter(paymentMethod)}`),
  );

  // 计算最大值，用于雷达图刻度
  const maxAmount = Math.max(...amounts);
  const adjustedMax = Math.ceil(maxAmount * 1.2);

  // 根据最大值调整分割数
  const getSplitNumber = (max: number) => {
    if (max >= 100000) {
      return 6;
    } else if (max >= 10000) {
      return 5;
    } else if (max >= 1000) {
      return 4;
    }
    return 4;
  };

  return {
    ...defaultTheme,
    silent: true,
    tooltip: {
      trigger: 'item',
      formatter: (params: any) => {
        return `${params.name}<br/>金额: ¥${params.value.toFixed(2)}`;
      },
    },
    legend: {
      data: [`${paymentMethodTypeName.value}分布`],
      top: 30,
    },
    radar: {
      indicator: internationalizedPaymentMethods.map(paymentMethod => ({
        name: paymentMethod,
        min: 0,
        max: adjustedMax,
      })),
      radius: '60%',
      splitNumber: getSplitNumber(adjustedMax),
      alignTicks: false,
      splitLine: {
        lineStyle: {
          color: '#e5e7eb',
        },
      },
      splitArea: {
        show: false,
      },
      axisName: {
        color: '#666',
        fontSize: 12,
      },
      axisLine: {
        show: true,
        lineStyle: {
          color: '#e5e7eb',
        },
      },
      axisTick: {
        show: false,
      },
      axisLabel: {
        show: true,
        color: '#666',
        fontSize: 10,
        formatter: (value: number) => {
          if (value >= 10000) {
            return `${(value / 10000).toFixed(1)}万`;
          } else if (value >= 1000) {
            return `${(value / 1000).toFixed(1)}k`;
          }
          return value.toString();
        },
      },
    },
    series: [
      {
        name: `${paymentMethodTypeName.value}分布`,
        type: 'radar',
        data: [
          {
            value: amounts,
            name: `${paymentMethodTypeName.value}分布`,
            itemStyle: {
              color: chartUtils.getColor(0),
            },
            areaStyle: {
              color: chartUtils.getColor(0),
              opacity: 0.3,
            },
          },
        ],
        animationDelay: 0,
      },
    ],
  };
});

// 当前图表配置
const currentChartOption = computed(() => {
  switch (chartViewType.value) {
    case 'pie':
      return pieChartOption.value;
    case 'bar':
      return barChartOption.value;
    case 'radar':
      return radarChartOption.value;
    default:
      return pieChartOption.value;
  }
});

// 图表加载状态
const chartLoading = ref(false);
</script>

<template>
  <div class="payment-method-charts-switcher">
    <div class="chart-card">
      <div class="chart-header">
        <h3 class="chart-title">
          {{ chartViewTypeName }}
        </h3>
        <div class="chart-controls">
          <!-- 图表类型切换按钮 -->
          <div class="view-type-buttons">
            <button
              class="view-type-btn" :class="[{ active: chartViewType === 'pie' }]"
              @click="chartViewType = 'pie'"
            >
              <span class="btn-icon">🥧</span>
              <span class="btn-text">占比</span>
            </button>
            <button
              class="view-type-btn" :class="[{ active: chartViewType === 'bar' }]"
              @click="chartViewType = 'bar'"
            >
              <span class="btn-icon">📊</span>
              <span class="btn-text">排行</span>
            </button>
            <button
              class="view-type-btn" :class="[{ active: chartViewType === 'radar' }]"
              @click="chartViewType = 'radar'"
            >
              <span class="btn-icon">🕸</span>
              <span class="btn-text">雷达</span>
            </button>
          </div>

          <!-- 支付渠道类型选择 -->
          <div class="control-group">
            <label class="control-label">交易类型:</label>
            <select
              v-model="paymentMethodType"
              class="control-select"
            >
              <option value="expense">
                支出
              </option>
              <option value="income">
                收入
              </option>
              <option value="transfer">
                转账
              </option>
            </select>
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

        <div v-else-if="currentPaymentMethods.length === 0" class="chart-empty">
          <div class="empty-icon">
            {{ chartViewType === 'pie' ? '🥧' : chartViewType === 'bar' ? '📊' : '🕸' }}
          </div>
          <div class="empty-text">
            暂无数据
          </div>
        </div>

        <VChart
          v-else
          :option="currentChartOption"
          :loading="chartLoading"
          class="chart"
          autoresize
        />
      </div>
    </div>
  </div>
</template>

<style scoped lang="postcss">
.payment-method-charts-switcher {
  margin-bottom: 2rem;
  width: 100%;
  box-sizing: border-box;
}

.chart-card {
  background: var(--color-base-100);
  border: 1px solid var(--color-base-300);
  border-radius: 0.5rem;
  padding: 1.5rem;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
  width: 100%;
  box-sizing: border-box;
  overflow: hidden;
}

.chart-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 1rem;
  flex-wrap: wrap;
  gap: 0.5rem;
}

.chart-title {
  font-size: 1.125rem;
  font-weight: 600;
  color: var(--color-accent-content);
  margin-bottom: 0.25rem;
  word-break: break-word;
}

.chart-controls {
  display: flex;
  gap: 1rem;
  align-items: center;
  flex-wrap: wrap;
}

.view-type-buttons {
  display: flex;
  gap: 0.5rem;
  background: var(--color-base-200);
  border-radius: 0.5rem;
  padding: 0.25rem;
}

.view-type-btn {
  display: flex;
  align-items: center;
  gap: 0.25rem;
  padding: 0.5rem 0.75rem;
  border: none;
  border-radius: 0.375rem;
  background: transparent;
  color: var(--color-neutral);
  font-size: 0.875rem;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s ease;
  white-space: nowrap;
}

.view-type-btn:hover {
  background: var(--color-base-300);
  color: var(--color-accent-content);
}

.view-type-btn.active {
  background: var(--color-primary);
  color: var(--color-primary-content);
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
}

.btn-icon {
  font-size: 1rem;
}

.btn-text {
  font-size: 0.75rem;
}

.control-group {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  flex-wrap: wrap;
}

.control-label {
  font-size: 0.875rem;
  color: var(--color-neutral);
  font-weight: 500;
  white-space: nowrap;
}

.control-select {
  padding: 0.375rem 0.75rem;
  border: 1px solid var(--color-base-300);
  border-radius: 0.375rem;
  background: var(--color-base-100);
  color: var(--color-accent-content);
  font-size: 0.875rem;
  min-width: 100px;
  max-width: 150px;
}

.control-select:focus {
  outline: none;
  border-color: var(--color-primary);
  box-shadow: 0 0 0 3px rgba(var(--color-primary-rgb), 0.1);
}

.chart-content {
  min-height: 400px;
  width: 100%;
  overflow: hidden;
}

.chart {
  width: 100%;
  height: 400px;
  max-width: 100%;
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

/* 移动端优化 */
@media (max-width: 768px) {
  .payment-method-charts-switcher {
    margin-bottom: 1rem;
  }

  .chart-card {
    padding: 1rem;
    margin: 0;
  }

  .chart-header {
    flex-direction: column;
    align-items: flex-start;
    gap: 0.75rem;
  }

  .chart-controls {
    width: 100%;
    justify-content: flex-start;
    flex-direction: column;
    align-items: flex-start;
    gap: 0.75rem;
  }

  .view-type-buttons {
    width: 100%;
    justify-content: center;
  }

  .control-group {
    width: 100%;
    justify-content: space-between;
  }

  .chart {
    height: 300px;
  }
}

/* 超小屏幕优化 */
@media (max-width: 480px) {
  .chart-card {
    padding: 0.75rem;
  }

  .chart-title {
    font-size: 1rem;
  }

  .view-type-btn {
    padding: 0.375rem 0.5rem;
    font-size: 0.75rem;
  }

  .btn-text {
    display: none;
  }

  .control-label {
    font-size: 0.75rem;
  }

  .control-select {
    font-size: 0.75rem;
    padding: 0.25rem 0.5rem;
  }

  .chart {
    height: 250px;
  }
}
</style>
