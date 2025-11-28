<script setup lang="ts">
import { Activity, CalendarCheck, Settings } from 'lucide-vue-next';
import { Card, ConfirmDialog, Modal, Spinner } from '@/components/ui';
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
  <div class="min-h-screen bg-gradient-to-br from-gray-50 to-gray-100 dark:from-gray-900 dark:to-gray-800">
    <!-- 头部导航 -->
    <div class="sticky top-0 z-10 bg-white/80 dark:bg-gray-800/80 backdrop-blur-md border-b border-gray-200 dark:border-gray-700">
      <div class="max-w-7xl mx-auto px-4 lg:px-6">
        <div class="py-1 flex items-center justify-end">
          <div class="flex items-center gap-1 p-1 bg-gray-100 dark:bg-gray-700 rounded-lg">
            <button
              class="flex items-center gap-2 px-3 py-2 rounded-md text-sm font-medium transition-all duration-200"
              :class="currentView === 'calendar'
                ? 'bg-white dark:bg-gray-600 text-gray-900 dark:text-white shadow-sm'
                : 'text-gray-600 dark:text-gray-400 hover:text-gray-900 dark:hover:text-white'"
              @click="currentView = 'calendar'"
            >
              <CalendarCheck :size="18" />
              <span class="hidden sm:inline">{{ t('period.navigation.calendar') }}</span>
            </button>
            <button
              class="flex items-center gap-2 px-3 py-2 rounded-md text-sm font-medium transition-all duration-200"
              :class="currentView === 'stats'
                ? 'bg-white dark:bg-gray-600 text-gray-900 dark:text-white shadow-sm'
                : 'text-gray-600 dark:text-gray-400 hover:text-gray-900 dark:hover:text-white'"
              @click="currentView = 'stats'"
            >
              <Activity :size="18" />
              <span class="hidden sm:inline">{{ t('period.navigation.statistics') }}</span>
            </button>
            <button
              class="flex items-center gap-2 px-3 py-2 rounded-md text-sm font-medium transition-all duration-200"
              :class="currentView === 'settings'
                ? 'bg-white dark:bg-gray-600 text-gray-900 dark:text-white shadow-sm'
                : 'text-gray-600 dark:text-gray-400 hover:text-gray-900 dark:hover:text-white'"
              @click="currentView = 'settings'"
            >
              <Settings :size="18" />
              <span class="hidden sm:inline">{{ t('period.navigation.settings') }}</span>
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- 主要内容区域 -->
    <div class="flex-1">
      <div class="max-w-7xl mx-auto px-4 py-6 lg:px-6">
        <!-- 统计仪表板视图 -->
        <div v-if="currentView === 'stats'">
          <PeriodStatsDashboard />
        </div>

        <!-- 日历视图 -->
        <div v-else-if="currentView === 'calendar'" class="space-y-6">
          <!-- 日历和今日信息网格 -->
          <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
            <!-- 日历组件 -->
            <Card shadow="md" padding="lg">
              <PeriodCalendar :selected-date="selectedDate" @date-select="handleDateSelect" />
            </Card>

            <!-- 今日信息和健康提示 -->
            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-1 gap-4">
              <PeriodTodayInfo
                :current-phase-label="currentPhaseLabel"
                :days-until-next="daysUntilNext"
                :today-record="todayRecord"
                @view-record="openDailyForm"
                @delete-record="handleDeleteDailyRecord"
                @add-record="openDailyForm()"
              />

              <Card shadow="md" padding="lg" class="backdrop-blur-sm border-gray-200 dark:border-gray-700 hover:shadow-lg transition-shadow">
                <PeriodHealthTip :stats="currentPhase" />
              </Card>
            </div>
          </div>

          <!-- 最近记录 -->
          <PeriodRecentRecord @add-record="openRecordForm()" @edit-record="openRecordForm($event)" />
        </div>

        <!-- 设置视图 -->
        <div v-else-if="currentView === 'settings'">
          <Card shadow="md" padding="lg">
            <PeriodSettings />
          </Card>
        </div>
      </div>
    </div>

    <!-- 经期记录表单弹窗 -->
    <Modal
      :open="uiState.showRecordForm"
      size="lg"
      :show-header="false"
      :show-footer="false"
      @close="closeRecordForm"
    >
      <PeriodRecordForm
        :record="editingRecord"
        @create="handleRecordCreate"
        @update="handleRecordUpdate"
        @delete="handleRecordDelete"
        @cancel="closeRecordForm"
      />
    </Modal>

    <!-- 日常记录表单弹窗 -->
    <Modal
      :open="uiState.showDailyForm"
      size="md"
      :show-header="false"
      :show-footer="false"
      @close="closeDailyForm"
    >
      <PeriodDailyForm
        :date="selectedDate"
        :record="editingDailyRecord"
        @create="handleDailyRecordCreate"
        @update="handleDailyRecordUpdate"
        @delete="handleDailyRecordDelete"
        @cancel="closeDailyForm"
      />
    </Modal>

    <!-- 删除确认弹窗 -->
    <ConfirmDialog
      :open="uiState.showDeleteConfirm"
      type="error"
      :title="t('period.confirmations.deleteRecord')"
      :message="t('period.confirmations.deleteWarning')"
      confirm-text="确认删除"
      cancel-text="取消"
      icon-buttons
      @confirm="confirmDelete"
      @cancel="closeDeleteConfirm"
      @close="closeDeleteConfirm"
    />

    <!-- 加载状态 -->
    <div v-if="periodStore.loading" class="fixed inset-0 bg-black/50 backdrop-blur-sm flex items-center justify-center z-50">
      <div class="bg-white dark:bg-gray-800 rounded-xl shadow-2xl px-8 py-6 flex items-center gap-4">
        <Spinner size="lg" color="primary" />
        <span class="text-gray-900 dark:text-white font-medium">{{ t('common.processing') }}</span>
      </div>
    </div>
  </div>
</template>
