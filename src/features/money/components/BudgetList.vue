<template>
  <div class="min-h-25">
    <div v-if="loading" class="flex-justify-center h-25 text-gray-600">
      加载中...
    </div>
    <div v-else-if="budgets.length === 0" class="flex-justify-center flex-col h-25 text-#999">
      <div class="text-sm mb-2 opacity-50">
        <i class="icon-target"></i>
      </div>
      <div class="text-sm">暂无预算</div>
    </div>
    <div v-else class="budget-grid frid gap-5 w-full">
      <div v-for="budget in budgets"
        :key="budget.serialNum"
        :class="[
        'bg-white border rounded-md p-1.5 transition-all hover:shadow-md',
        { 'opacity-60 bg-gray-100': !budget.isActive }
        ]"
        :style="{
          borderColor: budget.color || '#E5E7EB'
        }"
      >
        <!-- Header -->
        <div class="flex flex-wrap justify-between items-center mb-2 gap-2">
          <!-- 左侧预算名称 -->
          <div class="flex items-center text-gray-800">
            <span class=" text-lg font-semibold">{{ budget.name }}</span>
          </div>

          <!-- 右侧按钮组 -->
          <div class="flex items-center gap-1 md:self-end">
            <button
              class="money-option-btn hover:(border-green-500 text-green-500)"
              @click="emit('edit', budget)" title="编辑">
              <Edit class="w-4 h-4" />
            </button>
            <button
              class="money-option-btn hover:(border-blue-500 text-blue-500)"
              @click="emit('toggle-active', budget.serialNum)" :title="budget.isActive ? '停用' : '启用'">
              <component :is="budget.isActive ? Ban : StopCircle" class="w-4 h-4" />
            </button>
            <button
              class="money-option-btn hover:(border-red-500 text-red-500)"
              @click="emit('delete', budget.serialNum)" title="删除">
              <Trash class="w-4 h-4" />
            </button>
          </div>
        </div>
        <!-- Period -->
        <div class="flex items-center gap-1 mb-2 text-gray-600 text-sm">
          <CalendarIcon class="w-4 h-4 text-gray-600" />
          <span>{{ getBudgetPeriodName(budget.repeatPeriod) }}</span>
        </div>

        <!-- Progress -->
        <div class="mb-2">
          <div class="flex items-baseline gap-1 mb-1">
            <span class="text-lg font-semibold text-gray-800">{{ formatCurrency(budget.usedAmount) }}</span>
            <span class="text-sm text-gray-600">/ {{ formatCurrency(budget.amount) }}</span>
            <div class="ml-auto flex justify-end mb-2 p-1.5 bg-gray-50 rounded-md">
              <div :class="[
                'text-lg font-semibold',
                shouldHighlightRed(budget) ? 'text-red-500' : 'text-green-500'
              ]">
               {{ formatCurrency(getRemainingAmount(budget)) }}
              </div>
            </div>
          </div>
          <div class="w-full h-1 bg-gray-200 rounded-md overflow-hidden mb-1">
            <div class="h-full transition-[width] duration-300" :style="{ width: `${getProgressPercent(budget)}%` }"
              :class="isOverBudget(budget) ? 'bg-red-500' : 'bg-blue-500'"></div>
          </div>
          <div class="text-center text-lg"
            :class="shouldHighlightRed(budget) ? 'text-red-500' : 'text-gray-600'">
            {{ getProgressPercent(budget) }}%
          </div>
        </div>

        <!-- Info -->
        <div class="border-t border-gray-200 pt-2">
          <div class="flex justify-between mb-1 text-sm">
            <span class="font-medium text-gray-600">分类：</span>
            <span class="font-medium text-gray-800">{{ budget.category }}</span>
          </div>
          <div class="flex justify-between mb-1 text-sm">
            <span class="text-gray-600">创建时间：</span>
            <span class="text-gray-800">{{ formatDate(budget.createdAt) }}</span>
          </div>
          <div v-if="budget.description" class="flex justify-between mb-1 text-sm last:mb-0">
            <span class="text-gray-600">备注：</span>
            <span class="text-gray-800">{{ budget.description }}</span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import {Trash, Edit, CalendarIcon, StopCircle, Ban} from 'lucide-vue-next';
import {Budget} from '@/schema/money';
import {RepeatPeriod} from '@/schema/common';
import {formatDate} from '@/utils/date';
import {formatCurrency} from '../utils/money';

interface Props {
  budgets: Budget[];
  loading: boolean;
}

defineProps<Props>();

const emit = defineEmits<{
  edit: [budget: Budget];
  delete: [serialNum: string];
  'toggle-active': [serialNum: string];
}>();

const getBudgetPeriodName = (period: RepeatPeriod): string => {
  switch (period.type) {
    case 'None':
      return '无周期';
    case 'Daily':
      return period.interval > 1 ? `每${period.interval}天` : '每日预算';
    case 'Weekly':
      return period.interval > 1
        ? `每${period.interval}周 (${period.daysOfWeek.join(',')})`
        : `每周 (${period.daysOfWeek.join(',')})`;
    case 'Monthly':
      const day = period.day === 'last' ? '最后一天' : `第${period.day}天`;
      return period.interval > 1
        ? `每${period.interval}月，${day}`
        : `每月，${day}`;
    case 'Yearly':
      return period.interval > 1
        ? `每${period.interval}年，${period.month}月${period.day}日`
        : `${period.month}月${period.day}日`;
    case 'Custom':
      return period.description;
    default:
      return '未知周期';
  }
};

const getProgressPercent = (budget: Budget) => {
  const used = parseFloat(budget.usedAmount);
  const total = parseFloat(budget.amount);
  return Math.round((used / total) * 100);
};

const isOverBudget = (budget: Budget) => {
  const used = parseFloat(budget.usedAmount);
  const total = parseFloat(budget.amount);
  return used > total;
};

const isLowOnBudget = (budget: Budget) => {
  const percent = getProgressPercent(budget);
  return percent > 70;
};

const shouldHighlightRed = (budget: Budget) => {
  return isOverBudget(budget) || isLowOnBudget(budget);
};

const getRemainingAmount = (budget: Budget) => {
  const used = parseFloat(budget.usedAmount);
  const total = parseFloat(budget.amount);
  return (total - used).toString();
};
</script>

<style scoped>
.loading {
  display: flex;
  justify-content: center;
  align-items: center;
  height: 200px;
  color: #666;
}

.budget-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(320px, 1fr));
  gap: 20px;
}
</style>
