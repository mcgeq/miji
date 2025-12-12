<script setup lang="ts">
  import VChart from 'vue-echarts';
  import { Card, Spinner } from '@/components/ui';
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
  watch(
    () => props.transactionType,
    newTransactionType => {
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
    },
    { immediate: true },
  );

  // 根据支付渠道类型获取相应的支付渠道数据
  const currentPaymentMethods = computed(() => {
    switch (paymentMethodType.value) {
      case 'income':
        return props.topIncomePaymentMethods || [];
      case 'transfer':
        return props.topTransferPaymentMethods || [];
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

  // ECharts tooltip formatter type
  interface TooltipFormatterParams {
    name: string;
    value: number;
    seriesName?: string;
    componentType?: string;
  }

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
        formatter: (params: TooltipFormatterParams) => {
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
          name: `${paymentMethodTypeName.value}支付渠道`,
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
              shadowColor: 'var(--shadow-lg)',
            },
          },
          labelLine: {
            show: false,
          },
          data: paymentMethods.map((_paymentMethod, index) => ({
            value: amounts[index],
            name: internationalizedPaymentMethods[index],
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

  // 柱状图配置
  const barChartOption = computed(() => {
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
        trigger: 'axis',
        axisPointer: {
          type: 'shadow',
        },
        formatter: (params: TooltipFormatterParams[]) => {
          const param = params[0];
          const percentage = ((param.value / totalAmount) * 100).toFixed(2);
          return `${param.name}<br/>金额: ¥${param.value.toFixed(2)}<br/>占比: ${percentage}%`;
        },
      },
      legend: {
        show: false,
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
              shadowColor: 'var(--shadow-md)',
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
      t(`financial.paymentMethods.${paymentMethod.toLocaleLowerCase()}`),
    );

    const maxAmount = Math.max(...amounts);

    // Max value lookup table for chart scaling
    const maxValueRanges = [
      { threshold: 0, max: 100 },
      { threshold: 50, max: 100 },
      { threshold: 100, max: 150 },
      { threshold: 200, max: 250 },
      { threshold: 500, max: 600 },
      { threshold: 1000, max: 1200 },
      { threshold: 5000, multiplier: 1.2 },
      { threshold: 10000, multiplier: 1.1 },
      { threshold: 50000, multiplier: 1.05 },
      { threshold: Number.POSITIVE_INFINITY, multiplier: 1.02 },
    ];

    // Calculate appropriate max value for chart
    const calculateMax = (value: number): number => {
      const range = maxValueRanges.find(r => value <= r.threshold);
      if (!range) return Math.ceil(value * 1.02);
      return range.max ?? Math.ceil(value * (range.multiplier ?? 1));
    };

    const adjustedMax = Math.ceil(calculateMax(maxAmount));

    // Split number lookup table for readable ticks
    const splitNumberRanges = [
      { threshold: 100, splits: 5 },
      { threshold: 200, splits: 4 },
      { threshold: 300, splits: 3 },
      { threshold: 500, splits: 4 },
      { threshold: 600, splits: 3 },
      { threshold: 1000, splits: 4 },
      { threshold: 2000, splits: 4 },
      { threshold: 5000, splits: 5 },
      { threshold: 10000, splits: 4 },
      { threshold: 20000, splits: 4 },
      { threshold: 50000, splits: 5 },
      { threshold: Number.POSITIVE_INFINITY, splits: 4 },
    ];

    const getSplitNumber = (max: number): number => {
      const range = splitNumberRanges.find(r => max <= r.threshold);
      return range?.splits ?? 4;
    };

    return {
      ...defaultTheme,
      silent: true,
      tooltip: {
        trigger: 'item',
        formatter: (params: TooltipFormatterParams) => {
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
            // 确保显示整洁的数值
            const roundedValue = Math.round(value);
            if (roundedValue >= 10000) {
              return `${(roundedValue / 10000).toFixed(1)}万`;
            }
            if (roundedValue >= 1000) {
              return `${(roundedValue / 1000).toFixed(1)}k`;
            }
            if (roundedValue >= 100) {
              return `${roundedValue}`;
            }
            if (roundedValue >= 10) {
              return `${roundedValue}`;
            }
            return `${roundedValue}`;
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
  <div class="mb-8 w-full">
    <Card padding="lg" class="overflow-hidden">
      <div
        class="flex flex-col lg:flex-row justify-between items-start lg:items-center mb-4 gap-3 flex-wrap"
      >
        <h3 class="text-lg font-semibold text-gray-900 dark:text-white wrap-break-words">
          {{ chartViewTypeName }}
        </h3>
        <div class="flex gap-4 items-center flex-wrap w-full lg:w-auto">
          <!-- 图表类型切换按钮 -->
          <div
            class="flex gap-2 bg-gray-200 dark:bg-gray-800 rounded-lg p-1 w-full lg:w-auto justify-center"
          >
            <button
              class="flex items-center gap-1 px-3 py-2 rounded-md bg-transparent text-gray-600 dark:text-gray-400 text-sm font-medium cursor-pointer transition-all whitespace-nowrap hover:bg-gray-300 dark:hover:bg-gray-700 hover:text-gray-900 dark:hover:text-white"
              :class="chartViewType === 'pie' ? 'bg-blue-600 text-white! shadow-sm' : ''"
              @click="chartViewType = 'pie'"
            >
              <span class="text-base">🥧</span>
              <span class="text-xs hidden sm:inline">占比</span>
            </button>
            <button
              class="flex items-center gap-1 px-3 py-2 rounded-md bg-transparent text-gray-600 dark:text-gray-400 text-sm font-medium cursor-pointer transition-all whitespace-nowrap hover:bg-gray-300 dark:hover:bg-gray-700 hover:text-gray-900 dark:hover:text-white"
              :class="chartViewType === 'bar' ? 'bg-blue-600 text-white! shadow-sm' : ''"
              @click="chartViewType = 'bar'"
            >
              <span class="text-base">📊</span>
              <span class="text-xs hidden sm:inline">排行</span>
            </button>
            <button
              class="flex items-center gap-1 px-3 py-2 rounded-md bg-transparent text-gray-600 dark:text-gray-400 text-sm font-medium cursor-pointer transition-all whitespace-nowrap hover:bg-gray-300 dark:hover:bg-gray-700 hover:text-gray-900 dark:hover:text-white"
              :class="chartViewType === 'radar' ? 'bg-blue-600 text-white! shadow-sm' : ''"
              @click="chartViewType = 'radar'"
            >
              <span class="text-base">🕸</span>
              <span class="text-xs hidden sm:inline">雷达</span>
            </button>
          </div>

          <!-- 支付渠道类型选择 -->
          <div
            class="flex items-center gap-2 flex-wrap w-full lg:w-auto justify-between lg:justify-start"
          >
            <label class="text-sm text-gray-600 dark:text-gray-400 font-medium whitespace-nowrap">
              交易类型:
            </label>
            <select
              v-model="paymentMethodType"
              class="px-3 py-1.5 border border-gray-300 dark:border-gray-600 rounded-md bg-white dark:bg-gray-800 text-gray-900 dark:text-white text-sm min-w-[100px] max-w-[150px] focus:outline-none focus:border-blue-500 dark:focus:border-blue-600 focus:ring-2 focus:ring-blue-500/20 dark:focus:ring-blue-600/20"
            >
              <option value="expense">支出</option>
              <option value="income">收入</option>
              <option value="transfer">转账</option>
            </select>
          </div>
        </div>
      </div>

      <div class="min-h-[400px] sm:min-h-[300px] lg:min-h-[400px] w-full overflow-hidden">
        <div
          v-if="loading"
          class="flex flex-col items-center justify-center h-[400px] sm:h-[300px] lg:h-[400px] gap-4"
        >
          <Spinner size="lg" />
          <div class="text-gray-600 dark:text-gray-400 text-sm">加载中...</div>
        </div>

        <div
          v-else-if="currentPaymentMethods.length === 0"
          class="flex flex-col items-center justify-center h-[400px] sm:h-[300px] lg:h-[400px] gap-4"
        >
          <div class="text-5xl opacity-50">
            {{ chartViewType === 'pie' ? '🥧' : chartViewType === 'bar' ? '📊' : '🕸' }}
          </div>
          <div class="text-gray-600 dark:text-gray-400 text-sm">暂无数据</div>
        </div>

        <VChart
          v-else
          :option="currentChartOption"
          :loading="chartLoading"
          class="w-full h-[400px] sm:h-[300px] lg:h-[400px] max-w-full"
          autoresize
        />
      </div>
    </Card>
  </div>
</template>
