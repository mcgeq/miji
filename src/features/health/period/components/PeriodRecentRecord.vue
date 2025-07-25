<script setup lang="ts">
import { Plus } from 'lucide-vue-next';
import { usePeriodStore as usePeriodStores } from '@/stores/periodStore';
import type { PeriodRecords } from '@/schema/health/period';
// Emits
const emit = defineEmits<{
  addRecord: [];
  editRecord: [record: PeriodRecords];
}>();
const periodStore = usePeriodStores();

const recentRecords = computed(() => {
  return periodStore.periodRecords
    .slice()
    .sort(
      (a, b) =>
        new Date(b.startDate).getTime() - new Date(a.startDate).getTime(),
    )
    .slice(0, 3);
});

// Methods
function formatMonth(dateStr: string) {
  const date = new Date(dateStr);
  return `${date.getMonth() + 1}月`;
}

function formatDay(dateStr: string) {
  const date = new Date(dateStr);
  return date.getDate();
}

function calculateDuration(record: PeriodRecords) {
  const start = new Date(record.startDate);
  const end = new Date(record.endDate);
  return (
    Math.ceil((end.getTime() - start.getTime()) / (1000 * 60 * 60 * 24)) + 1
  );
}

function calculateCycleFromPrevious(record: PeriodRecords) {
  const records = periodStore.periodRecords
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
</script>

<template>
  <!-- 最近记录 -->
  <div class="recent-records card-base p-4">
    <div class="mb-4 flex-between">
      <h3 class="text-lg text-gray-900 font-semibold dark:text-white">
        最近记录
      </h3>
      <button class="btn-primary text-sm" @click="emit('addRecord')">
        <Plus class="wh-5" />
      </button>
    </div>

    <div v-if="periodStore.periodRecords.length === 0" class="empty-state">
      <i class="i-tabler-calendar-off mx-auto mb-3 wh-12 text-gray-400" />
      <p class="text-center text-gray-500 dark:text-gray-400">
        还没有经期记录，<button class="text-blue-500 hover:underline" @click="emit('addRecord')">
          点击添加
        </button>
      </p>
    </div>

    <div v-else class="space-y-3">
      <div
        v-for="record in recentRecords" :key="record.serialNum" class="record-item"
        @click="$emit('editRecord', record)"
      >
        <div class="record-date">
          <div class="record-month">
            {{ formatMonth(record.startDate) }}
          </div>
          <div class="record-day">
            {{ formatDay(record.startDate) }}
          </div>
        </div>
        <div class="record-info">
          <div class="record-duration">
            持续 {{ calculateDuration(record) }} 天
          </div>
          <div class="record-cycle">
            {{ calculateCycleFromPrevious(record) }}
          </div>
        </div>
        <div class="record-actions">
          <i class="i-tabler-chevron-right wh-4 text-gray-400" />
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped lang="postcss">
.card-base {
  @apply bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg shadow-sm;
}

.flex-between {
  @apply flex items-center justify-between;
}

.btn-primary {
  @apply px-3 py-1.5 bg-blue-600 text-white rounded-lg hover:bg-blue-700 focus:ring-2 focus:ring-blue-500 transition-colors flex items-center;
}

.empty-state {
  @apply flex flex-col items-center py-8;
}

.record-item {
  @apply flex items-center gap-4 p-3 rounded-lg border border-gray-200 dark:border-gray-700 hover:bg-gray-50 dark:hover:bg-gray-700 cursor-pointer transition-colors;
}

.record-date {
  @apply text-center flex-shrink-0;
}

.record-month {
  @apply text-xs text-gray-500 dark:text-gray-400;
}

.record-day {
  @apply text-lg font-bold text-gray-900 dark:text-white;
}

.record-info {
  @apply flex-1;
}

.record-duration {
  @apply text-sm font-medium text-gray-900 dark:text-white;
}

.record-cycle {
  @apply text-xs text-gray-500 dark:text-gray-400;
}

.record-actions {
  @apply flex-shrink-0;
}

.tip-item {
  @apply flex items-start gap-2;
}

@media (max-width: 768px) {
  .stats-grid {
    @apply grid-cols-1;
  }

  .stat-card {
    @apply p-3;
  }

  .stat-value {
    @apply text-lg;
  }
}
</style>
