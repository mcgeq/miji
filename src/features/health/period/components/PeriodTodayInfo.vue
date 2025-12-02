<script setup lang="ts">
import { CalendarCheck, Eye, Plus, Trash } from 'lucide-vue-next';
import Badge from '@/components/ui/Badge.vue';
import PeriodInfoCard from './PeriodInfoCard.vue';
import type { PeriodDailyRecords } from '@/schema/health/period';

defineProps<{
  currentPhaseLabel: string;
  daysUntilNext: string;
  todayRecord?: PeriodDailyRecords | null;
}>();

const emit = defineEmits<{
  viewRecord: [record: PeriodDailyRecords];
  deleteRecord: [serialNum: string];
  addRecord: [];
}>();

const { t } = useI18n();
</script>

<template>
  <PeriodInfoCard :title="t('period.todayInfo.title')" :icon="CalendarCheck" color="blue">
    <!-- 内容区域 -->
    <div class="flex flex-col gap-2.5">
      <!-- 当前阶段 -->
      <div class="flex items-center justify-between px-3 py-2.5 rounded-lg bg-gray-50 dark:bg-gray-700/50 transition-colors hover:bg-gray-100 dark:hover:bg-gray-700">
        <span class="text-sm font-medium text-gray-700 dark:text-gray-300">
          {{ t('period.todayInfo.currentPhase') }}
        </span>
        <Badge variant="info" size="md">
          {{ currentPhaseLabel }}
        </Badge>
      </div>

      <!-- 距离下次天数 -->
      <div class="flex items-center justify-between px-3 py-2.5 rounded-lg bg-gray-50 dark:bg-gray-700/50 transition-colors hover:bg-gray-100 dark:hover:bg-gray-700">
        <span class="text-sm font-medium text-gray-700 dark:text-gray-300">
          {{ t('period.todayInfo.daysUntilNext') }}
        </span>
        <span class="text-sm font-bold text-rose-600 dark:text-rose-400">
          {{ daysUntilNext }}
        </span>
      </div>

      <!-- 今日记录 - 有记录 -->
      <div
        v-if="todayRecord"
        class="flex items-center justify-between px-3 py-2.5 rounded-lg bg-gray-50 dark:bg-gray-700/50 transition-colors hover:bg-gray-100 dark:hover:bg-gray-700"
      >
        <span class="text-sm font-medium text-gray-700 dark:text-gray-300">
          {{ t('period.todayInfo.todayRecord') }}
        </span>
        <div class="flex items-center gap-2">
          <!-- 查看按钮 -->
          <button
            :title="t('common.actions.view')"
            class="flex items-center justify-center w-8 h-8 rounded-lg bg-blue-100 dark:bg-blue-900/30 text-blue-600 dark:text-blue-400 transition-all hover:bg-blue-200 dark:hover:bg-blue-900/50 hover:scale-105 shadow-sm"
            @click="emit('viewRecord', todayRecord)"
          >
            <Eye class="w-4 h-4" />
          </button>

          <!-- 删除按钮 -->
          <button
            :title="t('common.actions.delete')"
            class="flex items-center justify-center w-8 h-8 rounded-lg bg-rose-100 dark:bg-rose-900/30 text-rose-600 dark:text-rose-400 transition-all hover:bg-rose-200 dark:hover:bg-rose-900/50 hover:scale-105 shadow-sm"
            @click="emit('deleteRecord', todayRecord.serialNum)"
          >
            <Trash class="w-4 h-4" />
          </button>
        </div>
      </div>

      <!-- 今日记录 - 无记录 -->
      <div
        v-else
        class="flex items-center justify-between px-3 py-2.5 rounded-lg bg-gray-50 dark:bg-gray-700/50 transition-colors hover:bg-gray-100 dark:hover:bg-gray-700"
      >
        <span class="text-sm font-medium text-gray-700 dark:text-gray-300">
          {{ t('period.todayInfo.todayRecord') }}
        </span>
        <div class="flex items-center gap-2">
          <span class="text-xs italic text-gray-500 dark:text-gray-400">
            {{ t('period.todayInfo.noRecord') }}
          </span>

          <!-- 添加按钮 -->
          <button
            :title="t('common.actions.add')"
            class="flex items-center justify-center w-8 h-8 rounded-lg bg-green-100 dark:bg-green-900/30 text-green-600 dark:text-green-400 transition-all hover:bg-green-200 dark:hover:bg-green-900/50 hover:scale-105 shadow-sm"
            @click="emit('addRecord')"
          >
            <Plus class="w-4 h-4" />
          </button>
        </div>
      </div>
    </div>
  </PeriodInfoCard>
</template>
