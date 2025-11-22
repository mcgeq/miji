<script setup lang="ts">
import PeriodCalendar from '@/features/health/period/components/PeriodCalendar.vue';
import PeriodTodayInfo from '@/features/health/period/components/PeriodTodayInfo.vue';
import { usePeriodPhase } from '@/features/health/period/composables/usePeriodPhase';
import PeriodDailyForm from '@/features/health/period/views/PeriodDailyForm.vue';
import { DateUtils } from '@/utils/date';
import type { PeriodDailyRecordCreate, PeriodDailyRecords, PeriodDailyRecordUpdate } from '@/schema/health/period';

const periodStore = usePeriodStore();
const { currentPhaseLabel, daysUntilNext } = usePeriodPhase();

const selectedDate = ref(DateUtils.getTodayDate());
const showDailyForm = ref(false);
const editingDailyRecord = ref<PeriodDailyRecords | undefined>();

const todayRecord = computed(() => {
  return periodStore.periodDailyRecords.find(r => r.date.startsWith(DateUtils.getTodayDate())) || null;
});

function handleDateSelect(date: string) {
  selectedDate.value = date;
}

function openDailyForm(record?: PeriodDailyRecords) {
  editingDailyRecord.value = record;
  showDailyForm.value = true;
}

function closeDailyForm() {
  showDailyForm.value = false;
  editingDailyRecord.value = undefined;
}

async function handleDailyCreate(data: PeriodDailyRecordCreate) {
  await periodStore.periodDailyRecordCreate(data);
  closeDailyForm();
}

async function handleDailyUpdate(serialNum: string, data: PeriodDailyRecordUpdate) {
  await periodStore.periodDailyRecordUpdate(serialNum, data);
  closeDailyForm();
}

async function handleDailyDelete(serialNum: string) {
  await periodStore.periodDailyRecordDelete(serialNum);
  closeDailyForm();
}
</script>

<template>
  <div class="today-period">
    <!-- 日历组件 -->
    <div class="calendar-card">
      <PeriodCalendar :selected-date="selectedDate" @date-select="handleDateSelect" />
    </div>

    <!-- 今日信息组件 -->
    <div class="today-info-wrapper">
      <PeriodTodayInfo
        :current-phase-label="currentPhaseLabel"
        :days-until-next="daysUntilNext"
        :today-record="todayRecord"
        @view-record="openDailyForm"
        @delete-record="handleDailyDelete"
        @add-record="openDailyForm()"
      />
    </div>

    <!-- 每日记录表单弹窗 -->
    <PeriodDailyForm
      v-if="showDailyForm"
      :record="editingDailyRecord"
      @create="handleDailyCreate"
      @update="handleDailyUpdate"
      @delete="handleDailyDelete"
      @cancel="closeDailyForm"
    />
  </div>
</template>

<style scoped lang="postcss">
.today-period {
  width: 100%;
  display: flex;
  flex-direction: row;
  gap: 0.75rem;
  padding: 0.75rem;
  overflow: hidden;
}

/* 今日信息包装容器 */
.today-info-wrapper {
  flex-shrink: 0;
  width: 22rem;
  align-self: stretch;
  min-height: 0;
  display: flex;
  flex-direction: column;
}

/* 移动端布局：上下排列 */
@media (max-width: 768px) {
  .today-period {
    flex-direction: column;
    gap: 0.5rem;
    padding: 0.5rem;
  }

  .today-info-wrapper {
    width: 100%;
  }
}
</style>
