<script setup lang="ts">
// 提醒列表组件
import { formatCurrency } from '@/features/money/utils/money';
import type { BilReminder } from '@/schema/money';

interface Props {
  reminders: BilReminder[];
}

defineProps<Props>();
</script>

<template>
  <div class="w-full">
    <div v-if="reminders.length === 0" class="text-center py-8 px-4 text-gray-600 dark:text-gray-400 opacity-50 text-sm">
      暂无提醒
    </div>
    <div v-else class="flex flex-col gap-2">
      <div
        v-for="reminder in reminders"
        :key="reminder.serialNum"
        class="flex items-center gap-3 px-3 py-3 md:px-3 md:py-3 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg transition-all cursor-pointer hover:bg-gray-50 dark:hover:bg-gray-700 hover:shadow-sm"
      >
        <div class="w-8 h-8 rounded-lg flex items-center justify-center flex-shrink-0 bg-yellow-100 text-yellow-600">
          <LucideBell :size="14" />
        </div>
        <div class="flex-1 min-w-0">
          <div class="text-sm font-semibold text-gray-900 dark:text-white truncate">
            {{ reminder.name }}
          </div>
          <div class="text-xs text-gray-600 dark:text-gray-400 opacity-60 truncate">
            {{ reminder.billDate }}
          </div>
        </div>
        <div class="text-sm font-semibold text-gray-900 dark:text-white">
          {{ formatCurrency(reminder.amount ?? 0) }}
        </div>
      </div>
    </div>
  </div>
</template>
