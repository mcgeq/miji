<script setup lang="ts">
import { RotateCcw } from 'lucide-vue-next';
import type { BudgetFilters } from '@/services/money/budgets';

interface Props {
  filters: BudgetFilters;
  categories: string[];
}
const props = defineProps<Props>();

const emit = defineEmits<{
  update: [filters: BudgetFilters];
  reset: [];
}>();

const { t } = useI18n();

// 状态更新
function updateFilter<K extends keyof BudgetFilters>(key: K, value: BudgetFilters[K]) {
  emit('update', { ...props.filters, [key]: value });
}
</script>

<template>
  <div class="mb-5 flex flex-wrap items-center justify-center gap-3 rounded-lg bg-gray-50 p-4">
    <!-- 状态过滤 -->
    <div class="filter-flex-wrap">
      <label class="show-on-desktop text-sm text-gray-700 font-medium">{{ t('common.status.status') }}</label>
      <select
        :value="filters.isActive"
        class="border border-gray-300 rounded-md px-3 py-1.5 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
        @change="updateFilter('isActive', ($event.target as HTMLSelectElement).value === '' ? undefined : ($event.target as HTMLSelectElement).value === 'true')"
      >
        <option value="">
          {{ t('common.actions.all') }}
        </option>
        <option value="active">
          {{ t('common.status.active') }}
        </option>
        <option value="inactive">
          {{ t('common.status.inactive') }}
        </option>
      </select>
    </div>

    <!-- 周期过滤 -->
    <div class="filter-flex-wrap">
      <label class="show-on-desktop text-sm text-gray-700 font-medium">{{ t('todos.repeat.periodType') }}</label>
      <select
        :value="filters.repeatPeriod"
        class="border border-gray-300 rounded-md px-3 py-1.5 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
        @change="updateFilter('repeatPeriod', ($event.target as HTMLSelectElement).value)"
      >
        <option value="">
          {{ t('common.actions.all') }}
        </option>
        <option value="None">
          {{ t('date.repeat.none') }}
        </option>
        <option value="Daily">
          {{ t('date.repeat.daily') }}
        </option>
        <option value="Weekly">
          {{ t('date.repeat.weekly') }}
        </option>
        <option value="Monthly">
          {{ t('date.repeat.monthly') }}
        </option>
        <option value="Yearly">
          {{ t('date.repeat.yearly') }}
        </option>
        <option value="Custom">
          {{ t('date.repeat.custom') }}
        </option>
      </select>
    </div>

    <!-- 分类过滤 -->
    <div class="filter-flex-wrap">
      <label class="show-on-desktop text-sm text-gray-700 font-medium">{{ t('categories.category') }}</label>
      <select
        :value="filters.category"
        class="border border-gray-300 rounded-md px-3 py-1.5 text-sm focus:outline-none focus:ring-2 focus:ring-blue-500"
        @change="updateFilter('category', ($event.target as HTMLSelectElement).value)"
      >
        <option value="">
          {{ t('categories.allCategory') }}
        </option>
        <option v-for="category in categories" :key="category" :value="category">
          {{ category }}
        </option>
      </select>
    </div>

    <!-- 重置按钮 -->
    <button
      class="rounded-md bg-gray-200 px-3 py-1.5 text-sm text-gray-700 transition-colors hover:bg-gray-300"
      @click="emit('reset')"
    >
      <RotateCcw class="mr-1 wh-5" />
    </button>
  </div>
</template>
