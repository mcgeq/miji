<script setup lang="ts">
import { Ban, Edit, StopCircle, Trash } from 'lucide-vue-next';
import { DateUtils } from '@/utils/date';
import { formatCurrency } from '../utils/money';
import type { Budget } from '@/schema/money';

// 接收 props
interface Props {
  budget: Budget;
}
const { budget } = defineProps<Props>();

// 定义事件
const emit = defineEmits<{
  edit: [budget: Budget];
  delete: [serialNum: string];
  toggleActive: [serialNum: string, isActive: boolean];
}>();

// 预算进度百分比
function getProgressPercent(budget: Budget) {
  const used = budget.usedAmount;
  const total = budget.amount;
  return Math.min(Math.round((used / total) * 100), 100);
}

// 是否超支
function isOverBudget(budget: Budget) {
  return budget.usedAmount > budget.amount;
}

// 是否超过阈值（70%）
function isLowOnBudget(budget: Budget) {
  return getProgressPercent(budget) > 70;
}

// 是否需要红色高亮
function shouldHighlightRed(budget: Budget) {
  return isOverBudget(budget) || isLowOnBudget(budget);
}

// 剩余金额
function getRemainingAmount(budget: Budget) {
  return (budget.amount - budget.usedAmount).toString();
}
</script>

<template>
  <div
    class="border rounded-md bg-white p-1.5 transition-all hover:shadow-md"
    :class="[{ 'opacity-60 bg-gray-100': !budget.isActive }]"
    :style="{ borderColor: budget.color || '#E5E7EB' }"
  >
    <!-- Header -->
    <div class="mb-2 flex flex-wrap items-center justify-between gap-2">
      <!-- 左侧预算名称 -->
      <div class="flex items-center text-gray-800">
        <span class="text-lg font-semibold">{{ budget.name }}</span>
        <!-- 状态标签 -->
        <span v-if="!budget.isActive" class="ml-2 rounded bg-gray-200 px-2 py-0.5 text-xs text-gray-600">
          Inactive
        </span>
        <span v-else-if="isOverBudget(budget)" class="ml-2 rounded bg-red-100 px-2 py-0.5 text-xs text-red-600">
          Exceeded
        </span>
        <span v-else-if="isLowOnBudget(budget)" class="ml-2 rounded bg-yellow-100 px-2 py-0.5 text-xs text-yellow-600">
          Warning
        </span>
      </div>

      <!-- 右侧按钮组 -->
      <div class="flex items-center gap-1 md:self-end">
        <button
          class="money-option-btn hover:(border-green-500 text-green-500)"
          title="Edit"
          @click="emit('edit', budget)"
        >
          <Edit class="h-4 w-4" />
        </button>
        <button
          class="money-option-btn hover:(border-blue-500 text-blue-500)"
          :title="budget.isActive ? 'Stop' : 'Enable'"
          @click="emit('toggleActive', budget.serialNum, !budget.isActive)"
        >
          <component :is="budget.isActive ? Ban : StopCircle" class="h-4 w-4" />
        </button>
        <button
          class="money-option-btn hover:(border-red-500 text-red-500)"
          title="Delete"
          @click="emit('delete', budget.serialNum)"
        >
          <Trash class="h-4 w-4" />
        </button>
      </div>
    </div>

    <!-- Period -->
    <div class="mb-1 flex items-center justify-end gap-1 text-sm text-gray-600">
      <Repeat class="h-4 w-4 text-gray-600" />
      <span>{{ budget.repeatPeriod.type }}</span>
    </div>

    <!-- Progress -->
    <div class="mb-2">
      <div class="flex items-baseline gap-1">
        <span class="text-lg text-gray-800 font-semibold">{{ formatCurrency(budget.usedAmount) }}</span>
        <span class="text-sm text-gray-600">/ {{ formatCurrency(budget.amount) }}</span>
        <div class="mb-2 ml-auto flex justify-end rounded-md bg-gray-50 p-1.5">
          <div
            class="text-lg font-semibold"
            :class="[shouldHighlightRed(budget) ? 'text-red-500' : 'text-green-500']"
          >
            {{ formatCurrency(getRemainingAmount(budget)) }}
          </div>
        </div>
      </div>
      <div class="mb-1 h-1 w-full overflow-hidden rounded-md bg-gray-200">
        <div
          class="h-full transition-[width] duration-300"
          :style="{ width: `${getProgressPercent(budget)}%` }"
          :class="isOverBudget(budget) ? 'bg-red-500' : 'bg-blue-500'"
        />
      </div>
      <div class="text-center text-lg" :class="shouldHighlightRed(budget) ? 'text-red-500' : 'text-gray-600'">
        {{ getProgressPercent(budget) }}%
      </div>
    </div>

    <!-- Info -->
    <div class="border-t border-gray-200 pt-2">
      <div class="mb-1 flex justify-between text-sm">
        <span class="text-gray-600 font-medium">Category</span>
        <span class="text-gray-800 font-medium">{{ budget.category }}</span>
      </div>
      <div class="mb-1 flex justify-between text-sm">
        <span class="text-gray-600">Created</span>
        <span class="text-gray-800">{{ DateUtils.formatDate(budget.createdAt) }}</span>
      </div>
      <div v-if="budget.description" class="mb-1 flex justify-between text-sm last:mb-0">
        <span class="text-gray-600">Remark</span>
        <span class="text-gray-800">{{ budget.description }}</span>
      </div>
    </div>
  </div>
</template>

<style scoped lang="postcss">
.money-option-btn {
  @apply p-1.5 border border-gray-300 rounded-md text-gray-600 hover:bg-gray-50 transition-colors;
}
</style>
