<template>
  <div class="period-management">
    <!-- 头部导航 -->
    <div class="header-section">
      <div class="container mx-auto px-4">
        <div class="flex-between py-4">
          <h1 class="text-2xl font-bold text-gray-900 dark:text-white">
            经期管理
          </h1>
          <div class="flex items-center gap-3">
            <button 
              @click="currentView = 'calendar'" 
              class="nav-tab"
              :class="{ 'nav-tab-active': currentView === 'calendar' }"
            >
              <i class="i-tabler-calendar wh-4 mr-2" />
              日历
            </button>
            <button 
              @click="currentView = 'stats'" 
              class="nav-tab"
              :class="{ 'nav-tab-active': currentView === 'stats' }"
            >
              <i class="i-tabler-chart-line wh-4 mr-2" />
              统计
            </button>
            <button 
              @click="currentView = 'settings'" 
              class="nav-tab"
              :class="{ 'nav-tab-active': currentView === 'settings' }"
            >
              <i class="i-tabler-settings wh-4 mr-2" />
              设置
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- 主要内容区域 -->
    <div class="main-content scrollbar-hide">
      <div class="container mx-auto px-4 py-6">
        <!-- 统计仪表板视图 -->
        <div v-if="currentView === 'stats'" class="stats-view">
          <PeriodStatsDashboard 
            @add-record="openRecordForm()" 
            @edit-record="openRecordForm($event)" 
          />
        </div>

        <!-- 日历视图 -->
        <div v-else-if="currentView === 'calendar'" class="calendar-view">
          <div class="calendar-layout">
            <!-- 日历组件 -->
            <div class="calendar-section">
              <PeriodCalendar 
                :selected-date="selectedDate" 
                @date-select="handleDateSelect" 
              />
            </div>

            <!-- 右侧操作区域 -->
            <div class="sidebar-section">
              <!-- 快速操作 -->
              <div class="quick-actions card-base p-4">
                <h3 class="text-lg font-semibold text-gray-900 dark:text-white mb-4">
                  快速操作
                </h3>
                <div class="space-y-3">
                  <button @click="openRecordForm()" class="action-btn period-btn">
                    <i class="i-tabler-plus wh-4 mr-2" />
                    记录经期
                  </button>
                  <button @click="openDailyForm()" class="action-btn daily-btn">
                    <i class="i-tabler-edit wh-4 mr-2" />
                    日常记录
                  </button>
                  <button @click="currentView = 'stats'" class="action-btn stats-btn">
                    <i class="i-tabler-chart-bar wh-4 mr-2" />
                    查看统计
                  </button>
                </div>
              </div>

              <!-- 今日信息 -->
              <div class="today-info card-base p-4">
                <h3 class="text-lg font-semibold text-gray-900 dark:text-white mb-4">
                  今日信息
                </h3>
                <div class="space-y-3">
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
                    <button 
                      @click="openDailyForm(todayRecord)" 
                      class="text-blue-500 hover:underline text-sm"
                    >
                      查看详情
                    </button>
                  </div>
                </div>
              </div>

              <!-- 健康提示 -->
              <div class="health-tips card-base p-4">
                <h3 class="text-lg font-semibold text-gray-900 dark:text-white mb-4">
                  健康提示
                </h3>
                <div class="space-y-2">
                  <div 
                    v-for="tip in currentTips" 
                    :key="tip.id" 
                    class="tip-item"
                  >
                    <i :class="tip.icon" class="wh-4 text-blue-500 flex-shrink-0" />
                    <span class="text-sm text-gray-700 dark:text-gray-300">
                      {{ tip.text }}
                    </span>
                  </div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- 设置视图 -->
        <div v-else-if="currentView === 'settings'" class="settings-view">
          <PeriodSettings />
        </div>
      </div>
    </div>

    <!-- 经期记录表单弹窗 -->
    <div 
      v-if="showRecordForm" 
      class="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4"
      @click.self="closeRecordForm"
    >
      <div class="bg-white dark:bg-gray-800 rounded-lg max-w-md w-full max-h-[90vh] overflow-y-auto scrollbar-hide">
        <PeriodRecordForm 
          :record="editingRecord" 
          @submit="handleRecordSubmit" 
          @delete="handleRecordDelete"
          @cancel="closeRecordForm" 
        />
      </div>
    </div>

    <!-- 日常记录表单弹窗 -->
    <div 
      v-if="showDailyForm" 
      class="fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4"
      @click.self="closeDailyForm"
    >
      <div class="bg-white dark:bg-gray-800 rounded-lg max-w-md w-full max-h-[90vh] overflow-y-auto scrollbar-hide">
        <PeriodDailyForm 
          :date="selectedDate" 
          :record="editingDailyRecord" 
          @submit="handleDailySubmit"
          @cancel="closeDailyForm" 
        />
      </div>
    </div>

    <!-- 加载状态 -->
    <div 
      v-if="periodStore.loading" 
      class="fixed inset-0 bg-black/50 flex items-center justify-center z-50"
    >
      <div class="bg-white dark:bg-gray-800 rounded-lg p-6 flex items-center gap-3">
        <i class="i-tabler-loader-2 wh-5 animate-spin text-blue-500" />
        <span class="text-gray-700 dark:text-gray-300">处理中...</span>
      </div>
    </div>

    <!-- 错误提示 -->
    <div 
      v-if="periodStore.error"
      class="fixed bottom-4 right-4 bg-red-50 dark:bg-red-900/20 border border-red-200 dark:border-red-800 rounded-lg p-4 max-w-sm"
    >
      <div class="flex items-start gap-3">
        <i class="i-tabler-alert-circle wh-5 text-red-500 flex-shrink-0" />
        <div>
          <p class="text-sm font-medium text-red-900 dark:text-red-400">
            操作失败
          </p>
          <p class="text-xs text-red-700 dark:text-red-400 mt-1">
            {{ periodStore.error }}
          </p>
        </div>
        <button 
          @click="periodStore.clearError()" 
          class="text-red-400 hover:text-red-600 dark:hover:text-red-300"
        >
          <i class="i-tabler-x wh-4" />
        </button>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import {ref, computed, onMounted} from 'vue';
import {usePeriodStore} from '@/stores/periodStore';
import PeriodCalendar from '../components/PeriodCalendar.vue';
import PeriodStatsDashboard from './PeriodStatsDashboard.vue';
import PeriodSettings from './PeriodSettings.vue';
import PeriodRecordForm from './PeriodRecordForm.vue';
import PeriodDailyForm from './PeriodDailyForm.vue';
import type {PeriodRecords, PeriodDailyRecords} from '@/schema/health/period';

// Store
const periodStore = usePeriodStore();

// Reactive state
const currentView = ref<'calendar' | 'stats' | 'settings'>('calendar');
const selectedDate = ref(new Date().toISOString().split('T')[0]);
const showRecordForm = ref(false);
const showDailyForm = ref(false);
const editingRecord = ref<PeriodRecords | undefined>();
const editingDailyRecord = ref<PeriodDailyRecords | undefined>();

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
  return periodStore.getDailyRecord(selectedDate.value);
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
      {id: 1, icon: 'i-tabler-cup', text: '多喝温水，避免冷饮'},
      {id: 2, icon: 'i-tabler-bed', text: '充分休息，避免剧烈运动'},
      {id: 3, icon: 'i-tabler-flame', text: '注意保暖，特别是腹部'},
    ];
  } else if (phase === 'Ovulation') {
    return [
      {id: 1, icon: 'i-tabler-heart', text: '排卵期，注意个人卫生'},
      {id: 2, icon: 'i-tabler-activity', text: '适当运动有助于健康'},
      {id: 3, icon: 'i-tabler-leaf', text: '多吃新鲜蔬果'},
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

const handleRecordSubmit = (record: PeriodRecords) => {
  closeRecordForm();
  console.log('Record submitted:', record);
  // 可以在这里添加成功提示
};

const handleRecordDelete = (serialNum: string) => {
  closeRecordForm();
  console.log('Record deleted:', serialNum);
  // 可以在这里添加删除成功提示
};

const openDailyForm = (record?: PeriodDailyRecords) => {
  editingDailyRecord.value = record;
  showDailyForm.value = true;
};

const closeDailyForm = () => {
  showDailyForm.value = false;
  editingDailyRecord.value = undefined;
};

const handleDailySubmit = (record: PeriodDailyRecords) => {
  closeDailyForm();
  console.log('Daily record submitted:', record);
  // 可以在这里添加成功提示
};

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
  @apply min-h-screen bg-gray-50 dark:bg-gray-900;
}

.header-section {
  @apply bg-white dark:bg-gray-800 border-b border-gray-200 dark:border-gray-700 sticky top-0 z-10;
}

.container {
  @apply max-w-7xl;
}

.flex-between {
  @apply flex items-center justify-between;
}

.nav-tab {
  @apply px-4 py-2 text-sm font-medium rounded-lg transition-colors text-gray-600 dark:text-gray-400 hover:text-gray-900 dark:hover:text-white hover:bg-gray-100 dark:hover:bg-gray-700;
}

.nav-tab-active {
  @apply bg-blue-100 dark:bg-blue-900/30 text-blue-700 dark:text-blue-400;
}

.main-content {
  @apply flex-1;
}

/* 日历布局样式 */
.calendar-layout {
  @apply flex gap-6;
}

.calendar-section {
  @apply flex-shrink-0;
}

.sidebar-section {
  @apply flex-1 space-y-4 min-w-0 max-h-screen overflow-y-auto scrollbar-hide;
}

.card-base {
  @apply bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg shadow-sm;
}

.quick-actions .action-btn {
  @apply w-full flex items-center justify-start px-4 py-2.5 rounded-lg border transition-all hover:shadow-sm focus:ring-2 focus:ring-offset-2 text-sm;
}

.period-btn {
  @apply border-red-200 dark:border-red-800 bg-red-50 dark:bg-red-900/20 text-red-700 dark:text-red-400 hover:bg-red-100 dark:hover:bg-red-900/30 focus:ring-red-500;
}

.daily-btn {
  @apply border-blue-200 dark:border-blue-800 bg-blue-50 dark:bg-blue-900/20 text-blue-700 dark:text-blue-400 hover:bg-blue-100 dark:hover:bg-blue-900/30 focus:ring-blue-500;
}

.stats-btn {
  @apply border-green-200 dark:border-green-800 bg-green-50 dark:bg-green-900/20 text-green-700 dark:text-green-400 hover:bg-green-100 dark:hover:bg-green-900/30 focus:ring-green-500;
}

.info-item {
  @apply flex justify-between items-center;
}

.info-label {
  @apply text-sm text-gray-600 dark:text-gray-400;
}

.info-value {
  @apply text-sm font-medium text-gray-900 dark:text-white;
}

.phase-badge {
  @apply px-2 py-1 bg-pink-100 dark:bg-pink-900/30 text-pink-700 dark:text-pink-400 rounded-full text-xs;
}

.tip-item {
  @apply flex items-start gap-2;
}

/* 滚动条隐藏样式 - 确保使用 UnoCSS 的 scrollbar-hide */
.main-content,
.sidebar-section {
  /* UnoCSS scrollbar-hide 类已应用，这里添加额外的兼容性支持 */
  scrollbar-width: none; /* Firefox */
  -ms-overflow-style: none; /* IE/Edge */
}

.main-content::-webkit-scrollbar,
.sidebar-section::-webkit-scrollbar,
.scrollbar-hide::-webkit-scrollbar {
  display: none; /* Chrome/Safari */
  width: 0;
  height: 0;
}

/* 模态框动画 */
.fixed.inset-0 {
  animation: fadeIn 0.2s ease-out;
}

.fixed .bg-white,
.fixed .dark\\:bg-gray-800 {
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

@media (max-width: 1024px) {
  .calendar-layout {
    @apply flex-col gap-4;
  }
  
  .sidebar-section {
    @apply space-y-3 max-h-none; /* 移动端移除高度限制 */
  }

  .nav-tab {
    @apply px-3 py-1.5 text-xs;
  }

  .nav-tab i {
    @apply hidden;
  }
}

@media (max-width: 640px) {
  .header-section .flex-between {
    @apply flex-col gap-3 items-start;
  }

  .nav-tab {
    @apply flex-1 text-center;
  }

  .container {
    @apply px-2;
  }

  .main-content .container {
    @apply py-4;
  }
  
  .calendar-layout {
    @apply gap-3;
  }
  
  .sidebar-section {
    @apply space-y-2 max-h-none; /* 移动端移除高度限制 */
  }
  
  .card-base {
    @apply p-3;
  }
  
  .quick-actions .action-btn {
    @apply py-2 text-xs;
  }
}
</style>
