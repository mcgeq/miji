<script setup lang="ts">
import { DateUtils } from '@/utils/date';
import { Lg } from '@/utils/debugLog';
import PeriodCalendar from '../components/PeriodCalendar.vue';
import PeriodHealthTip from '../components/PeriodHealthTip.vue';
import PeriodRecentRecord from '../components/PeriodRecentRecord.vue';
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

// 1. 修改 confirmDelete 方法
function confirmDelete() {
  if (uiState.deletingSerialNum) {
    periodDailyRecords.remove(uiState.deletingSerialNum);
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

// 监控 uiState 的变化
watch(
  () => [uiState.showRecordForm, uiState.showDailyForm, uiState.showDeleteConfirm],
  async ([newShowRecordForm, newShowDailyForm, newShowDeleteConfirm], [oldShowRecordForm, oldShowDailyForm, oldShowDeleteConfirm]) => {
    // 检查是否有任一状态从 true 变为 false
    if (
      (oldShowRecordForm && !newShowRecordForm) ||
      (oldShowDailyForm && !newShowDailyForm) ||
      (oldShowDeleteConfirm && !newShowDeleteConfirm)
    ) {
      try {
        Lg.i('PeriodManagement', 'Refreshing data due to UI state change');
        await periodStore.periodRecordAll();
        await periodStore.periodDailyRecorAll();
      } catch (error) {
        Lg.e('PeriodManagement', 'Failed to refresh period data:', error);
      }
    }
  },
  { deep: true },
);

watch(
  () => [uiState.deletingSerialNum, selectedDate.value],
  async ([deletingSerialNum, currentDate]) => {
    if (deletingSerialNum === '' && currentDate) {
      const hasMatchingRecord = periodStore.periodRecords.some(record => record.startDate.startsWith(currentDate));
      if (hasMatchingRecord) {
        try {
          await periodStore.periodRecordAll();
        } catch (error) {
          Lg.e('PeriodManagement ', error);
        }
      }
    }
  },
);

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
              <!-- 今日信息 -->
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
                      <button class="action-icon-btn view-btn" title="查看记录" @click="openDailyForm(todayRecord)">
                        <LucideEye class="wh-4" />
                      </button>
                      <button
                        class="action-icon-btn delete-btn" :title="t('common.actions.delete')"
                        @click="handleDeleteDailyRecord(todayRecord.serialNum)"
                      >
                        <LucideTrash class="wh-4" />
                      </button>
                    </div>
                  </div>
                  <div v-else class="info-item">
                    <span class="info-label">{{ t('period.todayInfo.todayRecord') }}</span>
                    <span class="info-no-record">{{ t('period.todayInfo.noRecord') }}</span>

                    <div class="period-btn cursor-pointer" @click="openDailyForm()">
                      <LucidePlus class="wh-5" />
                    </div>
                  </div>
                </div>
              </div>

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
          @create="periodRecords.create"
          @update="periodRecords.update"
          @delete="periodRecords.remove"
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
          @create="periodDailyRecords.create"
          @update="periodDailyRecords.update"
          @delete="periodDailyRecords.remove"
          @cancel="closeDailyForm"
        />
      </div>
    </div>

    <!-- 删除确认弹窗 -->
    <div v-if="uiState.showDeleteConfirm" class="modal-overlay" @click.self="closeDeleteConfirm">
      <div class="modal-content max-w-sm">
        <div class="p-6">
          <div class="modal-header">
            <div class="modal-icon">
              <LucideTrash class="modal-icon-svg" />
            </div>
            <h3 class="modal-title">
              {{ t('period.confirmations.deleteRecord') }}
            </h3>
          </div>
          <p class="modal-description">
            {{ t('period.confirmations.deleteWarning') }}
          </p>
          <div class="modal-actions">
            <button
              class="btn-danger flex-1"
              @click="confirmDelete"
            >
              <LucideCheck class="wh-5" />
            </button>
            <button
              class="btn-secondary flex-1"
              @click="closeDeleteConfirm"
            >
              <LucideX class="wh-5" />
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

/* 模态框头部 */
.modal-header {
  margin-bottom: 1rem;
  display: flex;
  gap: 0.75rem;
  align-items: center;
}

/* 模态框图标 */
.modal-icon {
  border-radius: 50%;
  background-color: var(--color-error);
  display: flex;
  height: 2rem;
  width: 2rem;
  align-items: center;
  justify-content: center;
}

.modal-icon-svg {
  color: var(--color-error-content);
  width: 1rem;
  height: 1rem;
}

/* 模态框标题 */
.modal-title {
  font-size: 1.125rem;
  color: var(--color-base-content);
  font-weight: 600;
}

/* 模态框描述 */
.modal-description {
  font-size: 0.875rem;
  color: var(--color-neutral-content);
  margin-bottom: 1.5rem;
}

/* 模态框操作 */
.modal-actions {
  display: flex;
  gap: 0.75rem;
  align-items: center;
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
