<script setup lang="ts">
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
  <div class="today-info-card">
    <div class="today-info-header">
      <div class="today-info-icon">
        <LucideCalendarCheck class="today-info-icon-svg" />
      </div>
      <h3 class="today-info-title">
        {{ t('period.todayInfo.title') }}
      </h3>
    </div>
    <div class="today-info-content">
      <div class="info-item">
        <span class="info-label">{{ t('period.todayInfo.currentPhase') }}</span>
        <span class="info-value phase-badge">
          {{ currentPhaseLabel }}
        </span>
      </div>
      <div class="info-item">
        <span class="info-label">{{ t('period.todayInfo.daysUntilNext') }}</span>
        <span class="info-value">{{ daysUntilNext }}</span>
      </div>
      <div v-if="todayRecord" class="info-item">
        <span class="info-label">{{ t('period.todayInfo.todayRecord') }}</span>
        <div class="info-actions">
          <button class="action-icon-btn view-btn" :title="t('common.actions.view')" @click="emit('viewRecord', todayRecord)">
            <LucideEye class="wh-4" />
          </button>
          <button
            class="action-icon-btn delete-btn" :title="t('common.actions.delete')"
            @click="emit('deleteRecord', todayRecord.serialNum)"
          >
            <LucideTrash class="wh-4" />
          </button>
        </div>
      </div>
      <div v-else class="info-item">
        <span class="info-label">{{ t('period.todayInfo.todayRecord') }}</span>
        <span class="info-no-record">{{ t('period.todayInfo.noRecord') }}</span>
        <button class="action-icon-btn add-btn" :title="t('common.actions.add')" @click="emit('addRecord')">
          <LucidePlus class="wh-4" />
        </button>
      </div>
    </div>
  </div>
</template>

<style scoped lang="postcss">
.today-info-card {
  border: 1px solid var(--color-base-300);
  border-left-width: 4px;
  border-left-color: var(--color-info);
  background-color: var(--color-base-100);
  border-radius: 0.75rem;
  padding: 0.75rem;
  display: flex;
  flex-direction: column;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
  flex: 1;
  align-self: stretch;
  box-sizing: border-box;
}

.today-info-header {
  display: flex;
  align-items: center;
  gap: 0.625rem;
  margin-bottom: 0.75rem;
  padding-bottom: 0.625rem;
  border-bottom: 2px solid var(--color-info);
}

.today-info-icon {
  display: flex;
  align-items: center;
  justify-content: center;
}

.today-info-icon-svg {
  width: 1.125rem;
  height: 1.125rem;
  color: var(--color-info);
}

.today-info-title {
  font-size: 1rem;
  font-weight: 700;
  color: var(--color-info);
  margin: 0;
}

.today-info-content {
  display: flex;
  flex-direction: column;
  gap: 0.625rem;
  flex: 1;
  min-height: 0;
}

.info-item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0.625rem 0.75rem;
  background-color: var(--color-base-200);
  border-radius: 0.5rem;
  transition: all 0.2s;
}

.info-item:hover {
  background-color: var(--color-base-300);
}

.info-label {
  font-size: 0.875rem;
  font-weight: 500;
  color: var(--color-base-content);
}

.info-value {
  font-size: 0.875rem;
  font-weight: 700;
  color: var(--color-error);
}

.phase-badge {
  padding: 0.25rem 0.75rem;
  border-radius: 0.5rem;
  background-color: var(--color-info);
  color: var(--color-info-content);
  font-size: 0.875rem;
  font-weight: 700;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
}

.info-no-record {
  font-size: 0.8125rem;
  color: color-mix(in oklch, var(--color-base-content) 50%, transparent);
  font-style: italic;
  flex: 1;
}

.info-actions {
  display: flex;
  gap: 0.5rem;
}

.action-icon-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 2rem;
  height: 2rem;
  border-radius: 0.5rem;
  border: none;
  cursor: pointer;
  transition: all 0.2s;
  flex-shrink: 0;
  overflow: hidden;
  padding: 0.375rem;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.1);
}

.action-icon-btn.add-btn {
  background-color: color-mix(in oklch, var(--color-success) 15%, transparent);
  color: var(--color-success);
}

.action-icon-btn.add-btn:hover {
  background-color: color-mix(in oklch, var(--color-success) 25%, transparent);
  transform: scale(1.05);
}

.action-icon-btn.view-btn {
  background-color: color-mix(in oklch, var(--color-primary) 10%, transparent);
  color: var(--color-primary);
}

.action-icon-btn.view-btn:hover {
  background-color: color-mix(in oklch, var(--color-primary) 20%, transparent);
  transform: scale(1.05);
}

.action-icon-btn.delete-btn {
  background-color: color-mix(in oklch, var(--color-error) 10%, transparent);
  color: var(--color-error);
}

.action-icon-btn.delete-btn:hover {
  background-color: color-mix(in oklch, var(--color-error) 20%, transparent);
  transform: scale(1.05);
}
</style>
