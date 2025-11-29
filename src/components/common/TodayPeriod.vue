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
  <div class="w-full flex flex-col md:flex-row gap-2 md:gap-3 p-2 md:p-3 overflow-hidden">
    <!-- 日历组件 -->
    <div class="flex-1">
      <PeriodCalendar :selected-date="selectedDate" @date-select="handleDateSelect" />
    </div>

    <!-- 今日信息组件 -->
    <div class="w-full md:w-88 flex-shrink-0 self-stretch min-h-0 flex flex-col">
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
