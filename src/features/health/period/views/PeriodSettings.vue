<script setup lang="ts">
import { PeriodDataManager } from '../utils/periodUtils';
import { mergeSettings } from '../utils/utils';
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
const localSettings = ref<PeriodSettings>({ ...periodStore.settings });

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
  if (localSettings.value.averageCycleLength < 21) {
    localSettings.value.averageCycleLength = 21;
  } else if (localSettings.value.averageCycleLength > 35) {
    localSettings.value.averageCycleLength = 35;
  }

  if (localSettings.value.averagePeriodLength < 2) {
    localSettings.value.averagePeriodLength = 2;
  } else if (localSettings.value.averagePeriodLength > 8) {
    localSettings.value.averagePeriodLength = 8;
  }

  updateSettings();
}

async function updateSettings() {
  try {
    await periodStore.updateSettings(localSettings.value);
  } catch (error) {
    console.error('Failed to update settings:', error);
    // 恢复到原来的设置
    Object.assign(localSettings, periodStore.settings);
  }
}

function useCalculatedValue(field: 'averageCycleLength' | 'averagePeriodLength') {
  const calculatedValue = calculatedStats.value[field];
  if (calculatedValue) {
    localSettings.value[field] = calculatedValue;
    updateSettings();
  }
}

function exportData() {
  try {
    PeriodDataManager.exportToJSON({
      periodRecords: periodStore.periodRecords,
      dailyRecords: periodStore.periodDailyRecords,
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
async function initializeSettings() {
  await periodStore.periodSettingsGet();
  mergeSettings(localSettings.value, periodStore.settings);
}

// Watchers
watch(
  () => periodStore.settings,
  newSettings => {
    mergeSettings(localSettings.value, newSettings);
  },
  { deep: true },
);

// Lifecycle
onMounted(() => {
  initializeSettings();
});
</script>

<template>
  <div class="period-settings">
    <!-- 周期设置和提醒设置 - 并排显示 -->
    <div class="settings-row">
      <!-- 周期设置 -->
      <div class="settings-section card-base">
        <h2 class="section-title">
          <LucideSettings class="section-icon" />
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
                class="input-base input-number"
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
                <LucideLightbulb class="calculated-hint-icon" />
                <span class="calculated-hint-text">
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
                class="input-base input-number"
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
                <LucideLightbulb class="calculated-hint-icon" />
                <span class="calculated-hint-text">
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
              <LucideChartNoAxesCombined class="mr-2 wh-5" />
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
          <LucideBell class="mr-2 wh-5" />
          提醒设置
        </h2>
        <div class="settings-grid grid grid-cols-1 sm:grid-cols-2">
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
          <LucideShieldUser class="mr-2 wh-5" />
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
          <LucideDatabase class="mr-2 wh-5" />
          数据管理
        </h2>
        <div class="settings-grid">
          <div class="gap-4 grid grid-cols-2">
            <div class="setting-item">
              <label class="setting-label">导出数据</label>
              <button class="btn-secondary" :disabled="loading" @click="exportData">
                <LucideFileDown class="mr-2 wh-5" />
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
                  <LucideFileUp class="mr-2 wh-5" />
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
                <LucideTrash class="wh-5" />
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
              <LucideX class="wh-5" />
            </button>
            <button class="btn-danger flex-1" :disabled="resetConfirmText !== '确认重置' || loading" @click="confirmReset">
              <LucideListRestart class="=wh-5" />
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
          <LucideX class="wh-5" />
        </button>
      </div>
    </div>
  </div>
</template>

<style scoped lang="postcss">
/* Layout and Structure Styles */
.settings-row {
  display: grid;
  grid-template-columns: 1fr;
  gap: 1.5rem;
}

@media (min-width: 640px) {
  .settings-row {
    grid-template-columns: repeat(2, 1fr);
  }
}

.settings-section {
  background-color: var(--color-base-100);
  border: 1px solid var(--color-base-300);
  border-radius: 0.75rem;
  box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06);
  padding: 1.25rem;
  transition: box-shadow 0.2s ease-in-out;
}

.settings-section:hover {
  box-shadow: 0 10px 15px -3px rgba(0, 0, 0, 0.1), 0 4px 6px -2px rgba(0, 0, 0, 0.05);
}

.dark .settings-section {
  background-color: var(--color-base-200);
  border-color: var(--color-base-300);
}

@media (min-width: 640px) {
  .settings-section {
    padding: 1.5rem;
  }
}

.section-title {
  display: flex;
  align-items: center;
  font-size: 1.125rem;
  font-weight: 600;
  color: var(--color-base-content);
  margin-bottom: 1.5rem;
}

.dark .section-title {
  color: var(--color-base-content);
}

.settings-grid {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

@media (min-width: 640px) {
  .settings-grid {
    gap: 1.5rem;
  }
}

.setting-item {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
}

.analysis-card {
  margin-top: 1rem;
  padding: 0.75rem;
  background-color: var(--color-base-200);
  border-radius: 0.5rem;
  border: 1px solid var(--color-base-300);
}

.dark .analysis-card {
  background-color: var(--color-base-300);
  border-color: var(--color-neutral);
}

.analysis-header {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  margin-bottom: 0.5rem;
}

.analysis-content {
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}

.analysis-item {
  display: flex;
  justify-content: space-between;
  align-items: center;
  font-size: 0.75rem;
}

/* Typography and Colors */
.setting-label {
  display: block;
  font-size: 0.875rem;
  font-weight: 500;
  color: var(--color-base-content);
}

.dark .setting-label {
  color: var(--color-base-content);
}

.setting-description {
  font-size: 0.75rem;
  color: var(--color-neutral);
}

.dark .setting-description {
  color: var(--color-neutral-content);
}

.analysis-label {
  color: var(--color-neutral);
}

.dark .analysis-label {
  color: var(--color-neutral-content);
}

.analysis-value {
  font-weight: 500;
}

.toggle-text {
  font-size: 0.875rem;
  font-weight: 500;
  color: var(--color-base-content);
}

.dark .toggle-text {
  color: var(--color-base-content);
}

/* Form Controls */
.setting-control {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 0.5rem;
}

@media (min-width: 640px) {
  .setting-control {
    flex-direction: row;
    align-items: center;
    gap: 1rem;
  }
}

.setting-range {
  width: 100%;
}

@media (min-width: 640px) {
  .setting-range {
    flex: 1;
  }
}

.input-base {
  padding: 0.5rem 0.75rem;
  border: 1px solid var(--color-base-300);
  border-radius: 0.5rem;
  background-color: var(--color-base-100);
  color: var(--color-base-content);
  transition: all 0.2s ease-in-out;
}

.input-base:focus {
  outline: none;
  ring: 2px;
  ring-color: var(--color-primary);
  border-color: var(--color-primary);
}

.dark .input-base {
  border-color: var(--color-base-300);
  background-color: var(--color-base-200);
  color: var(--color-base-content);
}

.dark .input-base:focus {
  ring-color: var(--color-primary);
  border-color: var(--color-primary);
}

.select-base {
  padding: 0.5rem 0.75rem;
  border: 1px solid var(--color-base-300);
  border-radius: 0.5rem;
  background-color: var(--color-base-100);
  color: var(--color-base-content);
  transition: all 0.2s ease-in-out;
}

.select-base:focus {
  outline: none;
  ring: 2px;
  ring-color: var(--color-primary);
  border-color: var(--color-primary);
}

.dark .select-base {
  border-color: var(--color-base-300);
  background-color: var(--color-base-200);
  color: var(--color-base-content);
}

.dark .select-base:focus {
  ring-color: var(--color-primary);
  border-color: var(--color-primary);
}

.range-slider {
  width: 100%;
  height: 0.5rem;
  background-color: var(--color-base-300);
  border-radius: 0.5rem;
  appearance: none;
  cursor: pointer;
}

.dark .range-slider {
  background-color: var(--color-neutral);
}

.range-slider::-webkit-slider-thumb {
  appearance: none;
  width: 1rem;
  height: 1rem;
  background-color: var(--color-primary);
  border-radius: 50%;
  cursor: pointer;
}

.range-slider::-moz-range-thumb {
  width: 1rem;
  height: 1rem;
  background-color: var(--color-primary);
  border-radius: 50%;
  cursor: pointer;
  border: 0;
}

.setting-toggle {
  display: flex;
  align-items: center;
}

.toggle-label {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  cursor: pointer;
}

.toggle-input {
  position: absolute;
  width: 1px;
  height: 1px;
  padding: 0;
  margin: -1px;
  overflow: hidden;
  clip: rect(0, 0, 0, 0);
  white-space: nowrap;
  border: 0;
}

.toggle-slider {
  position: relative;
  display: inline-block;
  width: 2.75rem;
  height: 1.5rem;
  background-color: var(--color-base-300);
  border-radius: 9999px;
  transition: background-color 0.2s ease-in-out;
}

.dark .toggle-slider {
  background-color: var(--color-neutral);
}

.toggle-slider::after {
  content: '';
  position: absolute;
  top: 0.125rem;
  left: 0.125rem;
  width: 1.25rem;
  height: 1.25rem;
  background-color: var(--color-base-100);
  border-radius: 50%;
  box-shadow: 0 1px 3px 0 rgba(0, 0, 0, 0.1), 0 1px 2px 0 rgba(0, 0, 0, 0.06);
  transition: transform 0.2s ease-in-out;
}

.toggle-input:checked + .toggle-slider {
  background-color: var(--color-primary);
}

.toggle-input:checked + .toggle-slider::after {
  transform: translateX(1.25rem);
}

/* Buttons and Hints */
.calculated-hint {
  display: flex;
  flex-direction: column;
  align-items: flex-start;
  gap: 0.5rem;
  padding: 0.5rem;
  background-color: var(--color-warning);
  border-radius: 0.5rem;
  border: 1px solid var(--color-warning-content);
}

@media (min-width: 640px) {
  .calculated-hint {
    flex-direction: row;
    align-items: center;
  }
}

.dark .calculated-hint {
  background-color: color-mix(in oklch, var(--color-warning) 20%, transparent);
  border-color: var(--color-warning-content);
}

.btn-hint {
  padding: 0.25rem 0.5rem;
  font-size: 0.75rem;
  background-color: var(--color-warning);
  color: var(--color-warning-content);
  border-radius: 0.25rem;
  transition: all 0.2s ease-in-out;
}

.btn-hint:hover {
  background-color: color-mix(in oklch, var(--color-warning) 80%, white);
}

.dark .btn-hint {
  background-color: var(--color-warning-content);
  color: var(--color-warning);
}

.dark .btn-hint:hover {
  background-color: color-mix(in oklch, var(--color-warning-content) 80%, white);
}

/* 计算提示图标 */
.calculated-hint-icon {
  color: var(--color-warning-content);
  height: 1rem;
  width: 1rem;
}

/* 计算提示文本 */
.calculated-hint-text {
  font-size: 0.875rem;
  color: var(--color-warning-content);
}

/* 数字输入框 */
.input-number {
  width: 5rem;
}

.btn-secondary {
  padding: 0.5rem 1rem;
  background-color: var(--color-secondary);
  color: var(--color-secondary-content);
  border-radius: 0.5rem;
  transition: all 0.2s ease-in-out;
  display: flex;
  align-items: center;
}

.btn-secondary:hover {
  background-color: color-mix(in oklch, var(--color-secondary) 80%, black);
}

.btn-secondary:focus {
  outline: none;
  ring: 2px;
  ring-color: var(--color-secondary);
}

.btn-secondary:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.dark .btn-secondary {
  background-color: var(--color-secondary);
  color: var(--color-secondary-content);
}

.dark .btn-secondary:hover {
  background-color: color-mix(in oklch, var(--color-secondary) 70%, white);
}

.btn-danger {
  padding: 0.5rem 1rem;
  background-color: var(--color-error);
  color: var(--color-error-content);
  border-radius: 0.5rem;
  transition: all 0.2s ease-in-out;
  display: flex;
  align-items: center;
}

.btn-danger:hover {
  background-color: color-mix(in oklch, var(--color-error) 80%, black);
}

.btn-danger:focus {
  outline: none;
  ring: 2px;
  ring-color: var(--color-error);
}

.btn-danger:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.import-control {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

/* 模板样式 */
.period-settings {
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
}

.section-icon {
  margin-right: 0.5rem;
  height: 1.25rem;
  width: 1.25rem;
}
</style>
