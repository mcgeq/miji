<template>
  <div class="period-management">
    <!-- 头部导航 -->
    <div class="header-section">
      <div class="container mx-auto px-4 lg:px-6">
        <div class="flex items-center justify-end py-1">
          <div class="flex items-center gap-1 bg-gray-100 dark:bg-gray-700 rounded-lg p-1">
            <button @click="currentView = 'calendar'" class="nav-tab"
              :class="{ 'nav-tab-active': currentView === 'calendar' }">
              <CalendarCheck class="wh-4" />
              <span class="hidden sm:inline">{{ t('period.navigation.calendar') }}</span>
            </button>
            <button @click="currentView = 'stats'" class="nav-tab"
              :class="{ 'nav-tab-active': currentView === 'stats' }">
              <Activity class="wh-4" />
              <span class="hidden sm:inline">{{ t('period.navigation.statistics') }}</span>
            </button>
            <button @click="currentView = 'settings'" class="nav-tab"
              :class="{ 'nav-tab-active': currentView === 'settings' }">
              <Settings class="wh-4" />
              <span class="hidden sm:inline">{{ t('period.navigation.settings') }}</span>
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- 主要内容区域 -->
    <div class="main-content">
      <div class="container mx-auto px-4 lg:px-6 py-6">
        <!-- 统计仪表板视图 -->
        <div v-if="currentView === 'stats'" class="stats-view">
          <PeriodStatsDashboard @add-record="openRecordForm()" @edit-record="openRecordForm($event)" />
        </div>

        <!-- 日历视图 -->
        <div v-else-if="currentView === 'calendar'" class="calendar-view space-y-6">
          <!-- 第一行：日历占1/2，今日信息+快速操作占1/2 -->
          <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <!-- 日历组件 -->
            <div class="card-base p-6">
              <PeriodCalendar :selected-date="selectedDate" @date-select="handleDateSelect" />
            </div>

            <!-- 今日信息和快速操作 -->
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <!-- 今日信息 -->
              <div class="card-base p-6">
                <div class="flex items-center gap-3 mb-6">
                  <div
                    class="w-10 h-10 bg-gradient-to-r from-blue-500 to-cyan-500 rounded-full flex items-center justify-center">
                    <CalendarCheck class="w-5 h-5 text-white" />
                  </div>
                  <h3 class="text-lg font-semibold text-gray-900 dark:text-white">
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
                    <div class="flex items-center gap-2">
                      <button @click="openDailyForm(todayRecord)" class="action-icon-btn view-btn" title="查看记录">
                        <Eye class="wh-4" />
                      </button>
                      <button @click="handleDeleteDailyRecord(todayRecord.serialNum)" class="action-icon-btn delete-btn"
                        :title="t('common.actions.delete')">
                        <Trash class="wh-4" />
                      </button>
                    </div>
                  </div>
                  <div v-else class="info-item">
                    <span class="info-label">{{ t('period.todayInfo.todayRecord') }}</span>
                    <span class="text-sm text-gray-500 dark:text-gray-400">{{ t('period.todayInfo.noRecord') }}</span>
                  </div>
                </div>
              </div>

              <!-- 快速操作 -->
              <div class="card-base p-6">
                <div class="flex items-center gap-3 mb-6">
                  <div
                    class="w-10 h-10 bg-gradient-to-r from-purple-500 to-pink-500 rounded-full flex items-center justify-center">
                    <Plus class="w-5 h-5 text-white" />
                  </div>
                  <h3 class="text-lg font-semibold text-gray-900 dark:text-white">
                    {{ t('period.quickActions.title') }}
                  </h3>
                </div>
                <div class="space-y-3">
                  <button @click="openRecordForm()" class="action-btn period-btn">
                    <Plus class="wh-5" />
                    <span>{{ t('period.quickActions.recordPeriod') }}</span>
                  </button>
                  <button @click="openDailyForm()" class="action-btn daily-btn">
                    <Edit class="wh-5" />
                    <span>{{ t('period.quickActions.dailyRecord') }}</span>
                  </button>
                  <button @click="currentView = 'stats'" class="action-btn stats-btn">
                    <Activity class="wh-5" />
                    <span>{{ t('period.quickActions.viewStats') }}</span>
                  </button>
                </div>
              </div>
            </div>
          </div>

          <!-- 第二行：健康提示（铺满宽度） -->
          <div class="card-base p-4">
            <div class="flex items-center gap-3 mb-6">
              <div
                class="w-10 h-10 bg-gradient-to-r from-green-500 to-emerald-500 rounded-full flex items-center justify-center">
                <Heart class="wh-5 text-white" />
              </div>
              <h3 class="text-lg font-semibold text-gray-900 dark:text-white">
                {{ t('period.healthTips.title') }}
              </h3>
            </div>
            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              <div v-for="tip in currentTips" :key="tip.id" class="tip-item">
                <div class="flex items-start gap-3">
                  <div
                    class="w-8 h-8 bg-blue-50 dark:bg-blue-900/30 rounded-full flex items-center justify-center flex-shrink-0">
                    <component :is="tip.icon" class="wh-4 text-blue-600 dark:text-blue-400" />
                  </div>
                  <span class="text-sm text-gray-700 dark:text-gray-300 leading-relaxed">
                    {{ tip.text }}
                  </span>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- 设置视图 -->
        <div v-else-if="currentView === 'settings'" class="settings-view">
          <div class="card-base p-6">
            <PeriodSettings />
          </div>
        </div>
      </div>
    </div>

    <!-- 经期记录表单弹窗 -->
    <div v-if="showRecordForm" class="modal-overlay" @click.self="closeRecordForm">
      <div class="modal-content">
        <PeriodRecordForm :record="editingRecord" @submit="handleRecordSubmit" @delete="handleRecordDelete"
          @cancel="closeRecordForm" />
      </div>
    </div>

    <!-- 日常记录表单弹窗 -->
    <div v-if="showDailyForm" class="modal-overlay" @click.self="closeDailyForm">
      <div class="modal-content">
        <PeriodDailyForm :date="selectedDate" :record="editingDailyRecord" @submit="handleDailySubmit"
          @cancel="closeDailyForm" />
      </div>
    </div>

    <!-- 删除确认弹窗 -->
    <div v-if="showDeleteConfirm" class="modal-overlay" @click.self="closeDeleteConfirm">
      <div class="modal-content max-w-sm">
        <div class="p-6">
          <div class="flex items-center gap-3 mb-4">
            <div class="w-10 h-10 bg-red-100 dark:bg-red-900/30 rounded-full flex items-center justify-center">
              <Trash class="w-5 h-5 text-red-600 dark:text-red-400" />
            </div>
            <h3 class="text-lg font-semibold text-gray-900 dark:text-white">
              {{ t('period.confirmations.deleteRecord') }}
            </h3>
          </div>
          <p class="text-sm text-gray-600 dark:text-gray-400 mb-6">
            {{ t('period.confirmations.deleteWarning') }}
          </p>
          <div class="flex items-center gap-3">
            <button @click="confirmDelete"
              class="flex-1 bg-red-500 hover:bg-red-600 text-white px-4 py-2 rounded-lg text-sm font-medium transition-colors">
              <Check class="wh-5" />
            </button>
            <button @click="closeDeleteConfirm"
              class="flex-1 bg-gray-100 hover:bg-gray-200 dark:bg-gray-700 dark:hover:bg-gray-600 text-gray-700 dark:text-gray-300 px-4 py-2 rounded-lg text-sm font-medium transition-colors">
              <X class="wh-5" />
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- 加载状态 -->
    <div v-if="periodStore.loading" class="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
      <div class="bg-white dark:bg-gray-800 rounded-lg p-6 flex items-center gap-3 shadow-xl">
        <div class="w-6 h-6 border-2 border-blue-500 border-t-transparent rounded-full animate-spin"></div>
        <span class="text-gray-700 dark:text-gray-300"> {{ t('common.processing') }} </span>
      </div>
    </div>

    <!-- 错误提示 -->
    <div v-if="periodStore.error" class="fixed bottom-4 right-4 max-w-sm z-50">
      <div class="bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-lg p-4 shadow-lg">
        <div class="flex items-start gap-3">
          <div
            class="w-8 h-8 bg-red-100 dark:bg-red-900/30 rounded-full flex items-center justify-center flex-shrink-0">
            <i class="i-tabler-alert-circle w-4 h-4 text-red-500" />
          </div>
          <div class="flex-1">
            <p class="text-sm font-medium text-red-900 dark:text-red-400">
              {{ t('period.messages.operationFailed') }}
            </p>
            <p class="text-xs text-red-700 dark:text-red-400 mt-1">
              {{ periodStore.error }}
            </p>
          </div>
          <button @click="periodStore.clearError()"
            class="text-red-400 hover:text-red-600 dark:hover:text-red-300 transition-colors">
            <X class="w-4 h-4" />
          </button>
        </div>
      </div>
    </div>

    <!-- 成功提示 -->
    <div v-if="showSuccessMessage" class="fixed bottom-4 right-4 max-w-sm z-50">
      <div
        class="bg-green-50 dark:bg-green-900/20 border border-green-200 dark:border-green-800 rounded-lg p-4 shadow-lg">
        <div class="flex items-start gap-3">
          <div
            class="w-8 h-8 bg-green-100 dark:bg-green-900/30 rounded-full flex items-center justify-center flex-shrink-0">
            <i class="i-tabler-check w-4 h-4 text-green-500" />
          </div>
          <div class="flex-1">
            <p class="text-sm font-medium text-green-900 dark:text-green-400">
              {{ t('period.messages.operationSuccess') }}
            </p>
            <p class="text-xs text-green-700 dark:text-green-400 mt-1">
              {{ successMessage }}
            </p>
          </div>
          <button @click="hideSuccessMessage"
            class="text-green-400 hover:text-green-600 dark:hover:text-green-300 transition-colors">
            <Check class="w-4 h-4" />
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import {
  Activity,
  Apple,
  CalendarCheck,
  Check,
  Droplet,
  Edit,
  Eye,
  Heart,
  Moon,
  Plus,
  Settings,
  Trash,
  X,
} from 'lucide-vue-next';
import type {PeriodDailyRecords, PeriodRecords} from '@/schema/health/period';
import {usePeriodStore} from '@/stores/periodStore';
import {getTodayDate} from '@/utils/date';
import PeriodCalendar from '../components/PeriodCalendar.vue';
import PeriodDailyForm from './PeriodDailyForm.vue';
import PeriodRecordForm from './PeriodRecordForm.vue';
import PeriodSettings from './PeriodSettings.vue';
import PeriodStatsDashboard from './PeriodStatsDashboard.vue';
import {phaseTips, Tip} from '../../utils/periodUtils';
import {Lg} from '@/utils/debugLog';

// Store
const periodStore = usePeriodStore();

const {t} = useI18n();

// Reactive state
const currentView = ref<'calendar' | 'stats' | 'settings'>('calendar');
const selectedDate = ref(getTodayDate().split('T')[0]);
const showRecordForm = ref(false);
const showDailyForm = ref(false);
const showDeleteConfirm = ref(false);
const showSuccessMessage = ref(false);
const successMessage = ref('');
const editingRecord = ref<PeriodRecords | undefined>();
const editingDailyRecord = ref<PeriodDailyRecords | undefined>();
const deletingSerialNum = ref<string>('');

// Computed
const currentPhaseLabel = computed(() => {
  const phase = periodStore.periodStats.currentPhase;
  const labels = {
    Menstrual: t('period.phases.menstrual'),
    Follicular: t('period.phases.follicular'),
    Ovulation: t('period.phases.ovulation'),
    Luteal: t('period.phases.luteal'),
  };
  return labels[phase];
});

const daysUntilNext = computed(() => {
  const days = periodStore.periodStats.daysUntilNext;
  if (days === 0) return t('period.nextPeriod.todayStart');
  if (days === 1) return t('period.nextPeriod.tomorrowStart');
  if (days < 0) return t('period.nextPeriod.delayed');
  return `${days}${t('period.nextPeriod.daysLater')}`;
});

const todayRecord = computed(() => {
  periodStore.dailyRecords.length;
  const records = periodStore.dailyRecords;
  const today = selectedDate.value;

  // 每次都重新查找，确保获取最新数据
  const found = records.find((record) => record.date === today);

  return found || null;
});
const baseTips: Tip[] = [
  {id: 1, icon: Droplet, text: t('period.healthTips.water')},
  {id: 2, icon: Moon, text: t('period.healthTips.sleep')},
  {id: 3, icon: Apple, text: t('period.healthTips.iron')},
];
const currentTips = computed(() => {
  const phase = periodStore.periodStats.currentPhase;
  return phaseTips[phase] || baseTips;
});

// Methods
const handleDateSelect = (date: string) => {
  selectedDate.value = date;
};

const openRecordForm = (record?: PeriodRecords) => {
  editingRecord.value = record;
  showRecordForm.value = true;
};

const closeRecordForm = () => {
  showRecordForm.value = false;
  editingRecord.value = undefined;
};

const handleRecordSubmit = async (record: PeriodRecords) => {
  closeRecordForm();

  // 刷新数据以更新UI
  await periodStore.fetchPeriodRecords();

  showSuccessToast(t('period.messages.periodRecordSaved'));
  Lg.i('PeriodManagement', 'Record submitted:', record);
};

const handleRecordDelete = async (serialNum: string) => {
  closeRecordForm();

  // 刷新数据以更新UI
  await periodStore.fetchPeriodRecords();

  showSuccessToast(t('period.messages.periodRecordDeleted'));
  Lg.i('PeriodManagement', 'Record deleted:', serialNum);
};

const openDailyForm = (record?: PeriodDailyRecords) => {
  editingDailyRecord.value = record;
  showDailyForm.value = true;
};

const closeDailyForm = () => {
  showDailyForm.value = false;
  editingDailyRecord.value = undefined;
};

const handleDailySubmit = async (record: PeriodDailyRecords) => {
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
      periodStore.dailyRecords.length,
    );
  } catch (error) {
    Lg.e('PeriodManagement', `${t('period.saveFailed')}:`, error);
  }
};

// 删除相关方法
const handleDeleteDailyRecord = (serialNum: string) => {
  deletingSerialNum.value = serialNum;
  showDeleteConfirm.value = true;
};

const closeDeleteConfirm = () => {
  showDeleteConfirm.value = false;
  deletingSerialNum.value = '';
};

// 1. 修改 confirmDelete 方法
const confirmDelete = async () => {
  try {
    const deletingId = deletingSerialNum.value;

    Lg.i('PeriodManagement', 'Deleting record:', deletingId);

    // 使用专门的删除日常记录方法
    await periodStore.deleteDailyRecord(deletingId);

    // 等待一个 tick 确保状态更新完成
    await nextTick();

    // 强制刷新日常记录
    await periodStore.refreshDailyRecords();

    showSuccessToast(t('period.messages.recordDeleted'));
    closeDeleteConfirm();

    Lg.i(
      'PeriodManagement',
      'Delete completed, records count:',
      periodStore.dailyRecords.length,
    );
  } catch (error) {
    console.error(`${t('messages.deleteFailed')}:`, error);
  }
};

// 成功提示相关方法
const showSuccessToast = (message: string) => {
  successMessage.value = message;
  showSuccessMessage.value = true;
  setTimeout(() => {
    showSuccessMessage.value = false;
  }, 3000);
};

const hideSuccessMessage = () => {
  showSuccessMessage.value = false;
};

watch(
  () => periodStore.dailyRecords,
  (newRecords, oldRecords) => {
    Lg.i('PeriodManagement', 'Daily records changed:', {
      oldCount: oldRecords?.length || 0,
      newCount: newRecords.length,
      todayDate: selectedDate.value,
      hasTodayRecord: !!newRecords.find((r) => r.date === selectedDate.value),
    });
  },
  {deep: true},
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
  .header-section .container > .flex {
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
