<script setup lang="ts">
import { LucideBarChart3 } from 'lucide-vue-next';

// 成员贡献度图表组件
interface MemberData {
  name: string;
  totalPaid: number;
  totalOwed: number;
  netBalance: number;
  color?: string;
}

interface Props {
  data: MemberData[];
  title?: string;
  height?: string;
}

const props = withDefaults(defineProps<Props>(), {
  title: '成员贡献度',
  height: '400px',
});

// 计算总支付金额
const totalPaid = computed(() =>
  props.data.reduce((sum, member) => sum + member.totalPaid, 0),
);

// 计算图表数据
const chartData = computed(() =>
  props.data.map((member, index) => ({
    ...member,
    percentage: totalPaid.value > 0 ? (member.totalPaid / totalPaid.value) * 100 : 0,
    color: member.color || getDefaultColor(index),
  })).sort((a, b) => b.totalPaid - a.totalPaid),
);

// 预设颜色
const colors = [
  '#3b82f6',
  '#10b981',
  '#f59e0b',
  '#ef4444',
  '#8b5cf6',
  '#06b6d4',
  '#84cc16',
  '#f97316',
];

function getDefaultColor(index: number): string {
  return colors[index % colors.length];
}

// 格式化金额
function formatAmount(amount: number | undefined | null): string {
  if (amount === undefined || amount === null || Number.isNaN(amount)) {
    return '0.00';
  }
  return amount.toFixed(2);
}
</script>

<template>
  <div :style="{ height }">
    <h4 v-if="title" class="text-base font-semibold text-gray-900 dark:text-white mb-4 text-center">
      {{ title }}
    </h4>

    <div class="flex flex-col md:flex-row gap-6" :class="{ 'h-[calc(100%-3rem)]': title }">
      <!-- 柱状图 -->
      <div class="flex-[2] min-h-0">
        <div class="flex h-full">
          <!-- Y轴标签 -->
          <div class="flex flex-col w-20 mr-4">
            <div class="text-xs text-gray-500 dark:text-gray-400 text-center mb-2 [writing-mode:vertical-rl]">
              支付金额 (¥)
            </div>
            <div class="flex-1 flex flex-col justify-between relative">
              <div v-for="i in 5" :key="i" class="flex items-center justify-end relative after:content-[''] after:absolute after:right-[-8px] after:w-1 after:h-px after:bg-gray-300 dark:after:bg-gray-600">
                <span class="text-xs text-gray-500 dark:text-gray-400 mr-2">{{ formatAmount(totalPaid * (5 - i + 1) / 5) }}</span>
              </div>
            </div>
          </div>

          <!-- 图表区域 -->
          <div class="flex-1 relative border-l border-b border-gray-200 dark:border-gray-700">
            <div class="flex items-end justify-around h-[calc(100%-2rem)] pt-4 px-2 pb-0">
              <div
                v-for="member in chartData"
                :key="member.name"
                class="flex flex-col items-center flex-1 max-w-[80px]"
              >
                <!-- 支付金额柱 -->
                <div class="relative w-full h-full flex items-end justify-center">
                  <div
                    class="w-[60%] min-h-[4px] rounded-t relative transition-all duration-300 cursor-pointer hover:opacity-80 hover:scale-x-110 group"
                    :style="{
                      height: `${member.percentage}%`,
                      backgroundColor: member.color,
                    }"
                  >
                    <div class="absolute bottom-full left-1/2 -translate-x-1/2 bg-black/80 text-white px-2 py-2 rounded text-xs whitespace-nowrap opacity-0 invisible group-hover:opacity-100 group-hover:visible transition-all z-10">
                      <div class="font-semibold mb-1">
                        {{ member.name }}
                      </div>
                      <div class="mb-0.5">
                        <span>支付: ¥{{ formatAmount(member.totalPaid) }}</span>
                      </div>
                      <div class="mb-0.5">
                        <span>应分摆: ¥{{ formatAmount(member.totalOwed) }}</span>
                      </div>
                      <div
                        class="mb-0.5" :class="[
                          member.netBalance > 0 ? 'text-emerald-400' : member.netBalance < 0 ? 'text-red-400' : '',
                        ]"
                      >
                        <span>净余额: ¥{{ formatAmount(Math.abs(member.netBalance)) }}</span>
                      </div>
                    </div>
                  </div>
                </div>

                <!-- X轴标签 -->
                <div class="text-xs text-gray-500 dark:text-gray-400 text-center mt-2 max-w-full overflow-hidden text-ellipsis">
                  {{ member.name }}
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- 统计信息 -->
      <div class="flex-1 min-w-[200px] border-t md:border-t-0 md:border-l border-gray-200 dark:border-gray-700 pt-4 md:pt-0 md:pl-4">
        <div class="mb-4">
          <h5 class="text-sm font-semibold text-gray-900 dark:text-white">
            详细统计
          </h5>
        </div>

        <div class="flex flex-col gap-4 max-h-[calc(100%-3rem)] overflow-y-auto [scrollbar-width:none] [-ms-overflow-style:none] [&::-webkit-scrollbar]:hidden">
          <div
            v-for="member in chartData"
            :key="member.name"
            class="p-3 bg-gray-50 dark:bg-gray-700 rounded-md border border-gray-200 dark:border-gray-600"
          >
            <div class="flex items-center gap-2 mb-2">
              <div class="w-3 h-3 rounded-full" :style="{ backgroundColor: member.color }" />
              <span class="text-sm font-medium text-gray-900 dark:text-white">{{ member.name }}</span>
            </div>

            <div class="flex flex-col gap-1">
              <div class="flex justify-between items-center">
                <span class="text-xs text-gray-600 dark:text-gray-400">支付金额:</span>
                <span class="text-xs font-medium text-gray-900 dark:text-white">¥{{ formatAmount(member.totalPaid) }}</span>
              </div>
              <div class="flex justify-between items-center">
                <span class="text-xs text-gray-600 dark:text-gray-400">应分摆:</span>
                <span class="text-xs font-medium text-gray-900 dark:text-white">¥{{ formatAmount(member.totalOwed) }}</span>
              </div>
              <div class="flex justify-between items-center">
                <span class="text-xs text-gray-600 dark:text-gray-400">净余额:</span>
                <span
                  class="text-xs font-medium" :class="[
                    member.netBalance > 0 ? 'text-emerald-600 dark:text-emerald-400'
                    : member.netBalance < 0 ? 'text-red-600 dark:text-red-400'
                      : 'text-gray-600 dark:text-gray-400',
                  ]"
                >
                  <span v-if="member.netBalance > 0">+</span>
                  <span v-else-if="member.netBalance < 0">-</span>
                  ¥{{ formatAmount(Math.abs(member.netBalance)) }}
                </span>
              </div>
              <div class="flex justify-between items-center">
                <span class="text-xs text-gray-600 dark:text-gray-400">贡献度:</span>
                <span class="text-xs font-medium text-gray-900 dark:text-white">{{ member.percentage.toFixed(1) }}%</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- 空状态 -->
    <div v-if="data.length === 0" class="flex flex-col items-center justify-center h-full text-gray-400 dark:text-gray-500">
      <LucideBarChart3 class="w-8 h-8 mb-2" />
      <p class="text-sm">
        暂无数据
      </p>
    </div>
  </div>
</template>
