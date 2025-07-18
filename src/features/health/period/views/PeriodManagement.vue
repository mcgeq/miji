<template>
  <div class="period-management">
    <!-- 头部导航 -->
    <div class="header-section">
      <div class="container mx-auto px-4 lg:px-6">
        <div class="flex items-center justify-between py-4">
          <div class="flex items-center gap-2">
            <div
              class="w-8 h-8 bg-gradient-to-r from-pink-500 to-purple-500 rounded-full flex items-center justify-center">
              <CalendarCheck class="w-4 h-4 text-white" />
            </div>
            <h1 class="text-xl font-bold text-gray-900 dark:text-white">
              经期管理
            </h1>
          </div>
          <div class="flex items-center gap-1 bg-gray-100 dark:bg-gray-700 rounded-lg p-1">
            <button @click="currentView = 'calendar'" class="nav-tab"
              :class="{ 'nav-tab-active': currentView === 'calendar' }">
              <CalendarCheck class="w-4 h-4" />
              <span class="hidden sm:inline">日历</span>
            </button>
            <button @click="currentView = 'stats'" class="nav-tab"
              :class="{ 'nav-tab-active': currentView === 'stats' }">
              <Activity class="w-4 h-4" />
              <span class="hidden sm:inline">统计</span>
            </button>
            <button @click="currentView = 'settings'" class="nav-tab"
              :class="{ 'nav-tab-active': currentView === 'settings' }">
              <Settings class="w-4 h-4" />
              <span class="hidden sm:inline">设置</span>
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
                    今日信息
                  </h3>
                </div>
                <div class="space-y-4">
                  <div class="info-item">
                    <span class="info-label">当前阶段</span>
                    <span class="info-value phase-badge">
                      {{ currentPhaseLabel }}
                    </span>
                  </div>
                  <div class="info-item">
                    <span class="info-label">距离下次</span>
                    <span class="info-value">{{ daysUntilNext }}</span>
                  </div>
                  <div v-if="todayRecord" class="info-item">
                    <span class="info-label">今日记录</span>
                    <div class="flex items-center gap-2">
                      <button @click="openDailyForm(todayRecord)" class="action-icon-btn view-btn" title="查看记录">
                        <Eye class="w-4 h-4" />
                      </button>
                      <button @click="handleDeleteDailyRecord(todayRecord.serialNum)" class="action-icon-btn delete-btn"
                        title="删除记录">
                        <Trash class="w-4 h-4" />
                      </button>
                    </div>
                  </div>
                  <div v-else class="info-item">
                    <span class="info-label">今日记录</span>
                    <span class="text-sm text-gray-500 dark:text-gray-400">暂无记录</span>
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
                    快速操作
                  </h3>
                </div>
                <div class="space-y-3">
                  <button @click="openRecordForm()" class="action-btn period-btn">
                    <Plus class="w-5 h-5" />
                    <span>记录经期</span>
                  </button>
                  <button @click="openDailyForm()" class="action-btn daily-btn">
                    <Edit class="w-5 h-5" />
                    <span>日常记录</span>
                  </button>
                  <button @click="currentView = 'stats'" class="action-btn stats-btn">
                    <Activity class="w-5 h-5" />
                    <span>查看统计</span>
                  </button>
                </div>
              </div>
            </div>
          </div>

          <!-- 第二行：健康提示（铺满宽度） -->
          <div class="card-base p-6">
            <div class="flex items-center gap-3 mb-6">
              <div
                class="w-10 h-10 bg-gradient-to-r from-green-500 to-emerald-500 rounded-full flex items-center justify-center">
                <i class="i-tabler-heart w-5 h-5 text-white" />
              </div>
              <h3 class="text-lg font-semibold text-gray-900 dark:text-white">
                健康提示
              </h3>
            </div>
            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              <div v-for="tip in currentTips" :key="tip.id" class="tip-item">
                <div class="flex items-start gap-3">
                  <div
                    class="w-8 h-8 bg-blue-50 dark:bg-blue-900/30 rounded-full flex items-center justify-center flex-shrink-0">
                    <i :class="tip.icon" class="w-4 h-4 text-blue-600 dark:text-blue-400" />
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
              确认删除
            </h3>
          </div>
          <p class="text-sm text-gray-600 dark:text-gray-400 mb-6">
            确定要删除这条记录吗？此操作无法撤销。
          </p>
          <div class="flex items-center gap-3">
            <button @click="confirmDelete"
              class="flex-1 bg-red-500 hover:bg-red-600 text-white px-4 py-2 rounded-lg text-sm font-medium transition-colors">
              确认删除
            </button>
            <button @click="closeDeleteConfirm"
              class="flex-1 bg-gray-100 hover:bg-gray-200 dark:bg-gray-700 dark:hover:bg-gray-600 text-gray-700 dark:text-gray-300 px-4 py-2 rounded-lg text-sm font-medium transition-colors">
              取消
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- 加载状态 -->
    <div v-if="periodStore.loading" class="fixed inset-0 bg-black/50 flex items-center justify-center z-50">
      <div class="bg-white dark:bg-gray-800 rounded-lg p-6 flex items-center gap-3 shadow-xl">
        <div class="w-6 h-6 border-2 border-blue-500 border-t-transparent rounded-full animate-spin"></div>
        <span class="text-gray-700 dark:text-gray-300">处理中...</span>
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
              操作失败
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
              操作成功
            </p>
            <p class="text-xs text-green-700 dark:text-green-400 mt-1">
              {{ successMessage }}
            </p>
          </div>
          <button @click="hideSuccessMessage"
            class="text-green-400 hover:text-green-600 dark:hover:text-green-300 transition-colors">
            <X class="w-4 h-4" />
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import {
  Activity,
  CalendarCheck,
  Edit,
  Eye,
  Plus,
  Settings,
  Trash,
  X,
} from 'lucide-vue-next';
import type { PeriodDailyRecords, PeriodRecords } from '@/schema/health/period';
import { usePeriodStore } from '@/stores/periodStore';
import { getTodayDate } from '@/utils/date';
import PeriodCalendar from '../components/PeriodCalendar.vue';
import PeriodDailyForm from './PeriodDailyForm.vue';
import PeriodRecordForm from './PeriodRecordForm.vue';
import PeriodSettings from './PeriodSettings.vue';
import PeriodStatsDashboard from './PeriodStatsDashboard.vue';

// Store
const periodStore = usePeriodStore();

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
    Menstrual: '经期',
    Follicular: '卵泡期',
    Ovulation: '排卵期',
    Luteal: '黄体期',
  };
  return labels[phase];
});

const daysUntilNext = computed(() => {
  const days = periodStore.periodStats.daysUntilNext;
  if (days === 0) return '今天开始';
  if (days === 1) return '明天开始';
  if (days < 0) return '已延迟';
  return `${days}天后`;
});

const todayRecord = computed(() => {
  const recordsLength = periodStore.dailyRecords.length;
  const records = periodStore.dailyRecords;
  const today = selectedDate.value;

  // 每次都重新查找，确保获取最新数据
  const found = records.find((record) => record.date === today);

  console.log(
    `Today record check: date=${today}, found=${!!found}, total records=${recordsLength}`,
  );
  return found || null;
});

const currentTips = computed(() => {
  const phase = periodStore.periodStats.currentPhase;
  const baseTips = [
    {
      id: 1,
      icon: 'i-tabler-droplet',
      text: '每天喝足够的水有助于缓解经期不适',
    },
    {
      id: 2,
      icon: 'i-tabler-moon',
      text: '保持规律的睡眠时间对月经周期很重要',
    },
    {
      id: 3,
      icon: 'i-tabler-apple',
      text: '富含铁质的食物有助于补充经期流失的营养',
    },
  ];

  // 根据当前阶段提供特定建议
  if (phase === 'Menstrual') {
    return [
      { id: 1, icon: 'i-tabler-cup', text: '多喝温水，避免冷饮' },
      { id: 2, icon: 'i-tabler-bed', text: '充分休息，避免剧烈运动' },
      { id: 3, icon: 'i-tabler-flame', text: '注意保暖，特别是腹部' },
    ];
  } else if (phase === 'Ovulation') {
    return [
      { id: 1, icon: 'i-tabler-heart', text: '排卵期，注意个人卫生' },
      { id: 2, icon: 'i-tabler-activity', text: '适当运动有助于健康' },
      { id: 3, icon: 'i-tabler-leaf', text: '多吃新鲜蔬果' },
    ];
  }

  return baseTips;
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

  showSuccessToast('经期记录已保存');
  console.log('Record submitted:', record);
};

const handleRecordDelete = async (serialNum: string) => {
  closeRecordForm();

  // 刷新数据以更新UI
  await periodStore.fetchPeriodRecords();

  showSuccessToast('经期记录已删除');
  console.log('Record deleted:', serialNum);
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
    console.log('Submitting daily record:', record);

    closeDailyForm();

    // 等待保存完成
    await periodStore.upsertDailyRecord(record);

    // 等待一个 tick 确保状态更新
    await nextTick();

    showSuccessToast('日常记录已保存');

    console.log(
      'Daily record saved, total records:',
      periodStore.dailyRecords.length,
    );
  } catch (error) {
    console.error('保存日常记录失败:', error);
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

    console.log('Deleting record:', deletingId);

    // 使用专门的删除日常记录方法
    await periodStore.deleteDailyRecord(deletingId);

    // 等待一个 tick 确保状态更新完成
    await nextTick();

    // 强制刷新日常记录
    await periodStore.refreshDailyRecords();

    showSuccessToast('记录已删除');
    closeDeleteConfirm();

    console.log(
      'Delete completed, records count:',
      periodStore.dailyRecords.length,
    );
  } catch (error) {
    console.error('删除失败:', error);
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
    console.log('Daily records changed:', {
      oldCount: oldRecords?.length || 0,
      newCount: newRecords.length,
      todayDate: selectedDate.value,
      hasTodayRecord: !!newRecords.find((r) => r.date === selectedDate.value),
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
    console.error('Failed to load period data:', error);
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
  @apply border-red-200 dark:border-red-800 bg-gradient-to-r from-red-50 to-pink-50 dark:from-red-900/20 dark:to-pink-900/20 text-red-700 dark:text-red-400 hover:from-red-100 hover:to-pink-100 dark:hover:from-red-900/30 dark:hover:to-pink-900/30 focus:ring-red-500;
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

@media (max-width: 640px) {
  .header-section .flex {
    @apply flex-col gap-3 items-start;
  }

  .nav-tab span {
    @apply hidden;
  }

  .nav-tab {
    @apply flex-1 justify-center;
  }

  .main-content .container {
    @apply py-4;
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
