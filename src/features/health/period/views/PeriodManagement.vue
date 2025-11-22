<script setup lang="ts">
import { DateUtils } from '@/utils/date';
import { Lg } from '@/utils/debugLog';
import PeriodCalendar from '../components/PeriodCalendar.vue';
import PeriodHealthTip from '../components/PeriodHealthTip.vue';
import PeriodRecentRecord from '../components/PeriodRecentRecord.vue';
import PeriodTodayInfo from '../components/PeriodTodayInfo.vue';
import { usePeriodDailyRecords } from '../composables/usePeriodDailyRecords';
import { usePeriodPhase } from '../composables/usePeriodPhase';
import { usePeriodRecords } from '../composables/usePeriodRecords';
import PeriodDailyForm from './PeriodDailyForm.vue';
import PeriodRecordForm from './PeriodRecordForm.vue';
import PeriodSettings from './PeriodSettings.vue';
import PeriodStatsDashboard from './PeriodStatsDashboard.vue';
import type { PeriodDailyRecords, PeriodRecords } from '@/schema/health/period';

// Store
const periodStore = usePeriodStore();
const { t } = useI18n();

// Reactive state
const currentView = ref<'calendar' | 'stats' | 'settings'>('calendar');
const selectedDate = ref(DateUtils.getTodayDate());
const editingRecord = ref<PeriodRecords | undefined>();
const editingDailyRecord = ref<PeriodDailyRecords | undefined>();

const uiState = reactive({
  showRecordForm: false,
  showDailyForm: false,
  showDeleteConfirm: false,
  deletingSerialNum: '',
});

const { currentPhase, currentPhaseLabel, daysUntilNext } = usePeriodPhase();
const periodRecords = usePeriodRecords(t);
const periodDailyRecords = usePeriodDailyRecords(t);

const todayRecord = computed(() => {
  return periodStore.periodDailyRecords.find(r => r.date.startsWith(selectedDate.value)) || null;
});

// Methods
function handleDateSelect(date: string) {
  selectedDate.value = date;
}

function openRecordForm(record?: PeriodRecords) {
  editingRecord.value = record;
  uiState.showRecordForm = true;
}

function closeRecordForm() {
  uiState.showRecordForm = false;
  editingRecord.value = undefined;
}

function openDailyForm(record?: PeriodDailyRecords) {
  editingDailyRecord.value = record;
  uiState.showDailyForm = true;
}

function closeDailyForm() {
  uiState.showDailyForm = false;
  editingDailyRecord.value = undefined;
}

// 处理日常记录的创建和更新
async function handleDailyRecordCreate(record: any) {
  await periodDailyRecords.create(record);
  closeDailyForm();
}

async function handleDailyRecordUpdate(serialNum: string, record: any) {
  await periodDailyRecords.update(serialNum, record);
  closeDailyForm();
}

async function handleDailyRecordDelete(serialNum: string) {
  await periodDailyRecords.remove(serialNum);
  closeDailyForm();
}

// 处理经期记录的创建和更新
async function handleRecordCreate(record: any) {
  await periodRecords.create(record);
  closeRecordForm();
}

async function handleRecordUpdate(serialNum: string, record: any) {
  await periodRecords.update(serialNum, record);
  closeRecordForm();
}

async function handleRecordDelete(serialNum: string) {
  await periodRecords.remove(serialNum);
  closeRecordForm();
}

// 删除确认处理
async function confirmDelete() {
  if (uiState.deletingSerialNum) {
    await periodDailyRecords.remove(uiState.deletingSerialNum);
    uiState.showDeleteConfirm = false;
    uiState.deletingSerialNum = '';
  }
}

function handleDeleteDailyRecord(serialNum: string) {
  uiState.deletingSerialNum = serialNum;
  uiState.showDeleteConfirm = true;
}

function closeDeleteConfirm() {
  uiState.showDeleteConfirm = false;
  uiState.deletingSerialNum = '';
}

// Lifecycle
onMounted(async () => {
  periodStore.initialize();
  try {
    await periodStore.periodRecordAll();
    await periodStore.periodDailyRecorAll();
  } catch (error) {
    Lg.e('PeriodManagement', 'Failed to load period data:', error);
  }
});
</script>

<template>
  <div class="period-management">
    <!-- 头部导航 -->
    <div class="header-section">
      <div class="header-container">
        <div class="header-content">
          <div class="nav-tabs-container">
            <button
              class="nav-tab" :class="{ 'nav-tab-active': currentView === 'calendar' }"
              @click="currentView = 'calendar'"
            >
              <LucideCalendarCheck class="nav-tab-icon" />
              <span class="nav-tab-text">{{ t('period.navigation.calendar') }}</span>
            </button>
            <button
              class="nav-tab" :class="{ 'nav-tab-active': currentView === 'stats' }"
              @click="currentView = 'stats'"
            >
              <LucideActivity class="nav-tab-icon" />
              <span class="nav-tab-text">{{ t('period.navigation.statistics') }}</span>
            </button>
            <button
              class="nav-tab" :class="{ 'nav-tab-active': currentView === 'settings' }"
              @click="currentView = 'settings'"
            >
              <LucideSettings class="nav-tab-icon" />
              <span class="nav-tab-text">{{ t('period.navigation.settings') }}</span>
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- 主要内容区域 -->
    <div class="main-content">
      <div class="mx-auto px-4 py-6 container lg:px-6">
        <!-- 统计仪表板视图 -->
        <div v-if="currentView === 'stats'" class="stats-view">
          <PeriodStatsDashboard />
        </div>

        <!-- 日历视图 -->
        <div v-else-if="currentView === 'calendar'" class="calendar-view">
          <!-- 第一行：日历占1/2，今日信息+快速操作占1/2 -->
          <div class="calendar-grid">
            <!-- 日历组件 -->
            <div class="calendar-card">
              <PeriodCalendar :selected-date="selectedDate" @date-select="handleDateSelect" />
            </div>

            <!-- 今日信息和快速操作 -->
            <div class="today-info-grid">
              <!-- 今日信息组件 -->
              <PeriodTodayInfo
                :current-phase-label="currentPhaseLabel"
                :days-until-next="daysUntilNext"
                :today-record="todayRecord"
                @view-record="openDailyForm"
                @delete-record="handleDeleteDailyRecord"
                @add-record="openDailyForm()"
              />

              <div class="card-base">
                <PeriodHealthTip :stats="currentPhase" />
              </div>
            </div>
          </div>
          <PeriodRecentRecord @add-record="openRecordForm()" @edit-record="openRecordForm($event)" />
        </div>

        <!-- 设置视图 -->
        <div v-else-if="currentView === 'settings'" class="settings-view">
          <div class="settings-card">
            <PeriodSettings />
          </div>
        </div>
      </div>
    </div>

    <!-- 经期记录表单弹窗 -->
    <div
      v-if="uiState.showRecordForm"
      class="modal-overlay"
      @click.self="closeRecordForm"
    >
      <div class="modal-content">
        <PeriodRecordForm
          :record="editingRecord"
          @create="handleRecordCreate"
          @update="handleRecordUpdate"
          @delete="handleRecordDelete"
          @cancel="closeRecordForm"
        />
      </div>
    </div>

    <!-- 日常记录表单弹窗 -->
    <div
      v-if="uiState.showDailyForm"
      class="modal-overlay"
      @click.self="closeDailyForm"
    >
      <div class="modal-content">
        <PeriodDailyForm
          :date="selectedDate"
          :record="editingDailyRecord"
          @create="handleDailyRecordCreate"
          @update="handleDailyRecordUpdate"
          @delete="handleDailyRecordDelete"
          @cancel="closeDailyForm"
        />
      </div>
    </div>

    <!-- 删除确认弹窗 -->
    <div v-if="uiState.showDeleteConfirm" class="delete-modal-overlay" @click.self="closeDeleteConfirm">
      <div class="delete-modal-content">
        <div class="delete-modal-body">
          <!-- 图标 -->
          <div class="delete-modal-icon-wrapper">
            <div class="delete-modal-icon-bg">
              <LucideTrash class="delete-modal-icon" />
            </div>
          </div>
          <!-- 标题 -->
          <h3 class="delete-modal-title">
            {{ t('period.confirmations.deleteRecord') }}
          </h3>
          <!-- 描述 -->
          <p class="delete-modal-description">
            {{ t('period.confirmations.deleteWarning') }}
          </p>
          <!-- 操作按钮 -->
          <div class="delete-modal-actions">
            <button
              class="delete-modal-btn delete-modal-btn-cancel"
              @click="closeDeleteConfirm"
            >
              <LucideX class="delete-modal-btn-icon" />
              <span>取消</span>
            </button>
            <button
              class="delete-modal-btn delete-modal-btn-confirm"
              @click="confirmDelete"
            >
              <LucideCheck class="delete-modal-btn-icon" />
              <span>确认</span>
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- 加载状态 -->
    <div v-if="periodStore.loading" class="loading-overlay">
      <div class="loading-content">
        <div class="loading-spinner" />
        <span class="loading-text"> {{ t('common.processing') }} </span>
      </div>
    </div>
  </div>
</template>

<style scoped lang="postcss">
.period-management {
  min-height: 100vh;
}

.dark .period-management {
  background: linear-gradient(to bottom right, #111827, #1f2937);
}

.header-section {
  background-color: var(--color-base-200);
  backdrop-filter: blur(8px);
  border-bottom: 1px solid #e5e7eb;
  position: sticky;
  top: 0;
  z-index: 10;
}

.dark .header-section {
  background-color: rgba(31, 41, 55, 0.8);
  border-bottom-color: #374151;
}

.container {
  max-width: 80rem;
}

/* 头部容器 */
.header-container {
  margin: 0 auto;
  padding: 0 1rem;
  max-width: 80rem;
}

@media (min-width: 1024px) {
  .header-container {
    padding: 0 1.5rem;
  }
}

/* 头部内容 */
.header-content {
  padding: 0.25rem 0;
  display: flex;
  align-items: center;
  justify-content: flex-end;
}

/* 导航标签容器 */
.nav-tabs-container {
  padding: 0.25rem;
  border-radius: 0.5rem;
  background-color: var(--color-base-200);
  display: flex;
  gap: 0.25rem;
  align-items: center;
}

/* 日历视图 */
.calendar-view {
  padding: 1.5rem 0;
}

.calendar-view > * + * {
  margin-top: 1.5rem;
}

/* 日历网格 */
.calendar-grid {
  display: grid;
  grid-template-columns: 1fr;
  gap: 1.5rem;
}

@media (min-width: 1024px) {
  .calendar-grid {
    grid-template-columns: 1fr 1fr;
  }
}

/* 日历卡片 */
.calendar-card {
  padding: 1.5rem;
  background-color: var(--color-base-100);
  border: 1px solid var(--color-base-300);
  border-radius: 0.5rem;
  box-shadow: 0 1px 2px 0 rgba(0, 0, 0, 0.05);
}

/* 今日信息网格 */
.today-info-grid {
  display: grid;
  grid-template-columns: 1fr;
  gap: 1rem;
}

@media (min-width: 768px) {
  .today-info-grid {
    grid-template-columns: 1fr 1fr;
  }
}

/* 今日信息卡片 */
.today-info-card {
  padding: 1.5rem;
  background-color: var(--color-base-100);
  border: 1px solid var(--color-base-300);
  border-radius: 0.5rem;
  box-shadow: 0 1px 2px 0 rgba(0, 0, 0, 0.05);
}

/* 今日信息头部 */
.today-info-header {
  margin-bottom: 1.5rem;
  display: flex;
  gap: 0.75rem;
  align-items: center;
}

/* 今日信息图标 */
.today-info-icon {
  background: linear-gradient(to right, var(--color-info), var(--color-info));
  border-radius: 50%;
  display: flex;
  height: 2.5rem;
  width: 2.5rem;
  align-items: center;
  justify-content: center;
}

.today-info-icon-svg {
  color: var(--color-info-content);
  height: 1.25rem;
  width: 1.25rem;
}

/* 今日信息标题 */
.today-info-title {
  font-size: 1.125rem;
  color: var(--color-base-content);
  font-weight: 600;
}

/* 今日信息内容 */
.today-info-content {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

/* 信息操作 */
.info-actions {
  display: flex;
  gap: 0.5rem;
  align-items: center;
}

/* 信息无记录 */
.info-no-record {
  font-size: 0.875rem;
  color: var(--color-neutral-content);
}

/* 设置卡片 */
.settings-card {
  padding: 1.5rem;
  background-color: var(--color-base-100);
  border: 1px solid var(--color-base-300);
  border-radius: 0.5rem;
  box-shadow: 0 1px 2px 0 rgba(0, 0, 0, 0.05);
}

/* ==================== 删除确认弹窗样式 ==================== */
.delete-modal-overlay {
  position: fixed;
  inset: 0;
  background-color: rgba(0, 0, 0, 0.6);
  backdrop-filter: blur(4px);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 9999;
  padding: 1rem;
  animation: modalFadeIn 0.2s ease-out;
}

@keyframes modalFadeIn {
  from {
    opacity: 0;
  }
  to {
    opacity: 1;
  }
}

.delete-modal-content {
  background-color: var(--color-base-100);
  border-radius: 1rem;
  max-width: 400px;
  width: 100%;
  box-shadow: 0 20px 25px -5px color-mix(in oklch, var(--color-base-content) 10%, transparent),
              0 10px 10px -5px color-mix(in oklch, var(--color-base-content) 4%, transparent);
  animation: modalSlideUp 0.3s cubic-bezier(0.34, 1.56, 0.64, 1);
  overflow: hidden;
  border: 1px solid var(--color-base-300);
}

@keyframes modalSlideUp {
  from {
    opacity: 0;
    transform: translateY(20px) scale(0.95);
  }
  to {
    opacity: 1;
    transform: translateY(0) scale(1);
  }
}

.delete-modal-body {
  padding: 2rem;
  text-align: center;
}

/* 图标样式 */
.delete-modal-icon-wrapper {
  display: flex;
  justify-content: center;
  margin-bottom: 1.5rem;
}

.delete-modal-icon-bg {
  width: 4rem;
  height: 4rem;
  border-radius: 50%;
  background: color-mix(in oklch, var(--color-error) 15%, var(--color-base-100));
  display: flex;
  align-items: center;
  justify-content: center;
  position: relative;
  animation: iconPulse 2s ease-in-out infinite;
}

@keyframes iconPulse {
  0%, 100% {
    box-shadow: 0 0 0 0 color-mix(in oklch, var(--color-error) 40%, transparent);
  }
  50% {
    box-shadow: 0 0 0 10px color-mix(in oklch, var(--color-error) 0%, transparent);
  }
}

.delete-modal-icon {
  width: 2rem;
  height: 2rem;
  color: var(--color-error);
}

/* 标题样式 */
.delete-modal-title {
  font-size: 1.25rem;
  font-weight: 700;
  color: var(--color-base-content);
  margin-bottom: 0.75rem;
  line-height: 1.4;
}

/* 描述样式 */
.delete-modal-description {
  font-size: 0.9375rem;
  color: var(--color-base-content);
  opacity: 0.8;
  margin-bottom: 2rem;
  line-height: 1.6;
}

/* 按钮容器 */
.delete-modal-actions {
  display: flex;
  gap: 0.75rem;
}

/* 按钮基础样式 */
.delete-modal-btn {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  padding: 0.75rem 1.5rem;
  border-radius: 0.5rem;
  font-size: 0.9375rem;
  font-weight: 600;
  border: none;
  cursor: pointer;
  transition: all 0.2s ease;
  position: relative;
  overflow: hidden;
}

.delete-modal-btn::before {
  content: '';
  position: absolute;
  top: 50%;
  left: 50%;
  width: 0;
  height: 0;
  border-radius: 50%;
  background: color-mix(in oklch, var(--color-base-100) 30%, transparent);
  transform: translate(-50%, -50%);
  transition: width 0.6s, height 0.6s;
}

.delete-modal-btn:hover::before {
  width: 300px;
  height: 300px;
}

.delete-modal-btn-icon {
  width: 1.125rem;
  height: 1.125rem;
  position: relative;
  z-index: 1;
}

.delete-modal-btn span {
  position: relative;
  z-index: 1;
}

/* 取消按钮 */
.delete-modal-btn-cancel {
  background-color: var(--color-neutral);
  color: var(--color-neutral-content);
}

.delete-modal-btn-cancel:hover {
  background-color: color-mix(in oklch, var(--color-neutral) 80%, black);
  transform: translateY(-2px);
  box-shadow: 0 4px 12px color-mix(in oklch, var(--color-neutral) 30%, transparent);
}

.delete-modal-btn-cancel:active {
  transform: translateY(0);
}

/* 确认按钮 */
.delete-modal-btn-confirm {
  background-color: var(--color-error);
  color: var(--color-error-content);
}

.delete-modal-btn-confirm:hover {
  background-color: color-mix(in oklch, var(--color-error) 85%, black);
  transform: translateY(-2px);
  box-shadow: 0 8px 16px color-mix(in oklch, var(--color-error) 40%, transparent);
}

.delete-modal-btn-confirm:active {
  transform: translateY(0);
}

/* 响应式 */
@media (max-width: 640px) {
  .delete-modal-body {
    padding: 1.5rem;
  }

  .delete-modal-title {
    font-size: 1.125rem;
  }

  .delete-modal-description {
    font-size: 0.875rem;
    margin-bottom: 1.5rem;
  }

  .delete-modal-actions {
    flex-direction: column-reverse;
  }

  .delete-modal-btn {
    width: 100%;
  }
}

/* 加载覆盖层 */
.loading-overlay {
  background-color: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  inset: 0;
  justify-content: center;
  position: fixed;
  z-index: 50;
}

/* 加载内容 */
.loading-content {
  padding: 1.5rem;
  border-radius: 0.5rem;
  background-color: var(--color-base-100);
  display: flex;
  gap: 0.75rem;
  align-items: center;
  box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04);
}

/* 加载旋转器 */
.loading-spinner {
  border: 2px solid var(--color-info);
  border-top-color: transparent;
  border-radius: 50%;
  height: 1.5rem;
  width: 1.5rem;
  animation: spin 1s linear infinite;
}

/* 加载文本 */
.loading-text {
  color: var(--color-base-content);
}

/* 旋转动画 */
@keyframes spin {
  to {
    transform: rotate(360deg);
  }
}

.nav-tab {
  padding: 0.5rem 0.75rem;
  font-size: 0.875rem;
  font-weight: 500;
  border-radius: 0.375rem;
  transition: all 0.2s ease-in-out;
  display: flex;
  align-items: center;
  gap: 0.5rem;
  color: #4b5563;
}

.nav-tab:hover {
  color: #111827;
}

.dark .nav-tab {
  color: #9ca3af;
}

.dark .nav-tab:hover {
  color: white;
}

.main-content {
  flex: 1;
}

.card-base {
  backdrop-filter: blur(8px);
  border: 1px solid #e5e7eb;
  border-radius: 0.75rem;
  box-shadow: 0 1px 2px 0 rgba(0, 0, 0, 0.05);
  transition: box-shadow 0.2s ease-in-out;
}

.card-base:hover {
  box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06);
}

.dark .card-base {
  border-color: #374151;
}

.action-btn {
  width: 100%;
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 0.75rem 1rem;
  border-radius: 0.5rem;
  border: 2px solid;
  transition: all 0.2s ease-in-out;
  font-size: 0.875rem;
  font-weight: 500;
}

.action-btn:hover {
  box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06);
}

.action-btn:focus {
  outline: none;
  box-shadow: 0 0 0 2px, 0 0 0 4px rgba(0, 0, 0, 0.1);
}

.period-btn {
  border-color: #bbf7d0;
  background: linear-gradient(to right, #f0fdf4, #ecfdf5);
  color: #15803d;
}

.period-btn:hover {
  background: linear-gradient(to right, #dcfce7, #d1fae5);
}

.dark .period-btn {
  border-color: #166534;
  background: linear-gradient(to right, rgba(69, 26, 3, 0.2), rgba(69, 26, 3, 0.2));
  color: #4ade80;
}

.dark .period-btn:hover {
  background: linear-gradient(to right, rgba(69, 26, 3, 0.3), rgba(69, 26, 3, 0.3));
}

.period-btn:focus {
  box-shadow: 0 0 0 2px #22c55e, 0 0 0 4px rgba(34, 197, 94, 0.1);
}

.daily-btn {
  border-color: #bfdbfe;
  background: linear-gradient(to right, #eff6ff, #dbeafe);
  color: #1d4ed8;
}

.daily-btn:hover {
  background: linear-gradient(to right, #dbeafe, #bfdbfe);
}

.dark .daily-btn {
  border-color: #1e3a8a;
  background: linear-gradient(to right, rgba(30, 58, 138, 0.2), rgba(30, 58, 138, 0.2));
  color: #60a5fa;
}

.dark .daily-btn:hover {
  background: linear-gradient(to right, rgba(30, 58, 138, 0.3), rgba(30, 58, 138, 0.3));
}

.daily-btn:focus {
  box-shadow: 0 0 0 2px #3b82f6, 0 0 0 4px rgba(59, 130, 246, 0.1);
}

.stats-btn {
  border-color: #bbf7d0;
  background: linear-gradient(to right, #f0fdf4, #ecfdf5);
  color: #15803d;
}

.stats-btn:hover {
  background: linear-gradient(to right, #dcfce7, #d1fae5);
}

.dark .stats-btn {
  border-color: #166534;
  background: linear-gradient(to right, rgba(69, 26, 3, 0.2), rgba(69, 26, 3, 0.2));
  color: #4ade80;
}

.dark .stats-btn:hover {
  background: linear-gradient(to right, rgba(69, 26, 3, 0.3), rgba(69, 26, 3, 0.3));
}

.stats-btn:focus {
  box-shadow: 0 0 0 2px #22c55e, 0 0 0 4px rgba(34, 197, 94, 0.1);
}

.action-icon-btn {
  width: 2rem;
  height: 2rem;
  border-radius: 0.5rem;
  display: flex;
  align-items: center;
  justify-content: center;
  transition: all 0.2s ease-in-out;
}

.action-icon-btn:hover {
  transform: scale(1.1);
}

.action-icon-btn:focus {
  outline: none;
  box-shadow: 0 0 0 2px, 0 0 0 4px rgba(0, 0, 0, 0.1);
}

.view-btn {
  background-color: #eff6ff;
  color: #2563eb;
}

.view-btn:hover {
  background-color: #dbeafe;
}

.dark .view-btn {
  background-color: rgba(30, 58, 138, 0.3);
  color: #60a5fa;
}

.dark .view-btn:hover {
  background-color: rgba(30, 58, 138, 0.5);
}

.view-btn:focus {
  box-shadow: 0 0 0 2px #3b82f6, 0 0 0 4px rgba(59, 130, 246, 0.1);
}

.delete-btn {
  background-color: #fef2f2;
  color: #dc2626;
}

.delete-btn:hover {
  background-color: #fee2e2;
}

.dark .delete-btn {
  background-color: rgba(69, 10, 10, 0.3);
  color: #f87171;
}

.dark .delete-btn:hover {
  background-color: rgba(69, 10, 10, 0.5);
}

.delete-btn:focus {
  box-shadow: 0 0 0 2px #ef4444, 0 0 0 4px rgba(239, 68, 68, 0.1);
}

.info-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.info-label {
  font-size: 0.875rem;
  font-weight: 500;
  color: #4b5563;
}

.dark .info-label {
  color: #9ca3af;
}

.info-value {
  font-size: 0.875rem;
  font-weight: 600;
  color: #111827;
}

.dark .info-value {
  color: white;
}

.phase-badge {
  padding: 0.25rem 0.75rem;
  background: linear-gradient(to right, #fce7f3, #f3e8ff);
  color: #be185d;
  border-radius: 9999px;
  font-size: 0.75rem;
  font-weight: 500;
}

.dark .phase-badge {
  background: linear-gradient(to right, rgba(157, 23, 77, 0.3), rgba(147, 51, 234, 0.3));
  color: #f472b6;
}

.tip-item {
  padding: 1rem;
  background-color: #f9fafb;
  border-radius: 0.5rem;
  border: 1px solid #f3f4f6;
  transition: box-shadow 0.2s ease-in-out;
}

.tip-item:hover {
  box-shadow: 0 1px 2px 0 rgba(0, 0, 0, 0.05);
}

.dark .tip-item {
  background-color: rgba(55, 65, 81, 0.5);
  border-color: #4b5563;
}

.modal-overlay {
  position: fixed;
  inset: 0;
  background-color: rgba(0, 0, 0, 0.5);
  backdrop-filter: blur(8px);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 50;
  padding: 1rem;
  animation: fadeIn 0.2s ease-out;
}

.modal-content {
  background-color: white;
  border-radius: 0.75rem;
  max-width: 28rem;
  width: 100%;
  max-height: 90vh;
  overflow-y: auto;
  box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25);
  animation: slideUp 0.2s ease-out;
}

.dark .modal-content {
  background-color: #1f2937;
}

@keyframes fadeIn {
  from {
    opacity: 0;
  }

  to {
    opacity: 1;
  }
}

@keyframes slideUp {
  from {
    opacity: 0;
    transform: translateY(20px);
  }

  to {
    opacity: 1;
    transform: translateY(0);
  }
}

/* 响应式设计 */
@media (max-width: 1024px) {
  .grid.lg\\:grid-cols-2 {
    grid-template-columns: 1fr;
    gap: 1rem;
  }

  .nav-tab {
    padding: 0.375rem 0.5rem;
    font-size: 0.75rem;
  }
}

@media (max-width: 768px) {
  .grid.md\\:grid-cols-2 {
    grid-template-columns: 1fr;
    gap: 1rem;
  }

  .container {
    padding: 0 0.75rem;
  }

  .card-base {
    padding: 1rem;
  }

  .action-btn {
    padding: 0.625rem 0;
    font-size: 0.75rem;
  }

  .modal-content {
    margin: 0 0.5rem;
    max-width: none;
  }
}

/* 移动端适配 - 关键修复：保持导航在一行 */
@media (max-width: 640px) {

  /* 确保头部容器保持水平布局 */
  .header-section .container>.flex {
    display: flex;
    flex-direction: row;
    align-items: center;
    justify-content: space-between;
    gap: 0.5rem;
  }

  /* 左侧标题区域 */
  .header-section .flex.items-center.gap-2 {
    gap: 0.25rem;
    flex-shrink: 0;
  }

  .header-section h1 {
    font-size: 1rem;
  }

  /* 右侧导航区域 - 保持水平排列 */
  .header-section .flex.items-center.gap-1.bg-gray-100 {
    flex: 1;
    max-width: 180px;
    gap: 0.125rem;
    padding: 0.125rem;
  }

  /* 导航标签 - 水平排列 */
  .nav-tab {
    padding: 0.375rem 0.25rem;
    font-size: 0.75rem;
    flex: 1;
    justify-content: center;
    min-width: 0;
  }

  /* 只在移动端隐藏文字 */
  .nav-tab span.hidden.sm\\:inline {
    display: none;
  }

  /* 确保图标居中 */
  .nav-tab .w-4.h-4 {
    margin: 0 auto;
  }

  /* 主要内容区域调整 */
  .main-content .container {
    padding: 1rem 0.75rem;
  }

  /* 卡片内边距调整 */
  .card-base {
    padding: 0.75rem;
  }

  /* 按钮调整 */
  .action-btn {
    padding: 0.5rem 0;
    font-size: 0.75rem;
    gap: 0.5rem;
  }

  /* 图标按钮调整 */
  .action-icon-btn {
    width: 1.75rem;
    height: 1.75rem;
  }

  /* 提示卡片在移动端堆叠 */
  .tip-item {
    padding: 0.75rem;
  }
}

/* 滚动条样式 */
.scrollbar-hide {
  -ms-overflow-style: none;
  scrollbar-width: none;
}

.scrollbar-hide::-webkit-scrollbar {
  display: none;
}
</style>
