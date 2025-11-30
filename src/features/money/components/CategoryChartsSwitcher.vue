<script setup lang="ts">
import { computed, ref } from 'vue';
import VChart from 'vue-echarts';
import { Card, Spinner } from '@/components/ui';
import { lowercaseFirstLetter } from '@/utils/string';
import { chartUtils, defaultTheme, initECharts } from '@/utils/echarts';

const props = defineProps<Props>();

const { t } = useI18n();

// 初始化ECharts
initECharts();

interface TopCategory {
  category: string;
  amount: number;
  count: number;
  percentage: number;
}

interface Props {
  topCategories: TopCategory[];
  topIncomeCategories?: TopCategory[];
  topTransferCategories?: TopCategory[];
  transactionType?: string;
  loading: boolean;
}

// 图表类型切换
const chartViewType = ref<'pie' | 'bar' | 'radar'>('pie');

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

// 根据分类类型获取相应的分类数据
const currentCategories = computed(() => {
  switch (categoryType.value) {
    case 'income':
      return props.topIncomeCategories || [];
    case 'transfer':
      return props.topTransferCategories || [];
    case 'expense':
    default:
      return props.topCategories;
  }
});

// 获取分类类型的显示名称
const categoryTypeName = computed(() => {
  switch (categoryType.value) {
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
      return '分类占比';
    case 'bar':
      return '分类排行';
    case 'radar':
      return '分类雷达图';
    default:
      return '分类占比';
  }
});

// 饼图配置
const pieChartOption = computed(() => {
  const categories = currentCategories.value.slice(0, 8).map(cat => cat.category);
  const amounts = currentCategories.value.slice(0, 8).map(cat => cat.amount);
  const totalAmount = amounts.reduce((sum, amount) => sum + amount, 0);

  // 国际化分类名称
  const internationalizedCategories = categories.map(category =>
    t(`common.categories.${lowercaseFirstLetter(category)}`),
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
      data: internationalizedCategories,
      itemWidth: 12,
      itemHeight: 12,
    },
    series: [
      {
        name: `${categoryTypeName.value}分类`,
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
        data: categories.map((_category, index) => ({
          value: amounts[index],
          name: internationalizedCategories[index],
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

// 条形图配置
const barChartOption = computed(() => {
  const categories = currentCategories.value.slice(0, 10).map(cat => cat.category);
  const amounts = currentCategories.value.slice(0, 10).map(cat => cat.amount);
  const totalAmount = amounts.reduce((sum, amount) => sum + amount, 0);

  // 国际化分类名称
  const internationalizedCategories = categories.map(category =>
    t(`common.categories.${lowercaseFirstLetter(category)}`),
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
      data: internationalizedCategories,
      axisLabel: {
        formatter: (value: string) => {
          return value.length > 6 ? `${value.substring(0, 6)}...` : value;
        },
      },
    },
    series: [
      {
        name: `${categoryTypeName.value}金额`,
        type: 'bar',
        data: amounts.map((amount, index) => ({
          value: amount,
          name: internationalizedCategories[index],
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
  const categories = currentCategories.value.slice(0, 6).map(cat => cat.category);
  const amounts = currentCategories.value.slice(0, 6).map(cat => cat.amount);

  // 国际化分类名称
  const internationalizedCategories = categories.map(category =>
    t(`common.categories.${lowercaseFirstLetter(category)}`),
  );
  const maxAmount = Math.max(...amounts);

  // 计算合适的最大值，确保ticks可读且数值整洁
  const calculateMax = (value: number) => {
    if (value <= 0) return 100;
    if (value <= 50) return 100;
    if (value <= 100) return 150;
    if (value <= 200) return 250;
    if (value <= 500) return 600;
    if (value <= 1000) return 1200;
    if (value <= 5000) return Math.ceil(value * 1.2);
    if (value <= 10000) return Math.ceil(value * 1.1);
    if (value <= 50000) return Math.ceil(value * 1.05);
    return Math.ceil(value * 1.02);
  };

  // 计算整洁的最大值，避免长小数
  const getCleanMax = (value: number) => {
    const calculatedMax = calculateMax(value);

    // 如果是整数，直接返回
    if (calculatedMax % 1 === 0) {
      return calculatedMax;
    }

    // 否则向上取整到最近的整数
    return Math.ceil(calculatedMax);
  };

  const adjustedMax = getCleanMax(maxAmount);

  // 根据最大值动态设置splitNumber，确保刻度可读且数值整洁
  const getSplitNumber = (max: number) => {
    // 选择能够产生整洁刻度值的分割数
    if (max <= 100) return 5; // 0, 20, 40, 60, 80, 100
    if (max <= 200) return 4; // 0, 50, 100, 150, 200
    if (max <= 300) return 3; // 0, 100, 200, 300
    if (max <= 500) return 4; // 0, 125, 250, 375, 500
    if (max <= 600) return 3; // 0, 200, 400, 600
    if (max <= 1000) return 4; // 0, 250, 500, 750, 1000
    if (max <= 2000) return 4; // 0, 500, 1000, 1500, 2000
    if (max <= 5000) return 5; // 0, 1000, 2000, 3000, 4000, 5000
    if (max <= 10000) return 4; // 0, 2500, 5000, 7500, 10000
    if (max <= 20000) return 4; // 0, 5000, 10000, 15000, 20000
    if (max <= 50000) return 5; // 0, 10000, 20000, 30000, 40000, 50000
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
      show: false,
    },
    radar: {
      indicator: internationalizedCategories.map(category => ({
        name: category,
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
          } else if (roundedValue >= 1000) {
            return `${(roundedValue / 1000).toFixed(1)}k`;
          } else if (roundedValue >= 100) {
            return `${roundedValue}`;
          } else if (roundedValue >= 10) {
            return `${roundedValue}`;
          } else {
            return `${roundedValue}`;
          }
        },
      },
    },
    series: [
      {
        name: `${categoryTypeName.value}分布`,
        type: 'radar',
        data: [
          {
            value: amounts,
            name: `${categoryTypeName.value}分布`,
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
    <Card shadow="md" padding="lg">
      <!-- 图表头部 -->
      <div class="flex flex-col sm:flex-row justify-between items-start sm:items-center gap-2 sm:gap-4 mb-4">
        <h3 class="text-base sm:text-lg font-semibold text-gray-900 dark:text-white break-words">
          {{ chartViewTypeName }}
        </h3>

        <!-- 控制面板 -->
        <div class="flex flex-col sm:flex-row gap-3 sm:gap-4 items-start sm:items-center w-full sm:w-auto">
          <!-- 图表类型切换按钮 -->
          <div class="flex gap-2 bg-gray-100 dark:bg-gray-800 rounded-lg p-1 w-full sm:w-auto">
            <button
              class="flex items-center gap-1 px-3 py-2 rounded-md border-none transition-all text-sm font-medium whitespace-nowrap flex-1 sm:flex-initial justify-center"
              :class="chartViewType === 'pie' ? 'bg-blue-500 text-white shadow-sm' : 'bg-transparent text-gray-600 dark:text-gray-400 hover:bg-gray-200 dark:hover:bg-gray-700'"
              @click="chartViewType = 'pie'"
            >
              <span class="text-base">🥧</span>
              <span class="text-xs">占比</span>
            </button>
            <button
              class="flex items-center gap-1 px-3 py-2 rounded-md border-none transition-all text-sm font-medium whitespace-nowrap flex-1 sm:flex-initial justify-center"
              :class="chartViewType === 'bar' ? 'bg-blue-500 text-white shadow-sm' : 'bg-transparent text-gray-600 dark:text-gray-400 hover:bg-gray-200 dark:hover:bg-gray-700'"
              @click="chartViewType = 'bar'"
            >
              <span class="text-base">📊</span>
              <span class="text-xs">排行</span>
            </button>
            <button
              class="flex items-center gap-1 px-3 py-2 rounded-md border-none transition-all text-sm font-medium whitespace-nowrap flex-1 sm:flex-initial justify-center"
              :class="chartViewType === 'radar' ? 'bg-blue-500 text-white shadow-sm' : 'bg-transparent text-gray-600 dark:text-gray-400 hover:bg-gray-200 dark:hover:bg-gray-700'"
              @click="chartViewType = 'radar'"
            >
              <span class="text-base">🕸</span>
              <span class="text-xs">雷达</span>
            </button>
          </div>

          <!-- 分类类型选择 -->
          <div class="flex flex-col sm:flex-row items-start sm:items-center gap-2 w-full sm:w-auto">
            <label class="text-sm font-medium text-gray-600 dark:text-gray-400 whitespace-nowrap">交易类型:</label>
            <select
              v-model="categoryType"
              class="px-3 py-1.5 text-sm rounded-lg border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all min-w-[100px] max-w-[150px] sm:max-w-[150px] w-full sm:w-auto"
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

      <!-- 图表内容 -->
      <div class="min-h-[250px] sm:min-h-[300px] md:min-h-[400px] w-full overflow-hidden">
        <!-- 加载状态 -->
        <div v-if="loading" class="flex flex-col items-center justify-center h-[250px] sm:h-[300px] md:h-[400px] gap-4">
          <Spinner size="lg" />
          <div class="text-sm text-gray-500 dark:text-gray-400">
            加载中...
          </div>
        </div>

        <!-- 空状态 -->
        <div v-else-if="currentCategories.length === 0" class="flex flex-col items-center justify-center h-[250px] sm:h-[300px] md:h-[400px] gap-4">
          <div class="text-5xl opacity-50">
            {{ chartViewType === 'pie' ? '🥧' : chartViewType === 'bar' ? '📊' : '🕸' }}
          </div>
          <div class="text-sm text-gray-500 dark:text-gray-400">
            暂无数据
          </div>
        </div>

        <!-- 图表 -->
        <VChart
          v-else
          :option="currentChartOption"
          :loading="chartLoading"
          class="w-full h-[250px] sm:h-[300px] md:h-[400px] max-w-full"
          autoresize
        />
      </div>
    </Card>
  </div>
</template>
