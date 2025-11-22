<script setup lang="ts">
import { storeToRefs } from 'pinia';
import { calculatePeriodDuration } from '@/features/health/period/utils/periodUtils';
import { usePeriodStore as usePeriodStores } from '@/stores/periodStore';
import type { PeriodRecords } from '@/schema/health/period';
// Emits
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

// Methods
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
  <!-- 最近记录 -->
  <div class="recent-records">
    <div class="recent-records-header">
      <h3 class="recent-records-title">
        最近记录
      </h3>
      <button class="recent-records-add-btn" @click="emit('addRecord')">
        <LucidePlus class="recent-records-add-icon" />
      </button>
    </div>

    <div v-if="periodRecords.length === 0" class="recent-records-empty">
      <i class="recent-records-empty-icon" />
      <p class="recent-records-empty-text">
        还没有经期记录，<button class="recent-records-empty-link" @click="emit('addRecord')">
          点击添加
        </button>
      </p>
    </div>

    <div v-else class="recent-records-list">
      <div
        v-for="record in recentRecords"
        :key="record.serialNum"
        class="recent-record-item"
        @click="$emit('editRecord', record)"
      >
        <div class="recent-record-date">
          <div class="recent-record-month">
            {{ formatMonth(record.startDate) }}
          </div>
          <div class="recent-record-day">
            {{ formatDay(record.startDate) }}
          </div>
        </div>
        <div class="recent-record-info">
          <div class="recent-record-duration">
            {{ isPeriodActive(record) ? `预计持续 ${calculatePeriodDuration(record)} 天` : `已持续 ${calculatePeriodDuration(record)} 天` }}
          </div>
          <div class="recent-record-cycle">
            {{ calculateCycleFromPrevious(record) }}
          </div>
        </div>
        <div class="recent-record-actions">
          <LucideChevronRightCircle class="recent-record-arrow" />
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped lang="postcss">
/* 最近记录容器 */
.recent-records {
  padding: 1rem;
  background-color: var(--color-base-100);
  border: 1px solid var(--color-base-300);
  border-radius: 0.75rem;
  box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06);
  transition: box-shadow 0.2s ease-in-out;
}

/* 最近记录头部 */
.recent-records-header {
  margin-bottom: 1rem;
  display: flex;
  align-items: center;
  justify-content: space-between;
}

/* 最近记录标题 */
.recent-records-title {
  font-size: 1.125rem;
  color: var(--color-base-content);
  font-weight: 600;
}

/* 添加记录按钮 */
.recent-records-add-btn {
  padding: 0.375rem 0.75rem;
  background-color: var(--color-primary);
  color: var(--color-primary-content);
  border-radius: 0.5rem;
  transition: all 0.2s ease-in-out;
  display: flex;
  align-items: center;
  font-size: 0.875rem;
  border: none;
  cursor: pointer;
}

.recent-records-add-btn:hover {
  background-color: var(--color-primary-soft);
}

/* 添加记录按钮图标 */
.recent-records-add-icon {
  width: 1.25rem;
  height: 1.25rem;
}

/* 空状态 */
.recent-records-empty {
  text-align: center;
  padding: 2rem 1rem;
}

.recent-records-empty-icon {
  display: block;
  width: 3rem;
  height: 3rem;
  margin: 0 auto 0.75rem;
  background-color: var(--color-neutral);
  border-radius: 50%;
}

.recent-records-empty-text {
  color: var(--color-neutral-content);
  text-align: center;
}

.recent-records-empty-link {
  color: var(--color-info);
  text-decoration: underline;
  background: none;
  border: none;
  cursor: pointer;
}

.recent-records-empty-link:hover {
  color: var(--color-info-content);
}

/* 记录列表 */
.recent-records-list {
  display: flex;
  flex-direction: column;
  gap: 0.75rem;
}

/* 记录项目 */
.recent-record-item {
  display: flex;
  align-items: center;
  gap: 1rem;
  padding: 0.75rem;
  background-color: var(--color-base-200);
  border-radius: 0.5rem;
  cursor: pointer;
  transition: all 0.2s ease-in-out;
}

.recent-record-item:hover {
  background-color: var(--color-base-300);
  transform: translateY(-1px);
}

/* 记录日期 */
.recent-record-date {
  display: flex;
  flex-direction: column;
  align-items: center;
  min-width: 3rem;
}

.recent-record-month {
  font-size: 0.875rem;
  color: var(--color-error);
  font-weight: 600;
}

.recent-record-day {
  font-size: 1.5rem;
  color: var(--color-error);
  font-weight: 700;
}

/* 记录信息 */
.recent-record-info {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.recent-record-duration {
  font-size: 0.875rem;
  color: var(--color-base-content);
}

.recent-record-cycle {
  font-size: 0.75rem;
  color: var(--color-primary-content);
  background-color: var(--color-primary);
  padding: 0.25rem 0.5rem;
  border-radius: 0.25rem;
  font-weight: 500;
}

/* 记录操作 */
.recent-record-actions {
  display: flex;
  align-items: center;
}

.recent-record-arrow {
  width: 1.5rem;
  height: 1.5rem;
  color: var(--color-primary);
  transition: color 0.2s ease-in-out;
}

.recent-record-item:hover .recent-record-arrow {
  color: var(--color-primary-content);
}

/* 深色模式适配 */
.dark .recent-records {
  background-color: var(--color-base-200);
  border-color: var(--color-base-300);
}

.dark .recent-record-item {
  background-color: var(--color-base-300);
}

.dark .recent-record-item:hover {
  background-color: var(--color-base-content);
}
</style>
