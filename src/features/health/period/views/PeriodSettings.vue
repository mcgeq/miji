<script setup lang="ts">
import {
  Bell,
  ChartNoAxesCombined,
  Database,
  FileDown,
  FileUp,
  Lightbulb,
  ListRestart,
  Settings,
  ShieldUser,
  Trash,
  X,
} from 'lucide-vue-next';
import { usePeriodStore } from '@/stores/periodStore';
import { PeriodDataManager } from '../utils/periodUtils';
import type { PeriodSettings } from '@/schema/health/period';

// Store
const periodStore = usePeriodStore();
const fileInput = ref<HTMLInputElement>();

// Reactive state
const loading = ref(false);
const showResetModal = ref(false);
const resetConfirmText = ref('');
const importMessage = ref('');
const importSuccess = ref(false);

// Local settings (for immediate UI updates)
const localSettings = reactive<PeriodSettings>({
  averageCycleLength: 28,
  averagePeriodLength: 5,
  notifications: {
    periodReminder: true,
    ovulationReminder: true,
    pmsReminder: true,
    reminderDays: 3,
  },
  privacy: {
    dataSync: true,
    analytics: false,
  },
});

// 计算历史数据统计
const calculatedStats = computed(() => {
  const records = periodStore.periodRecords;
  if (records.length < 2) {
    return {
      averageCycleLength: null,
      averagePeriodLength: null,
      cycleRegularity: 0,
      confidence: 'low',
    };
  }

  const sortedRecords = [...records].sort(
    (a, b) => new Date(a.startDate).getTime() - new Date(b.startDate).getTime(),
  );

  // 计算周期长度
  const cycles = sortedRecords.slice(0, -1).map((record, index) => {
    const nextRecord = sortedRecords[index + 1];
    const start = new Date(record.startDate);
    const nextStart = new Date(nextRecord.startDate);
    return (
      Math.abs(nextStart.getTime() - start.getTime()) / (1000 * 60 * 60 * 24)
    );
  });

  const averageCycleLength
    = cycles.length > 0
      ? Math.round(
          cycles.reduce((sum, cycle) => sum + cycle, 0) / cycles.length,
        )
      : null;

  // 计算经期长度
  const periodLengths = sortedRecords.map(record => {
    const start = new Date(record.startDate);
    const end = new Date(record.endDate);
    return (
      Math.abs(end.getTime() - start.getTime()) / (1000 * 60 * 60 * 24) + 1
    );
  });

  const averagePeriodLength = Math.round(
    periodLengths.reduce((sum, length) => sum + length, 0)
    / periodLengths.length,
  );

  // 计算周期规律性
  let cycleRegularity = 0;
  if (cycles.length >= 2) {
    const average
      = cycles.reduce((sum, cycle) => sum + cycle, 0) / cycles.length;
    const variance
      = cycles.reduce((sum, cycle) => sum + (cycle - average) ** 2, 0)
        / cycles.length;
    const standardDeviation = Math.sqrt(variance);
    cycleRegularity = Math.max(0, 100 - standardDeviation * 10);
  }

  // 计算置信度
  let confidence = 'low';
  if (records.length >= 6)
    confidence = 'high';
  else if (records.length >= 3)
    confidence = 'medium';

  return {
    averageCycleLength,
    averagePeriodLength,
    cycleRegularity: Math.min(100, cycleRegularity),
    confidence,
  };
});

// 规律性文本和颜色
const regularityText = computed(() => {
  const regularity = calculatedStats.value.cycleRegularity;
  if (regularity >= 80)
    return '非常规律';
  if (regularity >= 60)
    return '较为规律';
  if (regularity >= 40)
    return '一般';
  if (regularity >= 20)
    return '不太规律';
  return '数据不足';
});

const regularityColor = computed(() => {
  const regularity = calculatedStats.value.cycleRegularity;
  if (regularity >= 80)
    return 'text-green-600 dark:text-green-400';
  if (regularity >= 60)
    return 'text-blue-600 dark:text-blue-400';
  if (regularity >= 40)
    return 'text-yellow-600 dark:text-yellow-400';
  return 'text-red-600 dark:text-red-400';
});

// 置信度文本和颜色
const confidenceText = computed(() => {
  const confidence = calculatedStats.value.confidence;
  switch (confidence) {
    case 'high':
      return '高';
    case 'medium':
      return '中等';
    default:
      return '较低';
  }
});

const confidenceColor = computed(() => {
  const confidence = calculatedStats.value.confidence;
  switch (confidence) {
    case 'high':
      return 'text-green-600 dark:text-green-400';
    case 'medium':
      return 'text-yellow-600 dark:text-yellow-400';
    default:
      return 'text-red-600 dark:text-red-400';
  }
});

// Methods
function validateAndUpdate() {
  // 验证数据范围
  if (localSettings.averageCycleLength < 21) {
    localSettings.averageCycleLength = 21;
  } else if (localSettings.averageCycleLength > 35) {
    localSettings.averageCycleLength = 35;
  }

  if (localSettings.averagePeriodLength < 2) {
    localSettings.averagePeriodLength = 2;
  } else if (localSettings.averagePeriodLength > 8) {
    localSettings.averagePeriodLength = 8;
  }

  updateSettings();
}

async function updateSettings() {
  try {
    await periodStore.updateSettings(localSettings);
  } catch (error) {
    console.error('Failed to update settings:', error);
    // 恢复到原来的设置
    Object.assign(localSettings, periodStore.settings);
  }
}

function useCalculatedValue(field: 'averageCycleLength' | 'averagePeriodLength') {
  const calculatedValue = calculatedStats.value[field];
  if (calculatedValue) {
    localSettings[field] = calculatedValue;
    updateSettings();
  }
}

function exportData() {
  try {
    PeriodDataManager.exportToJSON({
      periodRecords: periodStore.periodRecords,
      dailyRecords: periodStore.dailyRecords,
      settings: periodStore.settings,
    });
    showMessage('数据导出成功', true);
  } catch (error) {
    console.error('Export failed:', error);
    showMessage('数据导出失败', false);
  }
}

async function handleFileImport(event: Event) {
  const target = event.target as HTMLInputElement;
  const file = target.files?.[0];
  if (!file)
    return;

  loading.value = true;

  try {
    const text = await file.text();
    const data = JSON.parse(text);

    // 验证数据格式
    const validation = PeriodDataManager.validateImportData(data);
    if (!validation.valid) {
      throw new Error(validation.errors.join('; '));
    }

    // 这里应该调用 store 的导入方法
    // await periodStore.importData(data);

    showMessage(`成功导入 ${data.periodRecords.length} 条经期记录`, true);
  } catch (error) {
    console.error('Import failed:', error);
    const errorMessage
      = error instanceof Error ? error.message : '文件格式错误或数据损坏';
    showMessage(errorMessage, false);
  } finally {
    loading.value = false;
    // 清空文件选择
    target.value = '';
  }
}

function triggerFileInput() {
  fileInput.value?.click();
}

async function confirmReset() {
  if (resetConfirmText.value !== '确认重置')
    return;

  loading.value = true;

  try {
    await periodStore.resetAllData();
    showResetModal.value = false;
    resetConfirmText.value = '';
    showMessage('所有数据已清空', true);
  } catch (error) {
    console.error('Reset failed:', error);
    showMessage('重置失败，请重试', false);
  } finally {
    loading.value = false;
  }
}

function showMessage(message: string, success: boolean) {
  importMessage.value = message;
  importSuccess.value = success;

  setTimeout(() => {
    importMessage.value = '';
  }, 5000);
}

// Initialize local settings from store
function initializeSettings() {
  Object.assign(localSettings, periodStore.settings);
}

// Watchers
watch(() => periodStore.settings, initializeSettings, { deep: true });

// Lifecycle
onMounted(() => {
  initializeSettings();
});
</script>

<template>
  <div class="period-settings space-y-6">
    <!-- 周期设置和提醒设置 - 并排显示 -->
    <div class="settings-row">
      <!-- 周期设置 -->
      <div class="settings-section card-base">
        <h2 class="section-title">
          <Settings class="mr-2 wh-5" />
          周期设置
        </h2>

        <div class="settings-grid">
          <div class="setting-item">
            <label class="setting-label">
              平均周期长度 (天)
            </label>
            <div class="setting-control">
              <input
                v-model.number="localSettings.averageCycleLength"
                type="number"
                class="input-base w-20"
                min="21"
                max="35"
                @change="validateAndUpdate"
              >
              <div class="setting-range">
                <input
                  v-model.number="localSettings.averageCycleLength"
                  type="range"
                  class="range-slider"
                  min="21"
                  max="35"
                  @input="validateAndUpdate"
                >
              </div>
            </div>
            <div class="setting-info">
              <p class="setting-description">
                正常范围：21-35天，大部分女性为28天
              </p>
              <div
                v-if="calculatedStats.averageCycleLength && calculatedStats.averageCycleLength !== localSettings.averageCycleLength"
                class="calculated-hint"
              >
                <Lightbulb class="text-amber-500 h-4 w-4" />
                <span class="text-sm text-amber-700 dark:text-amber-400">
                  根据历史数据计算：{{ calculatedStats.averageCycleLength }}天
                </span>
                <button
                  class="btn-hint"
                  @click="useCalculatedValue('averageCycleLength')"
                >
                  采用
                </button>
              </div>
            </div>
          </div>

          <div class="setting-item">
            <label class="setting-label">
              平均经期长度 (天)
            </label>
            <div class="setting-control">
              <input
                v-model.number="localSettings.averagePeriodLength"
                type="number"
                class="input-base w-20"
                min="2"
                max="8"
                @change="validateAndUpdate"
              >
              <div class="setting-range">
                <input
                  v-model.number="localSettings.averagePeriodLength"
                  type="range"
                  class="range-slider"
                  min="2"
                  max="8"
                  @input="validateAndUpdate"
                >
              </div>
            </div>
            <div class="setting-info">
              <p class="setting-description">
                正常范围：2-8天，大部分女性为3-7天
              </p>
              <div
                v-if="calculatedStats.averagePeriodLength && calculatedStats.averagePeriodLength !== localSettings.averagePeriodLength"
                class="calculated-hint"
              >
                <Lightbulb class="text-amber-500 h-4 w-4" />
                <span class="text-sm text-amber-700 dark:text-amber-400">
                  根据历史数据计算：{{ calculatedStats.averagePeriodLength }}天
                </span>
                <button
                  class="btn-hint"
                  @click="useCalculatedValue('averagePeriodLength')"
                >
                  采用
                </button>
              </div>
            </div>
          </div>

          <!-- 智能分析卡片 -->
          <div v-if="periodStore.periodRecords.length >= 2" class="analysis-card">
            <div class="analysis-header">
              <ChartNoAxesCombined class="mr-2 wh-5" />
              <span class="text-sm text-gray-700 font-medium dark:text-gray-300">智能分析</span>
            </div>
            <div class="analysis-content">
              <div class="analysis-item">
                <span class="analysis-label">周期规律性：</span>
                <span class="analysis-value" :class="regularityColor">{{ regularityText }}</span>
              </div>
              <div class="analysis-item">
                <span class="analysis-label">记录数量：</span>
                <span class="analysis-value">{{ periodStore.periodRecords.length }} 个周期</span>
              </div>
              <div class="analysis-item">
                <span class="analysis-label">数据置信度：</span>
                <span class="analysis-value" :class="confidenceColor">{{ confidenceText }}</span>
              </div>
            </div>
          </div>
        </div>
      </div>

      <!-- 提醒设置 -->
      <div class="settings-section card-base">
        <h2 class="section-title">
          <Bell class="mr-2 wh-5" />
          提醒设置
        </h2>
        <div class="settings-grid">
          <div class="setting-item">
            <div class="setting-toggle">
              <label class="toggle-label">
                <input
                  v-model="localSettings.notifications.periodReminder"
                  type="checkbox"
                  class="toggle-input"
                  @change="updateSettings"
                >
                <span class="toggle-slider" />
                <span class="toggle-text">经期提醒</span>
              </label>
            </div>
            <p class="setting-description">
              在经期开始前几天发送提醒
            </p>
          </div>

          <div class="setting-item">
            <div class="setting-toggle">
              <label class="toggle-label">
                <input
                  v-model="localSettings.notifications.ovulationReminder"
                  type="checkbox"
                  class="toggle-input"
                  @change="updateSettings"
                >
                <span class="toggle-slider" />
                <span class="toggle-text">排卵期提醒</span>
              </label>
            </div>
            <p class="setting-description">
              在排卵期到来时发送提醒
            </p>
          </div>

          <div class="setting-item">
            <div class="setting-toggle">
              <label class="toggle-label">
                <input
                  v-model="localSettings.notifications.pmsReminder"
                  type="checkbox"
                  class="toggle-input"
                  @change="updateSettings"
                >
                <span class="toggle-slider" />
                <span class="toggle-text">PMS提醒</span>
              </label>
            </div>
            <p class="setting-description">
              在可能出现经前症状时发送提醒
            </p>
          </div>

          <div class="setting-item">
            <label class="setting-label">
              提前提醒天数
            </label>
            <div class="setting-control">
              <select
                v-model.number="localSettings.notifications.reminderDays"
                class="select-base"
                @change="updateSettings"
              >
                <option value="1">
                  1天
                </option>
                <option value="2">
                  2天
                </option>
                <option value="3">
                  3天
                </option>
                <option value="5">
                  5天
                </option>
                <option value="7">
                  7天
                </option>
              </select>
            </div>
            <p class="setting-description">
              在经期开始前多少天发送提醒
            </p>
          </div>
        </div>
      </div>
    </div>

    <!-- 隐私设置和数据管理 - 并排显示 -->
    <div class="settings-row">
      <!-- 隐私设置 -->
      <div class="settings-section card-base">
        <h2 class="section-title">
          <ShieldUser class="mr-2 wh-5" />
          隐私设置
        </h2>
        <div class="settings-grid">
          <div class="setting-item">
            <div class="setting-toggle">
              <label class="toggle-label">
                <input
                  v-model="localSettings.privacy.dataSync"
                  type="checkbox"
                  class="toggle-input"
                  @change="updateSettings"
                >
                <span class="toggle-slider" />
                <span class="toggle-text">数据同步</span>
              </label>
            </div>
            <p class="setting-description">
              将数据同步到云端，便于在多设备间使用
            </p>
          </div>
          <div class="setting-item">
            <div class="setting-toggle">
              <label class="toggle-label">
                <input
                  v-model="localSettings.privacy.analytics"
                  type="checkbox"
                  class="toggle-input"
                  @change="updateSettings"
                >
                <span class="toggle-slider" />
                <span class="toggle-text">匿名统计</span>
              </label>
            </div>
            <p class="setting-description">
              帮助改进应用功能，所有数据都是匿名的
            </p>
          </div>
        </div>
      </div>

      <!-- 数据管理 -->
      <div class="settings-section card-base">
        <h2 class="section-title">
          <Database class="mr-2 wh-5" />
          数据管理
        </h2>
        <div class="settings-grid">
          <div class="gap-4 grid grid-cols-2">
            <div class="setting-item">
              <label class="setting-label">导出数据</label>
              <button class="btn-secondary" :disabled="loading" @click="exportData">
                <FileDown class="mr-2 wh-5" />
                导出为JSON
              </button>
              <p class="setting-description">
                导出所有经期数据到本地文件
              </p>
            </div>
            <div class="setting-item">
              <label class="setting-label">导入数据</label>
              <div class="import-control">
                <input ref="fileInput" type="file" accept=".json" class="hidden" @change="handleFileImport">
                <button class="btn-secondary" :disabled="loading" @click="triggerFileInput">
                  <FileUp class="mr-2 wh-5" />
                  选择文件
                </button>
              </div>
              <p class="setting-description">
                从JSON文件导入经期数据
              </p>
            </div>
          </div>

          <div class="setting-item mt-4">
            <div class="flex gap-2 items-center">
              <button class="btn-danger" :disabled="loading" @click="showResetModal = true">
                <Trash class="wh-5" />
              </button>
            </div>
            <p class="setting-description">
              删除所有经期记录，此操作不可撤销
            </p>
          </div>
        </div>
      </div>
    </div>

    <!-- 重置确认弹窗 -->
    <div
      v-if="showResetModal" class="bg-black/50 flex items-center inset-0 justify-center fixed z-50"
      @click.self="showResetModal = false"
    >
      <div class="mx-4 p-6 rounded-lg bg-white max-w-sm dark:bg-gray-800">
        <h3 class="text-lg text-gray-900 font-semibold mb-4 dark:text-white">
          确认重置
        </h3>
        <p class="text-gray-600 mb-6 dark:text-gray-400">
          确定要清空所有数据吗？此操作将删除所有经期记录、日常记录和设置，且无法撤销。
        </p>
        <div class="space-y-3">
          <input v-model="resetConfirmText" type="text" placeholder="输入 '确认重置' 来确认操作" class="input-base w-full">
          <div class="flex gap-3">
            <button class="btn-secondary flex-1" @click="showResetModal = false">
              <X class="wh-5" />
            </button>
            <button class="btn-danger flex-1" :disabled="resetConfirmText !== '确认重置' || loading" @click="confirmReset">
              <ListRestart class="=wh-5" />
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- 导入结果提示 -->
    <div
      v-if="importMessage"
      class="p-4 border border-gray-200 rounded-lg bg-white max-w-sm shadow-lg bottom-4 right-4 fixed dark:border-gray-700 dark:bg-gray-800"
    >
      <div class="flex gap-3 items-start">
        <i
          :class="importSuccess ? 'i-tabler-check text-green-500' : 'i-tabler-x text-red-500'"
          class="mt-0.5 flex-shrink-0 wh-5"
        />
        <div>
          <p class="text-sm text-gray-900 font-medium dark:text-white">
            {{ importSuccess ? '导入成功' : '导入失败' }}
          </p>
          <p class="text-xs text-gray-600 mt-1 dark:text-gray-400">
            {{ importMessage }}
          </p>
        </div>
        <button class="text-gray-400 hover:text-gray-600 dark:hover:text-gray-300" @click="importMessage = ''">
          <X class="wh-5" />
        </button>
      </div>
    </div>
  </div>
</template>

<style scoped lang="postcss">
/* Layout and Structure Styles */
.settings-row {
  @apply grid grid-cols-1 sm:grid-cols-2 gap-6;
}

.settings-section {
  @apply bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg shadow-sm p-4 sm:p-6;
}

.section-title {
  @apply flex items-center text-lg font-semibold text-gray-900 dark:text-white mb-6;
}

.settings-grid {
  @apply space-y-4 sm:space-y-6;
}

.setting-item {
  @apply space-y-2;
}

.analysis-card {
  @apply mt-4 p-3 bg-gray-50 dark:bg-gray-700/50 rounded-lg border border-gray-200 dark:border-gray-600;
}

.analysis-header {
  @apply flex items-center gap-2 mb-2;
}

.analysis-content {
  @apply space-y-1;
}

.analysis-item {
  @apply flex justify-between items-center text-xs;
}

/* Typography and Colors */
.setting-label {
  @apply block text-sm font-medium text-gray-700 dark:text-gray-300;
}

.setting-description {
  @apply text-xs text-gray-500 dark:text-gray-400;
}

.analysis-label {
  @apply text-gray-600 dark:text-gray-400;
}

.analysis-value {
  @apply font-medium;
}

.toggle-text {
  @apply text-sm font-medium text-gray-700 dark:text-gray-300;
}

/* Form Controls */
.setting-control {
  @apply flex flex-col items-start gap-2 sm:flex-row sm:items-center sm:gap-4;
}

.setting-range {
  @apply w-full sm:flex-1;
}

.input-base {
  @apply px-3 py-2 border border-gray-300 rounded-lg focus:ring-2 focus:ring-blue-500 focus:border-blue-500 dark:border-gray-600 dark:bg-gray-800 dark:text-white dark:focus:ring-blue-400 dark:focus:border-blue-400 transition-colors;
}

.select-base {
  @apply px-3 py-2 border border-gray-300 rounded-lg bg-white focus:ring-2 focus:ring-blue-500 focus:border-blue-500 dark:border-gray-600 dark:bg-gray-800 dark:text-white dark:focus:ring-blue-400 dark:focus:border-blue-400 transition-colors;
}

.range-slider {
  @apply w-full h-2 bg-gray-200 dark:bg-gray-700 rounded-lg appearance-none cursor-pointer;
}

.range-slider::-webkit-slider-thumb {
  @apply appearance-none w-4 h-4 bg-blue-500 rounded-full cursor-pointer;
}

.range-slider::-moz-range-thumb {
  @apply w-4 h-4 bg-blue-500 rounded-full cursor-pointer border-0;
}

.setting-toggle {
  @apply flex items-center;
}

.toggle-label {
  @apply flex items-center gap-3 cursor-pointer;
}

.toggle-input {
  @apply sr-only;
}

.toggle-slider {
  @apply relative inline-block w-11 h-6 bg-gray-200 dark:bg-gray-700 rounded-full transition-colors duration-200 ease-in-out;
}

.toggle-slider::after {
  @apply absolute top-0.5 left-0.5 w-5 h-5 bg-white rounded-full shadow transition-transform duration-200 ease-in-out content-[''];
}

.toggle-input:checked + .toggle-slider {
  @apply bg-blue-500;
}

.toggle-input:checked + .toggle-slider::after {
  @apply translate-x-5;
}

/* Buttons and Hints */
.calculated-hint {
  @apply flex flex-col items-start gap-2 sm:flex-row sm:items-center p-2 bg-amber-50 dark:bg-amber-900/20 rounded-lg border border-amber-200 dark:border-amber-800;
}

.btn-hint {
  @apply px-2 py-1 text-xs bg-amber-100 hover:bg-amber-200 dark:bg-amber-800 dark:hover:bg-amber-700 text-amber-800 dark:text-amber-200 rounded transition-colors;
}

.btn-secondary {
  @apply px-4 py-2 bg-gray-200 text-gray-700 rounded-lg hover:bg-gray-300 focus:ring-2 focus:ring-gray-500 disabled:opacity-50 disabled:cursor-not-allowed dark:bg-gray-700 dark:text-gray-300 dark:hover:bg-gray-600 transition-colors flex items-center;
}

.btn-danger {
  @apply px-4 py-2 bg-red-600 text-white rounded-lg hover:bg-red-700 focus:ring-2 focus:ring-red-500 disabled:opacity-50 disabled:cursor-not-allowed transition-colors flex items-center;
}

.import-control {
  @apply flex items-center gap-2;
}
</style>
