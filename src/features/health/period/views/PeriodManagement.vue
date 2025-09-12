<script setup lang="ts">
import { DateUtils } from '@/utils/date';
import { Lg } from '@/utils/debugLog';
import PeriodCalendar from '../components/PeriodCalendar.vue';
import PeriodHealthTip from '../components/PeriodHealthTip.vue';
import PeriodRecentRecord from '../components/PeriodRecentRecord.vue';
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
const showRecordForm = ref(false);
const showDailyForm = ref(false);
const showDeleteConfirm = ref(false);
const showSuccessMessage = ref(false);
const successMessage = ref('');
const editingRecord = ref<PeriodRecords | undefined>();
const editingDailyRecord = ref<PeriodDailyRecords | undefined>();
const deletingSerialNum = ref<string>('');

// Computed
const currentPhase = computed(() => periodStore.periodStats);
const currentPhaseLabel = computed(() => {
  const labels = {
    Menstrual: t('period.phases.menstrual'),
    Follicular: t('period.phases.follicular'),
    Ovulation: t('period.phases.ovulation'),
    Luteal: t('period.phases.luteal'),
  };
  return labels[currentPhase.value.currentPhase];
});

const daysUntilNext = computed(() => {
  const days = periodStore.periodStats.daysUntilNext;
  if (days === 0)
    return t('period.nextPeriod.todayStart');
  if (days === 1)
    return t('period.nextPeriod.tomorrowStart');
  if (days < 0)
    return t('period.nextPeriod.delayed');
  return `${days}${t('period.nextPeriod.daysLater')}`;
});

const todayRecord = computed(() => {
  const records = periodStore.periodDailyRecords;
  const today = selectedDate.value;

  // 每次都重新查找，确保获取最新数据
  const found = records.find(record => record.date === today);

  return found || null;
});

// Methods
function handleDateSelect(date: string) {
  selectedDate.value = date;
}

function openRecordForm(record?: PeriodRecords) {
  editingRecord.value = record;
  showRecordForm.value = true;
}

function closeRecordForm() {
  showRecordForm.value = false;
  editingRecord.value = undefined;
}

async function handleRecordSubmit(record: PeriodRecords) {
  closeRecordForm();

  // 刷新数据以更新UI
  await periodStore.fetchPeriodRecords();

  showSuccessToast(t('period.messages.periodRecordSaved'));
  Lg.i('PeriodManagement', 'Record submitted:', record);
}

async function handleRecordDelete(serialNum: string) {
  closeRecordForm();

  // 刷新数据以更新UI
  await periodStore.fetchPeriodRecords();

  showSuccessToast(t('period.messages.periodRecordDeleted'));
  Lg.i('PeriodManagement', 'Record deleted:', serialNum);
}

function openDailyForm(record?: PeriodDailyRecords) {
  editingDailyRecord.value = record;
  showDailyForm.value = true;
}

function closeDailyForm() {
  showDailyForm.value = false;
  editingDailyRecord.value = undefined;
}

async function handleDailySubmit(record: PeriodDailyRecords) {
  try {
    Lg.i('PeriodManagement', 'Submitting daily record:', record);

    closeDailyForm();

    // 等待保存完成
    await periodStore.upsertDailyRecord(record);

    // 等待一个 tick 确保状态更新
    await nextTick();

    showSuccessToast(t('period.messages.dailyRecordSaved'));

    Lg.i(
      'PeriodManagement',
      'Daily record saved, total records:',
      periodStore.periodDailyRecords.length,
    );
  } catch (error) {
    Lg.e('PeriodManagement', `${t('period.saveFailed')}:`, error);
  }
}

// 删除相关方法
function handleDeleteDailyRecord(serialNum: string) {
  deletingSerialNum.value = serialNum;
  showDeleteConfirm.value = true;
}

function closeDeleteConfirm() {
  showDeleteConfirm.value = false;
  deletingSerialNum.value = '';
}

// 1. 修改 confirmDelete 方法
async function confirmDelete() {
  try {
    const deletingId = deletingSerialNum.value;

    Lg.i('PeriodManagement', 'Deleting record:', deletingId);

    // 使用专门的删除日常记录方法
    await periodStore.periodDailyRecordDelete(deletingId);

    // 等待一个 tick 确保状态更新完成
    await nextTick();

    // 强制刷新日常记录
    await periodStore.refreshDailyRecords();

    showSuccessToast(t('period.messages.recordDeleted'));
    closeDeleteConfirm();

    Lg.i(
      'PeriodManagement',
      'Delete completed, records count:',
      periodStore.periodDailyRecords.length,
    );
  } catch (error) {
    console.error(`${t('messages.deleteFailed')}:`, error);
  }
}

// 成功提示相关方法
function showSuccessToast(message: string) {
  successMessage.value = message;
  showSuccessMessage.value = true;
  setTimeout(() => {
    showSuccessMessage.value = false;
  }, 3000);
}

function hideSuccessMessage() {
  showSuccessMessage.value = false;
}

watch(
  () => periodStore.periodDailyRecords,
  (newRecords, oldRecords) => {
    Lg.i('PeriodManagement', 'Daily records changed:', {
      oldCount: oldRecords?.length || 0,
      newCount: newRecords.length,
      todayDate: selectedDate.value,
      hasTodayRecord: !!newRecords.find(r => r.date === selectedDate.value),
    });
  },
  { deep: true },
);
// Lifecycle
onMounted(async () => {
  periodStore.initialize();
  try {
    await periodStore.fetchPeriodRecords();
  } catch (error) {
    Lg.e('PeriodManagement', 'Failed to load period data:', error);
  }
});
</script>

<template>
  <div class="period-management">
    <!-- 头部导航 -->
    <div class="header-section">
      <div class="mx-auto px-4 container lg:px-6">
        <div class="py-1 flex items-center justify-end">
          <div class="p-1 rounded-lg bg-gray-100 flex gap-1 items-center dark:bg-gray-700">
            <button
              class="nav-tab" :class="{ 'nav-tab-active': currentView === 'calendar' }"
              @click="currentView = 'calendar'"
            >
              <LucideCalendarCheck class="wh-4" />
              <span class="hidden sm:inline">{{ t('period.navigation.calendar') }}</span>
            </button>
            <button
              class="nav-tab" :class="{ 'nav-tab-active': currentView === 'stats' }"
              @click="currentView = 'stats'"
            >
              <LucideActivity class="wh-4" />
              <span class="hidden sm:inline">{{ t('period.navigation.statistics') }}</span>
            </button>
            <button
              class="nav-tab" :class="{ 'nav-tab-active': currentView === 'settings' }"
              @click="currentView = 'settings'"
            >
              <LucideSettings class="wh-4" />
              <span class="hidden sm:inline">{{ t('period.navigation.settings') }}</span>
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
        <div v-else-if="currentView === 'calendar'" class="calendar-view space-y-6">
          <!-- 第一行：日历占1/2，今日信息+快速操作占1/2 -->
          <div class="gap-6 grid grid-cols-1 lg:grid-cols-2">
            <!-- 日历组件 -->
            <div class="p-6 card-base">
              <PeriodCalendar :selected-date="selectedDate" @date-select="handleDateSelect" />
            </div>

            <!-- 今日信息和快速操作 -->
            <div class="gap-4 grid grid-cols-1 md:grid-cols-2">
              <!-- 今日信息 -->
              <div class="p-6 card-base">
                <div class="mb-6 flex gap-3 items-center">
                  <div
                    class="bg-gradient-to-r rounded-full flex h-10 w-10 items-center justify-center from-blue-500 to-cyan-500"
                  >
                    <LucideCalendarCheck class="text-white h-5 w-5" />
                  </div>
                  <h3 class="text-lg text-gray-900 font-semibold dark:text-white">
                    {{ t('period.todayInfo.title') }}
                  </h3>
                </div>
                <div class="space-y-4">
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
                    <div class="flex gap-2 items-center">
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
                    <span class="text-sm text-gray-500 dark:text-gray-400">{{ t('period.todayInfo.noRecord') }}</span>

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
          <div class="p-6 card-base">
            <PeriodSettings />
          </div>
        </div>
      </div>
    </div>

    <!-- 经期记录表单弹窗 -->
    <div v-if="showRecordForm" class="modal-overlay" @click.self="closeRecordForm">
      <div class="modal-content">
        <PeriodRecordForm
          :record="editingRecord" @submit="handleRecordSubmit" @delete="handleRecordDelete"
          @cancel="closeRecordForm"
        />
      </div>
    </div>

    <!-- 日常记录表单弹窗 -->
    <div v-if="showDailyForm" class="modal-overlay" @click.self="closeDailyForm">
      <div class="modal-content">
        <PeriodDailyForm
          :date="selectedDate" :record="editingDailyRecord" @submit="handleDailySubmit"
          @cancel="closeDailyForm"
        />
      </div>
    </div>

    <!-- 删除确认弹窗 -->
    <div v-if="showDeleteConfirm" class="modal-overlay" @click.self="closeDeleteConfirm">
      <div class="modal-content max-w-sm">
        <div class="p-6">
          <div class="mb-4 flex gap-3 items-center">
            <div class="rounded-full bg-red-100 flex h-8 w-8 items-center justify-center dark:bg-red-900/30">
              <LucideTrash class="text-red-600 wh-4 dark:text-red-400" />
            </div>
            <h3 class="text-lg text-gray-900 font-semibold dark:text-white">
              {{ t('period.confirmations.deleteRecord') }}
            </h3>
          </div>
          <p class="text-sm text-gray-600 mb-6 dark:text-gray-400">
            {{ t('period.confirmations.deleteWarning') }}
          </p>
          <div class="flex gap-3 items-center">
            <button
              class="text-sm text-white font-medium px-4 py-2 rounded-lg bg-red-500 flex-1 transition-colors hover:bg-red-600"
              @click="confirmDelete"
            >
              <LucideCheck class="wh-5" />
            </button>
            <button
              class="text-sm text-gray-700 font-medium px-4 py-2 rounded-lg bg-gray-100 flex-1 transition-colors dark:text-gray-300 dark:bg-gray-700 hover:bg-gray-200 dark:hover:bg-gray-600"
              @click="closeDeleteConfirm"
            >
              <LucideX class="wh-5" />
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- 加载状态 -->
    <div v-if="periodStore.loading" class="bg-black/50 flex items-center inset-0 justify-center fixed z-50">
      <div class="p-6 rounded-lg bg-white flex gap-3 shadow-xl items-center dark:bg-gray-800">
        <div class="border-2 border-blue-500 border-t-transparent rounded-full h-6 w-6 animate-spin" />
        <span class="text-gray-700 dark:text-gray-300"> {{ t('common.processing') }} </span>
      </div>
    </div>

    <!-- 错误提示 -->
    <div v-if="periodStore.error" class="max-w-sm bottom-4 right-4 fixed z-50">
      <div class="p-4 border border-red-200 rounded-lg bg-red-50 shadow-lg dark:border-red-800 dark:bg-red-900/20">
        <div class="flex gap-3 items-start">
          <div
            class="rounded-full bg-red-100 flex flex-shrink-0 h-8 w-8 items-center justify-center dark:bg-red-900/30"
          >
            <i class="i-tabler-alert-circle text-red-500 h-4 w-4" />
          </div>
          <div class="flex-1">
            <p class="text-sm text-red-900 font-medium dark:text-red-400">
              {{ t('period.messages.operationFailed') }}
            </p>
            <p class="text-xs text-red-700 mt-1 dark:text-red-400">
              {{ periodStore.error }}
            </p>
          </div>
          <button
            class="text-red-400 transition-colors hover:text-red-600 dark:hover:text-red-300"
            @click="periodStore.clearError()"
          >
            <LucideX class="h-4 w-4" />
          </button>
        </div>
      </div>
    </div>

    <!-- 成功提示 -->
    <div v-if="showSuccessMessage" class="max-w-sm bottom-4 right-4 fixed z-50">
      <div
        class="p-4 border border-green-200 rounded-lg bg-green-50 shadow-lg dark:border-green-800 dark:bg-green-900/20"
      >
        <div class="flex gap-3 items-start">
          <div
            class="rounded-full bg-green-100 flex flex-shrink-0 h-8 w-8 items-center justify-center dark:bg-green-900/30"
          >
            <i class="i-tabler-check text-green-500 h-4 w-4" />
          </div>
          <div class="flex-1">
            <p class="text-sm text-green-900 font-medium dark:text-green-400">
              {{ t('period.messages.operationSuccess') }}
            </p>
            <p class="text-xs text-green-700 mt-1 dark:text-green-400">
              {{ successMessage }}
            </p>
          </div>
          <button
            class="text-green-400 transition-colors hover:text-green-600 dark:hover:text-green-300"
            @click="hideSuccessMessage"
          >
            <LucideCheck class="h-4 w-4" />
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped lang="postcss">
.period-management {
  @apply min-h-screen bg-gradient-to-br from-gray-50 to-gray-100 dark:from-gray-900 dark:to-gray-800;
}

.header-section {
  @apply bg-white/80 dark:bg-gray-800/80 backdrop-blur-sm border-b border-gray-200 dark:border-gray-700 sticky top-0 z-10;
}

.container {
  @apply max-w-7xl;
}

.nav-tab {
  @apply px-3 py-2 text-sm font-medium rounded-md transition-all duration-200 flex items-center gap-2 text-gray-600 dark:text-gray-400 hover:text-gray-900 dark:hover:text-white;
}

.nav-tab-active {
  @apply bg-white dark:bg-gray-600 text-blue-600 dark:text-blue-400 shadow-sm;
}

.main-content {
  @apply flex-1;
}

.card-base {
  @apply bg-white/80 dark:bg-gray-800/80 backdrop-blur-sm border border-gray-200 dark:border-gray-700 rounded-xl shadow-sm hover:shadow-md transition-shadow duration-200;
}

.action-btn {
  @apply w-full flex items-center gap-3 px-4 py-3 rounded-lg border-2 transition-all duration-200 hover:shadow-md focus:ring-2 focus:ring-offset-2 text-sm font-medium;
}

.period-btn {
  @apply border-green-200 dark:border-green-800 bg-gradient-to-r from-green-50 to-emerald-50 dark:from-green-900/20 dark:to-emerald-900/20 text-green-700 dark:text-green-400 hover:from-green-100 hover:to-emerald-100 dark:hover:from-green-900/30 dark:hover:to-emerald-900/30 focus:ring-green-500;
}

.daily-btn {
  @apply border-blue-200 dark:border-blue-800 bg-gradient-to-r from-blue-50 to-cyan-50 dark:from-blue-900/20 dark:to-cyan-900/20 text-blue-700 dark:text-blue-400 hover:from-blue-100 hover:to-cyan-100 dark:hover:from-blue-900/30 dark:hover:to-cyan-900/30 focus:ring-blue-500;
}

.stats-btn {
  @apply border-green-200 dark:border-green-800 bg-gradient-to-r from-green-50 to-emerald-50 dark:from-green-900/20 dark:to-emerald-900/20 text-green-700 dark:text-green-400 hover:from-green-100 hover:to-emerald-100 dark:hover:from-green-900/30 dark:hover:to-emerald-900/30 focus:ring-green-500;
}

.action-icon-btn {
  @apply w-8 h-8 rounded-lg flex items-center justify-center transition-all duration-200 hover:scale-110 focus:ring-2 focus:ring-offset-2;
}

.view-btn {
  @apply bg-blue-50 dark:bg-blue-900/30 text-blue-600 dark:text-blue-400 hover:bg-blue-100 dark:hover:bg-blue-900/50 focus:ring-blue-500;
}

.delete-btn {
  @apply bg-red-50 dark:bg-red-900/30 text-red-600 dark:text-red-400 hover:bg-red-100 dark:hover:bg-red-900/50 focus:ring-red-500;
}

.info-item {
  @apply flex justify-between items-center;
}

.info-label {
  @apply text-sm font-medium text-gray-600 dark:text-gray-400;
}

.info-value {
  @apply text-sm font-semibold text-gray-900 dark:text-white;
}

.phase-badge {
  @apply px-3 py-1 bg-gradient-to-r from-pink-100 to-purple-100 dark:from-pink-900/30 dark:to-purple-900/30 text-pink-700 dark:text-pink-400 rounded-full text-xs font-medium;
}

.tip-item {
  @apply p-4 bg-gray-50 dark:bg-gray-700/50 rounded-lg border border-gray-100 dark:border-gray-600 hover:shadow-sm transition-shadow duration-200;
}

.modal-overlay {
  @apply fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-50 p-4;
  animation: fadeIn 0.2s ease-out;
}

.modal-content {
  @apply bg-white dark:bg-gray-800 rounded-xl max-w-md w-full max-h-[90vh] overflow-y-auto shadow-2xl;
  animation: slideUp 0.2s ease-out;
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
    @apply grid-cols-1 gap-4;
  }

  .nav-tab {
    @apply px-2 py-1.5 text-xs;
  }
}

@media (max-width: 768px) {
  .grid.md\\:grid-cols-2 {
    @apply grid-cols-1 gap-4;
  }

  .container {
    @apply px-3;
  }

  .card-base {
    @apply p-4;
  }

  .action-btn {
    @apply py-2.5 text-xs;
  }

  .modal-content {
    @apply mx-2 max-w-none;
  }
}

/* 移动端适配 - 关键修复：保持导航在一行 */
@media (max-width: 640px) {

  /* 确保头部容器保持水平布局 */
  .header-section .container>.flex {
    @apply flex-row items-center justify-between gap-2;
  }

  /* 左侧标题区域 */
  .header-section .flex.items-center.gap-2 {
    @apply gap-1 flex-shrink-0;
  }

  .header-section h1 {
    @apply text-base;
  }

  /* 右侧导航区域 - 保持水平排列 */
  .header-section .flex.items-center.gap-1.bg-gray-100 {
    @apply flex-1 max-w-[180px] gap-0.5 p-0.5;
  }

  /* 导航标签 - 水平排列 */
  .nav-tab {
    @apply px-1 py-1.5 text-xs flex-1 justify-center min-w-0;
  }

  /* 只在移动端隐藏文字 */
  .nav-tab span.hidden.sm\\:inline {
    @apply hidden;
  }

  /* 确保图标居中 */
  .nav-tab .w-4.h-4 {
    @apply mx-auto;
  }

  /* 主要内容区域调整 */
  .main-content .container {
    @apply py-4 px-3;
  }

  /* 卡片内边距调整 */
  .card-base {
    @apply p-3;
  }

  /* 按钮调整 */
  .action-btn {
    @apply py-2 text-xs gap-2;
  }

  /* 图标按钮调整 */
  .action-icon-btn {
    @apply w-7 h-7;
  }

  /* 提示卡片在移动端堆叠 */
  .tip-item {
    @apply p-3;
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
