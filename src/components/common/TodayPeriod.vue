<script setup lang="ts">
import { usePeriodPhase } from '@/features/health/period/composables/usePeriodPhase';
import PeriodDailyForm from '@/features/health/period/views/PeriodDailyForm.vue';
import { DateUtils } from '@/utils/date';
import type { PeriodDailyRecordCreate, PeriodDailyRecords, PeriodDailyRecordUpdate } from '@/schema/health/period';

const periodStore = usePeriodStore();
const { currentPhaseLabel, daysUntilNext } = usePeriodPhase();

const selectedDate = ref(DateUtils.getTodayDate());
const currentDate = ref(DateUtils.getCurrentDate());
const showDailyForm = ref(false);
const editingDailyRecord = ref<PeriodDailyRecords | undefined>();

const todayRecord = computed(() => {
  return periodStore.periodDailyRecords.find(r => r.date.startsWith(selectedDate.value)) || null;
});

const isToday = computed(() => {
  return selectedDate.value === DateUtils.getTodayDate();
});

const isCurrentMonth = computed(() => {
  const today = new Date();
  const current = currentDate.value;
  return today.getFullYear() === current.getFullYear() && today.getMonth() === current.getMonth();
});

const currentMonthYear = computed(() => {
  const year = currentDate.value.getFullYear();
  const month = currentDate.value.getMonth() + 1;
  return `${year}年${month}月`;
});

const weekDays = ['日', '一', '二', '三', '四', '五', '六'];

// 格式化日期为 YYYY-MM-DD
function formatDateToString(date: Date): string {
  const yyyy = date.getFullYear();
  const mm = String(date.getMonth() + 1).padStart(2, '0');
  const dd = String(date.getDate()).padStart(2, '0');
  return `${yyyy}-${mm}-${dd}`;
}

// 简化的日历数据
const calendarDays = computed(() => {
  const year = currentDate.value.getFullYear();
  const month = currentDate.value.getMonth();
  const firstDay = new Date(year, month, 1);
  const lastDay = new Date(year, month + 1, 0);
  const startDate = new Date(firstDay);
  startDate.setDate(startDate.getDate() - firstDay.getDay());
  const endDate = new Date(lastDay);
  endDate.setDate(endDate.getDate() + (6 - lastDay.getDay()));
  const days = [];
  const today = DateUtils.getTodayDate();
  const current = new Date(startDate);
  while (current.getTime() <= endDate.getTime()) {
    const dateStr = formatDateToString(current);
    const isCurrentMonth = current.getMonth() === month;
    const isToday = dateStr === today;
    days.push({
      date: dateStr,
      day: current.getDate(),
      isCurrentMonth,
      isToday,
    });
    current.setDate(current.getDate() + 1);
  }
  return days;
});

function previousMonth() {
  currentDate.value = new Date(currentDate.value.getFullYear(), currentDate.value.getMonth() - 1, 1);
}

function nextMonth() {
  currentDate.value = new Date(currentDate.value.getFullYear(), currentDate.value.getMonth() + 1, 1);
}

function selectDate(date: string) {
  selectedDate.value = date;
}

function goToToday() {
  const today = DateUtils.getTodayDate();
  selectedDate.value = today;
  currentDate.value = DateUtils.getCurrentDate();
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
    <!-- 迷你日历 -->
    <div class="mini-calendar">
      <div class="calendar-header">
        <button class="nav-btn" @click="previousMonth">
          <LucideChevronLeft class="icon" />
        </button>
        <div class="header-center">
          <span class="month-label">{{ currentMonthYear }}</span>
          <button
            v-if="!isToday || !isCurrentMonth"
            class="today-btn"
            title="返回今日"
            @click="goToToday"
          >
            今天
          </button>
        </div>
        <button class="nav-btn" @click="nextMonth">
          <LucideChevronRight class="icon" />
        </button>
      </div>
      <div class="weekdays">
        <div v-for="day in weekDays" :key="day" class="weekday">
          {{ day }}
        </div>
      </div>
      <div class="days-grid">
        <button
          v-for="day in calendarDays"
          :key="day.date"
          class="day-cell"
          :class="{
            'other-month': !day.isCurrentMonth,
            'today': day.isToday,
            'selected': day.date === selectedDate,
          }"
          @click="selectDate(day.date)"
        >
          {{ day.day }}
        </button>
      </div>
    </div>

    <!-- 今日信息 -->
    <div class="today-info">
      <div class="info-header">
        <LucideCalendarCheck class="header-icon" />
        <h3 class="header-title">
          今日信息
        </h3>
      </div>
      <div class="info-content">
        <div class="info-row">
          <span class="info-label">当前阶段</span>
          <span class="info-value phase-badge">{{ currentPhaseLabel }}</span>
        </div>
        <div class="info-row">
          <span class="info-label">距离下次</span>
          <span class="info-value">{{ daysUntilNext }}</span>
        </div>
        <div class="info-row">
          <span class="info-label">今日记录</span>
          <div v-if="!todayRecord" class="info-actions">
            <button class="info-action-btn add-btn" title="添加记录" @click="openDailyForm()">
              <LucidePlus class="btn-icon" />
            </button>
          </div>
          <div v-else class="info-actions">
            <button class="info-action-btn view-btn" title="查看记录" @click="openDailyForm(todayRecord)">
              <LucideEye class="btn-icon" />
            </button>
            <button class="info-action-btn delete-btn" title="删除记录" @click="handleDailyDelete(todayRecord.serialNum)">
              <LucideTrash2 class="btn-icon" />
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- 每日记录表单弹窗 -->
    <Teleport to="body">
      <Transition name="modal-fade">
        <div
          v-if="showDailyForm"
          class="modal-overlay"
          @click.self="closeDailyForm"
        >
          <div class="modal-content">
            <PeriodDailyForm
              :record="editingDailyRecord"
              @create="handleDailyCreate"
              @update="handleDailyUpdate"
              @delete="handleDailyDelete"
              @cancel="closeDailyForm"
            />
          </div>
        </div>
      </Transition>
    </Teleport>
  </div>
</template>

<style scoped lang="postcss">
.today-period {
  width: 100%;
  height: 100%;
  display: flex;
  flex-direction: row;
  gap: 0.75rem;
  padding: 0.75rem;
  overflow: hidden;
}

/* 迷你日历 */
.mini-calendar {
  flex: 1;
  display: flex;
  flex-direction: column;
  min-height: 0;
  min-width: 0;
  border: 1px solid var(--color-base-300);
}

.calendar-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 0.5rem;
  padding: 0 0.25rem;
}

.header-center {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.nav-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 1.5rem;
  height: 1.5rem;
  border-radius: 0.375rem;
  background-color: transparent;
  border: none;
  cursor: pointer;
  transition: all 0.2s;
  color: var(--color-base-content);
}

.nav-btn:hover {
  background-color: var(--color-base-200);
}

.nav-btn .icon {
  width: 1rem;
  height: 1rem;
}

.month-label {
  font-size: 0.875rem;
  font-weight: 600;
  color: var(--color-base-content);
}

.today-btn {
  padding: 0.2rem 0.4rem;
  font-size: 0.6rem;
  font-weight: 500;
  border-radius: 0.375rem;
  border: none;
  cursor: pointer;
  transition: all 0.2s;
  background-color: color-mix(in oklch, var(--color-info) 15%, transparent);
  color: var(--color-info);
}

.today-btn:hover {
  background-color: color-mix(in oklch, var(--color-info) 25%, transparent);
  transform: scale(1.05);
}

.weekdays {
  display: grid;
  grid-template-columns: repeat(7, 1fr);
  gap: 0.25rem;
  margin-bottom: 0.375rem;
}

.weekday {
  text-align: center;
  font-size: 0.75rem;
  font-weight: 500;
  color: color-mix(in oklch, var(--color-base-content) 60%, transparent);
  padding: 0.25rem 0;
}

.days-grid {
  display: grid;
  grid-template-columns: repeat(7, 1fr);
  gap: 0.25rem;
  flex: 1;
  min-height: 0;
  align-content: start;
}

.day-cell {
  aspect-ratio: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 0.75rem;
  border-radius: 0.375rem;
  border: none;
  background-color: transparent;
  color: var(--color-base-content);
  cursor: pointer;
  transition: all 0.2s;
  padding: 0.25rem;
  min-height: 1.5rem;
}

.day-cell:hover {
  background-color: color-mix(in oklch, var(--color-info) 10%, transparent);
}

.day-cell.other-month {
  color: color-mix(in oklch, var(--color-base-content) 30%, transparent);
}

.day-cell.today {
  background-color: var(--color-info);
  color: var(--color-info-content);
  font-weight: 600;
}

.day-cell.selected {
  background-color: var(--color-primary);
  color: var(--color-primary-content);
  font-weight: 600;
}

/* 今日信息 */
.today-info {
  flex-shrink: 0;
  width: 10rem;
  border: 1px solid var(--color-base-300);
  background-color: color-mix(in oklch, var(--color-base-200) 50%, transparent);
  border-radius: 0.75rem;
  padding: 0.75rem;
  display: flex;
  flex-direction: column;
}

.info-header {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  margin-bottom: 0.625rem;
}

.header-icon {
  width: 1.125rem;
  height: 1.125rem;
  color: var(--color-info);
}

.header-title {
  font-size: 0.875rem;
  font-weight: 600;
  color: var(--color-base-content);
  margin: 0;
}

.info-content {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.info-row {
  display: flex;
  align-items: center;
  justify-content: space-between;
}

.info-label {
  font-size: 0.8125rem;
  color: color-mix(in oklch, var(--color-base-content) 70%, transparent);
}

.info-value {
  font-size: 0.8125rem;
  font-weight: 600;
  color: var(--color-base-content);
}

.phase-badge {
  padding: 0.125rem 0.5rem;
  border-radius: 0.375rem;
  background-color: color-mix(in oklch, var(--color-info) 15%, transparent);
  color: var(--color-info);
  font-size: 0.75rem;
}

.info-no-record {
  font-size: 0.8125rem;
  color: color-mix(in oklch, var(--color-base-content) 50%, transparent);
  font-style: italic;
  flex: 1;
}

.info-actions {
  display: flex;
  gap: 0.375rem;
}

.info-action-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 1.75rem;
  height: 1.75rem;
  border-radius: 0.5rem;
  border: none;
  cursor: pointer;
  transition: all 0.2s;
  flex-shrink: 0;
}

.info-action-btn.add-btn {
  background-color: color-mix(in oklch, var(--color-success) 15%, transparent);
  color: var(--color-success);
}

.info-action-btn.add-btn:hover {
  background-color: color-mix(in oklch, var(--color-success) 25%, transparent);
  transform: scale(1.05);
}

.info-action-btn.view-btn {
  background-color: color-mix(in oklch, var(--color-primary) 10%, transparent);
  color: var(--color-primary);
}

.info-action-btn.view-btn:hover {
  background-color: color-mix(in oklch, var(--color-primary) 20%, transparent);
  transform: scale(1.05);
}

.info-action-btn.delete-btn {
  background-color: color-mix(in oklch, var(--color-error) 10%, transparent);
  color: var(--color-error);
}

.info-action-btn.delete-btn:hover {
  background-color: color-mix(in oklch, var(--color-error) 20%, transparent);
  transform: scale(1.05);
}

.btn-icon {
  width: 1rem;
  height: 1rem;
}

/* Modal 样式 */
.modal-overlay {
  position: fixed;
  inset: 0;
  background-color: color-mix(in oklch, var(--color-neutral) 60%, transparent);
  backdrop-filter: blur(6px);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 10000;
  padding: 1rem;
}

.modal-content {
  background-color: var(--color-base-100);
  border-radius: 1rem;
  box-shadow: 0 10px 40px color-mix(in oklch, var(--color-neutral) 30%, transparent);
  border: 1px solid var(--color-base-300);
  width: 100%;
  max-width: 600px;
  max-height: 90vh;
  overflow-y: auto;
}

/* Modal 过渡动画 */
.modal-fade-enter-active,
.modal-fade-leave-active {
  transition: all 0.3s ease-in-out;
}

.modal-fade-enter-from,
.modal-fade-leave-to {
  opacity: 0;
}

.modal-fade-enter-from .modal-content,
.modal-fade-leave-to .modal-content {
  transform: scale(0.9) translateY(20px);
}

.modal-fade-enter-active .modal-content,
.modal-fade-leave-active .modal-content {
  transition: transform 0.3s ease-in-out;
}
</style>
