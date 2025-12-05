<script setup lang="ts">
// 预算列表组件
import { formatCurrency } from '@/features/money/utils/money';
import { getRepeatTypeName } from '@/utils/business/repeat';
import type { Budget } from '@/schema/money';

interface Props {
  budgets: Budget[];
}

defineProps<Props>();

function getBudgetProgress(budget: Budget) {
  const progress = Number(budget?.progress ?? 0);
  return Number.isFinite(progress) ? Math.min(Math.max(progress, 0), 100) : 0;
}

function isBudgetOver(budget: Budget) {
  return Number(budget?.usedAmount ?? 0) > Number(budget?.amount ?? 0);
}

function getBudgetPeriodText(budget: Budget) {
  return getRepeatTypeName(budget?.repeatPeriod);
}
</script>

<template>
  <div class="w-full">
    <div v-if="budgets.length === 0" class="text-center py-8 px-4 text-gray-600 dark:text-gray-400 opacity-50 text-sm">
      暂无预算
    </div>
    <div v-else class="flex flex-col gap-2">
      <div
        v-for="budget in budgets"
        :key="budget.serialNum"
        class="flex items-center gap-3 px-3 py-3 md:px-2 md:py-2 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg"
      >
        <div class="w-8 h-8 rounded-lg flex items-center justify-center flex-shrink-0 bg-yellow-100 text-yellow-600">
          <LucideTarget :size="14" />
        </div>
        <div class="flex-1 min-w-0">
          <div class="text-sm font-semibold text-gray-900 dark:text-white truncate">
            {{ budget.name }}
          </div>
          <div class="text-xs text-gray-600 dark:text-gray-400 opacity-60 truncate">
            {{ getBudgetPeriodText(budget) }}
          </div>
        </div>
        <!-- 进度条 (桌面端显示) -->
        <div class="hidden md:flex items-center gap-2 min-w-[120px] flex-1 max-w-[200px]">
          <div class="flex-1 h-2 bg-gray-100 dark:bg-gray-700 rounded-full overflow-hidden relative border border-gray-200 dark:border-gray-600">
            <div
              class="h-full rounded-full transition-all shadow-sm"
              :class="isBudgetOver(budget) ? 'bg-gradient-to-r from-red-500 to-red-600' : 'bg-gradient-to-r from-blue-500 to-blue-600'"
              :style="{ width: `${getBudgetProgress(budget)}%` }"
            />
          </div>
          <div
            class="text-xs font-semibold min-w-10 h-6 leading-6 text-center rounded-xl border flex items-center justify-center px-2"
            :class="isBudgetOver(budget) ? 'text-red-600 bg-red-50 dark:bg-red-900/20 border-red-200 dark:border-red-700' : 'text-gray-700 dark:text-gray-300 bg-white dark:bg-gray-800 border-gray-200 dark:border-gray-600'"
          >
            {{ getBudgetProgress(budget) }}%
          </div>
        </div>
        <!-- 移动端只显示百分比 -->
        <div class="flex md:hidden items-center justify-end flex-shrink-0">
          <div
            class="text-xs font-semibold min-w-8 h-5 leading-5 text-center rounded-lg border flex items-center justify-center px-2"
            :class="isBudgetOver(budget) ? 'text-red-600 bg-red-50 dark:bg-red-900/20 border-red-200 dark:border-red-700' : 'text-gray-700 dark:text-gray-300 bg-white dark:bg-gray-800 border-gray-200 dark:border-gray-600'"
          >
            {{ getBudgetProgress(budget) }}%
          </div>
        </div>
        <!-- 金额信息 -->
        <div class="flex flex-col items-end gap-0.5 flex-shrink-0">
          <div class="text-sm font-semibold text-gray-900 dark:text-white whitespace-nowrap">
            {{ formatCurrency(budget.amount ?? 0) }}
          </div>
          <div
            class="text-xs font-medium whitespace-nowrap"
            :class="isBudgetOver(budget) ? 'text-red-600 font-semibold' : 'text-blue-600'"
          >
            已用: {{ formatCurrency(budget.usedAmount ?? 0) }}
          </div>
          <div
            class="text-xs font-medium whitespace-nowrap"
            :class="isBudgetOver(budget) ? 'text-red-600 font-semibold' : 'text-green-600'"
          >
            剩余: {{ formatCurrency((Number(budget.amount ?? 0) - Number(budget.usedAmount ?? 0))) }}
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
