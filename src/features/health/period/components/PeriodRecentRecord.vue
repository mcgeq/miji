<script setup lang="ts">
import { CalendarX, ChevronRightCircle, Plus } from 'lucide-vue-next';
import { storeToRefs } from 'pinia';
import Button from '@/components/ui/Button.vue';
import Card from '@/components/ui/Card.vue';
import { calculatePeriodDuration } from '@/features/health/period/utils/periodUtils';
import { usePeriodStore as usePeriodStores } from '@/stores/periodStore';
import type { PeriodRecords } from '@/schema/health/period';

const emit = defineEmits<{
  addRecord: [];
  editRecord: [record: PeriodRecords];
}>();

const periodStore = usePeriodStores();
const { periodRecords } = storeToRefs(periodStore);

const recentRecords = computed(() => {
  return periodRecords.value
    .slice()
    .sort(
      (a, b) =>
        new Date(b.startDate).getTime() - new Date(a.startDate).getTime(),
    )
    .slice(0, 3);
});

function formatMonth(dateStr: string) {
  const date = new Date(dateStr);
  return `${date.getMonth() + 1}月`;
}

function formatDay(dateStr: string) {
  const date = new Date(dateStr);
  return date.getDate();
}

function calculateCycleFromPrevious(record: PeriodRecords) {
  const records = periodRecords.value
    .slice()
    .sort(
      (a, b) =>
        new Date(a.startDate).getTime() - new Date(b.startDate).getTime(),
    );

  const index = records.findIndex(r => r.serialNum === record.serialNum);
  if (index <= 0)
    return '首次记录';

  const current = new Date(record.startDate);
  const previous = new Date(records[index - 1].startDate);
  const cycleDays = Math.ceil(
    (current.getTime() - previous.getTime()) / (1000 * 60 * 60 * 24),
  );

  return `周期 ${cycleDays} 天`;
}

function isPeriodActive(record: PeriodRecords) {
  const currentDate = new Date();
  const startDate = new Date(record.startDate);
  const endDate = new Date(record.endDate);
  return currentDate >= startDate && currentDate <= endDate;
}
</script>

<template>
  <Card shadow="md" padding="md">
    <!-- 自定义头部 -->
    <template #header>
      <div class="flex items-center justify-between">
        <h3 class="text-lg font-semibold text-gray-900 dark:text-white">
          最近记录
        </h3>

        <Button
          variant="primary"
          size="sm"
          @click="emit('addRecord')"
        >
          <Plus class="w-5 h-5" />
        </Button>
      </div>
    </template>

    <!-- 空状态 -->
    <div
      v-if="periodRecords.length === 0"
      class="flex flex-col items-center justify-center py-8 px-4 text-center"
    >
      <div class="flex items-center justify-center w-16 h-16 mb-3 rounded-full bg-gray-200 dark:bg-gray-700">
        <CalendarX class="w-8 h-8 text-gray-400 dark:text-gray-500" />
      </div>
      <p class="text-sm text-gray-600 dark:text-gray-400">
        还没有经期记录，
        <button
          class="text-blue-600 dark:text-blue-400 underline hover:text-blue-700 dark:hover:text-blue-300 transition-colors"
          @click="emit('addRecord')"
        >
          点击添加
        </button>
      </p>
    </div>

    <!-- 记录列表 -->
    <div v-else class="flex flex-col gap-3">
      <div
        v-for="record in recentRecords"
        :key="record.serialNum"
        class="flex items-center gap-3 sm:gap-4 p-3 rounded-lg bg-gray-50 dark:bg-gray-700/50 cursor-pointer transition-all duration-200 hover:bg-gray-100 dark:hover:bg-gray-700 hover:-translate-y-0.5 hover:shadow-md"
        @click="emit('editRecord', record)"
      >
        <!-- 日期显示 -->
        <div class="flex flex-col items-center justify-center min-w-[3rem] flex-shrink-0">
          <div class="text-sm font-semibold text-rose-600 dark:text-rose-400">
            {{ formatMonth(record.startDate) }}
          </div>
          <div class="text-2xl font-bold text-rose-600 dark:text-rose-400 leading-tight">
            {{ formatDay(record.startDate) }}
          </div>
        </div>

        <!-- 记录信息 -->
        <div class="flex-1 min-w-0 flex flex-col sm:flex-row sm:items-center sm:justify-between gap-1 sm:gap-2">
          <div class="text-sm text-gray-700 dark:text-gray-300 truncate">
            {{ isPeriodActive(record) ? `预计持续 ${calculatePeriodDuration(record)} 天` : `已持续 ${calculatePeriodDuration(record)} 天` }}
          </div>

          <div class="inline-flex items-center self-start sm:self-auto px-2 py-1 text-xs font-medium rounded bg-blue-600 dark:bg-blue-500 text-white">
            {{ calculateCycleFromPrevious(record) }}
          </div>
        </div>

        <!-- 箭头图标 -->
        <ChevronRightCircle class="w-6 h-6 flex-shrink-0 text-blue-600 dark:text-blue-400 transition-colors group-hover:text-blue-700 dark:group-hover:text-blue-300" />
      </div>
    </div>
  </Card>
</template>
