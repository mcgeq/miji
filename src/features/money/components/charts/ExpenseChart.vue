<script setup lang="ts">
import { LucidePieChart } from 'lucide-vue-next';

// 简化的支出分析图表组件
interface ExpenseData {
  category: string;
  amount: number;
  color?: string;
}

interface Props {
  data: ExpenseData[];
  title?: string;
  height?: string;
}

const props = withDefaults(defineProps<Props>(), {
  title: '支出分析',
  height: '300px',
});

// 计算总金额
const totalAmount = computed(() =>
  props.data.reduce((sum, item) => sum + item.amount, 0),
);

// 计算百分比
const chartData = computed(() =>
  props.data.map(item => ({
    ...item,
    percentage: totalAmount.value > 0 ? (item.amount / totalAmount.value) * 100 : 0,
  })),
);

// 预设颜色
const defaultColors = [
  '#3b82f6',
  '#10b981',
  '#f59e0b',
  '#ef4444',
  '#8b5cf6',
  '#06b6d4',
  '#84cc16',
  '#f97316',
];

// 格式化金额
function formatAmount(amount: number): string {
  return amount.toFixed(2);
}
</script>

<template>
  <div :style="{ height }">
    <h4 v-if="title" class="text-base font-semibold text-gray-900 dark:text-white mb-4 text-center">
      {{ title }}
    </h4>

    <div class="flex flex-col sm:flex-row items-center gap-8 sm:gap-8" :class="{ 'h-[calc(100%-3rem)]': title }">
      <!-- 饼图可视化 -->
      <div class="flex-shrink-0 w-[200px] h-[200px]">
        <svg viewBox="0 0 200 200" class="w-full h-full">
          <g transform="translate(100,100)">
            <circle
              v-for="(item, index) in chartData"
              :key="item.category"
              :r="80"
              :stroke="item.color || defaultColors[index % defaultColors.length]"
              :stroke-width="20"
              :stroke-dasharray="`${item.percentage * 5.03} 502`"
              :stroke-dashoffset="`${-chartData.slice(0, index).reduce((sum, prev) => sum + prev.percentage, 0) * 5.03}`"
              fill="none"
              class="transition-all duration-300 hover:stroke-[25]"
            />
          </g>

          <!-- 中心文字 -->
          <text x="100" y="95" text-anchor="middle" class="text-xs fill-gray-500 dark:fill-gray-400">总支出</text>
          <text x="100" y="115" text-anchor="middle" class="text-sm font-semibold fill-gray-900 dark:fill-white">
            ¥{{ formatAmount(totalAmount) }}
          </text>
        </svg>
      </div>

      <!-- 图例 -->
      <div class="flex-1 flex flex-col gap-3 max-h-[200px] sm:max-h-[200px] overflow-y-auto">
        <div
          v-for="(item, index) in chartData"
          :key="item.category"
          class="flex items-center gap-3 p-2 rounded-md transition-colors hover:bg-gray-50 dark:hover:bg-gray-700"
        >
          <div
            class="w-4 h-4 rounded flex-shrink-0"
            :style="{ backgroundColor: item.color || defaultColors[index % defaultColors.length] }"
          />
          <div class="flex-1">
            <div class="text-sm font-medium text-gray-700 dark:text-gray-200 mb-0.5">
              {{ item.category }}
            </div>
            <div class="text-xs text-gray-600 dark:text-gray-400">
              ¥{{ formatAmount(item.amount) }}
              <span class="text-gray-400 dark:text-gray-500">({{ item.percentage.toFixed(1) }}%)</span>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- 空状态 -->
    <div v-if="data.length === 0" class="flex flex-col items-center justify-center h-full text-gray-400 dark:text-gray-500">
      <LucidePieChart class="w-8 h-8 mb-2" />
      <p class="text-sm">
        暂无数据
      </p>
    </div>
  </div>
</template>
