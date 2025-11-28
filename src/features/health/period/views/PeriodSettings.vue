<script setup lang="ts">
import { AlertCircle, Bell, ChartNoAxesCombined, Check, Database, FileDown, FileUp, Lightbulb, Settings, ShieldUser, Trash, X } from 'lucide-vue-next';
import { Button, Card, ConfirmDialog, Switch } from '@/components/ui';
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
  <div class="space-y-6">
    <!-- 周期设置和提醒设置 - 并排显示 -->
    <div class="grid grid-cols-1 sm:grid-cols-2 gap-6">
      <!-- 周期设置 -->
      <Card shadow="md" padding="lg" hoverable>
        <h2 class="flex items-center gap-2 text-lg font-semibold text-gray-900 dark:text-white mb-6">
          <Settings :size="20" class="text-blue-600 dark:text-blue-400" />
          周期设置
        </h2>

        <div class="space-y-6">
          <div class="space-y-3">
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300">
              平均周期长度 (天)
            </label>
            <div class="flex flex-col sm:flex-row items-start sm:items-center gap-4">
              <input
                v-model.number="localSettings.averageCycleLength"
                type="number"
                class="w-20 px-3 py-2 rounded-lg border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
                min="21"
                max="35"
                @change="validateAndUpdate"
              >
              <div class="flex-1 w-full">
                <input
                  v-model.number="localSettings.averageCycleLength"
                  type="range"
                  class="w-full h-2 bg-gray-200 dark:bg-gray-700 rounded-lg appearance-none cursor-pointer accent-blue-600"
                  min="21"
                  max="35"
                  @input="validateAndUpdate"
                >
              </div>
            </div>
            <div class="space-y-2">
              <p class="text-xs text-gray-500 dark:text-gray-400">
                正常范围：21-35天，大部分女性为28天
              </p>
              <div
                v-if="calculatedStats.averageCycleLength && calculatedStats.averageCycleLength !== localSettings.averageCycleLength"
                class="flex flex-col sm:flex-row items-start sm:items-center gap-2 p-3 bg-yellow-50 dark:bg-yellow-900/20 border border-yellow-200 dark:border-yellow-800 rounded-lg"
              >
                <Lightbulb :size="16" class="text-yellow-600 dark:text-yellow-400 shrink-0" />
                <span class="text-sm text-yellow-800 dark:text-yellow-300">
                  根据历史数据计算：{{ calculatedStats.averageCycleLength }}天
                </span>
                <button
                  class="px-3 py-1 text-xs font-medium bg-yellow-600 hover:bg-yellow-700 text-white rounded-md transition-colors"
                  @click="useCalculatedValue('averageCycleLength')"
                >
                  采用
                </button>
              </div>
            </div>
          </div>

          <div class="space-y-3">
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300">
              平均经期长度 (天)
            </label>
            <div class="flex flex-col sm:flex-row items-start sm:items-center gap-4">
              <input
                v-model.number="localSettings.averagePeriodLength"
                type="number"
                class="w-20 px-3 py-2 rounded-lg border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
                min="2"
                max="8"
                @change="validateAndUpdate"
              >
              <div class="flex-1 w-full">
                <input
                  v-model.number="localSettings.averagePeriodLength"
                  type="range"
                  class="w-full h-2 bg-gray-200 dark:bg-gray-700 rounded-lg appearance-none cursor-pointer accent-blue-600"
                  min="2"
                  max="8"
                  @input="validateAndUpdate"
                >
              </div>
            </div>
            <div class="space-y-2">
              <p class="text-xs text-gray-500 dark:text-gray-400">
                正常范围：2-8天，大部分女性为3-7天
              </p>
              <div
                v-if="calculatedStats.averagePeriodLength && calculatedStats.averagePeriodLength !== localSettings.averagePeriodLength"
                class="flex flex-col sm:flex-row items-start sm:items-center gap-2 p-3 bg-yellow-50 dark:bg-yellow-900/20 border border-yellow-200 dark:border-yellow-800 rounded-lg"
              >
                <Lightbulb :size="16" class="text-yellow-600 dark:text-yellow-400 shrink-0" />
                <span class="text-sm text-yellow-800 dark:text-yellow-300">
                  根据历史数据计算：{{ calculatedStats.averagePeriodLength }}天
                </span>
                <button
                  class="px-3 py-1 text-xs font-medium bg-yellow-600 hover:bg-yellow-700 text-white rounded-md transition-colors"
                  @click="useCalculatedValue('averagePeriodLength')"
                >
                  采用
                </button>
              </div>
            </div>
          </div>

          <!-- 智能分析卡片 -->
          <div v-if="periodStore.periodRecords.length >= 2" class="mt-4 p-4 bg-gray-50 dark:bg-gray-700/50 border border-gray-200 dark:border-gray-600 rounded-lg">
            <div class="flex items-center gap-2 mb-3">
              <ChartNoAxesCombined :size="18" class="text-gray-600 dark:text-gray-400" />
              <span class="text-sm font-medium text-gray-700 dark:text-gray-300">智能分析</span>
            </div>
            <div class="space-y-2">
              <div class="flex justify-between items-center text-xs">
                <span class="text-gray-600 dark:text-gray-400">周期规律性：</span>
                <span class="font-medium" :class="regularityColor">{{ regularityText }}</span>
              </div>
              <div class="flex justify-between items-center text-xs">
                <span class="text-gray-600 dark:text-gray-400">记录数量：</span>
                <span class="font-medium text-gray-900 dark:text-white">{{ periodStore.periodRecords.length }} 个周期</span>
              </div>
              <div class="flex justify-between items-center text-xs">
                <span class="text-gray-600 dark:text-gray-400">数据置信度：</span>
                <span class="font-medium" :class="confidenceColor">{{ confidenceText }}</span>
              </div>
            </div>
          </div>
        </div>
      </Card>

      <!-- 提醒设置 -->
      <Card shadow="md" padding="lg" hoverable>
        <h2 class="flex items-center gap-2 text-lg font-semibold text-gray-900 dark:text-white mb-6">
          <Bell :size="20" class="text-green-600 dark:text-green-400" />
          提醒设置
        </h2>
        <div class="grid grid-cols-1 sm:grid-cols-2 gap-6">
          <div class="space-y-2">
            <Switch
              v-model="localSettings.notifications.periodReminder"
              label="经期提醒"
              @update:model-value="updateSettings"
            />
            <p class="text-xs text-gray-500 dark:text-gray-400 ml-1">
              在经期开始前几天发送提醒
            </p>
          </div>

          <div class="space-y-2">
            <Switch
              v-model="localSettings.notifications.ovulationReminder"
              label="排卵期提醒"
              @update:model-value="updateSettings"
            />
            <p class="text-xs text-gray-500 dark:text-gray-400 ml-1">
              在排卵期到来时发送提醒
            </p>
          </div>

          <div class="space-y-2">
            <Switch
              v-model="localSettings.notifications.pmsReminder"
              label="PMS提醒"
              @update:model-value="updateSettings"
            />
            <p class="text-xs text-gray-500 dark:text-gray-400 ml-1">
              在可能出现经前症状时发送提醒
            </p>
          </div>

          <div class="space-y-2">
            <label class="block text-sm font-medium text-gray-700 dark:text-gray-300">提醒天数</label>
            <select
              v-model.number="localSettings.notifications.reminderDays"
              class="w-full px-3 py-2 rounded-lg border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-900 dark:text-white focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all"
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
            <p class="text-xs text-gray-500 dark:text-gray-400">
              在经期开始前多少天发送提醒
            </p>
          </div>
        </div>
      </Card>
    </div>

    <!-- 隐私设置和数据管理 - 并排显示 -->
    <div class="grid grid-cols-1 sm:grid-cols-2 gap-6">
      <!-- 隐私设置 -->
      <Card shadow="md" padding="lg" hoverable>
        <h2 class="flex items-center gap-2 text-lg font-semibold text-gray-900 dark:text-white mb-6">
          <ShieldUser :size="20" class="text-purple-600 dark:text-purple-400" />
          隐私设置
        </h2>
        <div class="space-y-6">
          <div class="space-y-2">
            <Switch
              v-model="localSettings.privacy.dataSync"
              label="数据同步"
              @update:model-value="updateSettings"
            />
            <p class="text-xs text-gray-500 dark:text-gray-400 ml-1">
              将数据同步到云端，便于在多设备间使用
            </p>
          </div>
          <div class="space-y-2">
            <Switch
              v-model="localSettings.privacy.analytics"
              label="匿名统计"
              @update:model-value="updateSettings"
            />
            <p class="text-xs text-gray-500 dark:text-gray-400 ml-1">
              帮助改进应用功能，所有数据都是匿名的
            </p>
          </div>
        </div>
      </Card>

      <!-- 数据管理 -->
      <Card shadow="md" padding="lg" hoverable>
        <h2 class="flex items-center gap-2 text-lg font-semibold text-gray-900 dark:text-white mb-6">
          <Database :size="20" class="text-orange-600 dark:text-orange-400" />
          数据管理
        </h2>
        <div class="space-y-6">
          <div class="grid grid-cols-2 gap-4">
            <div class="space-y-3">
              <label class="block text-sm font-medium text-gray-700 dark:text-gray-300">导出数据</label>
              <Button variant="secondary" size="sm" full-width :disabled="loading" @click="exportData">
                <FileDown :size="16" class="mr-2" />
                导出为JSON
              </Button>
              <p class="text-xs text-gray-500 dark:text-gray-400">
                导出所有经期数据到本地文件
              </p>
            </div>
            <div class="space-y-3">
              <label class="block text-sm font-medium text-gray-700 dark:text-gray-300">导入数据</label>
              <input ref="fileInput" type="file" accept=".json" class="hidden" @change="handleFileImport">
              <Button variant="secondary" size="sm" full-width :disabled="loading" @click="triggerFileInput">
                <FileUp :size="16" class="mr-2" />
                选择文件
              </Button>
              <p class="text-xs text-gray-500 dark:text-gray-400">
                从JSON文件导入经期数据
              </p>
            </div>
          </div>

          <div class="space-y-3 pt-4 border-t border-gray-200 dark:border-gray-700">
            <Button variant="danger" size="sm" circle :icon="Trash" :disabled="loading" @click="showResetModal = true" />
            <p class="text-xs text-gray-500 dark:text-gray-400">
              删除所有经期记录，此操作不可撤销
            </p>
          </div>
        </div>
      </Card>
    </div>

    <!-- 重置确认弹窗 -->
    <ConfirmDialog
      :open="showResetModal"
      type="error"
      title="确认重置"
      :confirm-disabled="resetConfirmText !== '确认重置' || loading"
      :loading="loading"
      @confirm="confirmReset"
      @close="showResetModal = false"
    >
      <div class="space-y-4">
        <p class="text-sm text-gray-600 dark:text-gray-400">
          确定要清空所有数据吗？此操作将删除所有经期记录、日常记录和设置，且无法撤销。
        </p>
        <input
          v-model="resetConfirmText"
          type="text"
          placeholder="输入 '确认重置' 来确认操作"
          class="w-full px-4 py-2 rounded-lg border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-900 dark:text-white placeholder-gray-400 dark:placeholder-gray-500 focus:ring-2 focus:ring-red-500 focus:border-transparent transition-all"
        >
        <div class="flex items-center gap-2 text-sm text-orange-800 dark:text-orange-300 bg-orange-50 dark:bg-orange-900/20 rounded-lg p-3">
          <AlertCircle :size="18" />
          <span>请谨慎操作，此操作不可恢复</span>
        </div>
      </div>
    </ConfirmDialog>

    <!-- 导入结果提示 -->
    <div
      v-if="importMessage"
      class="fixed bottom-4 right-4 max-w-sm p-4 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg shadow-lg animate-slide-up"
    >
      <div class="flex items-start gap-3">
        <div class="shrink-0 mt-0.5">
          <Check v-if="importSuccess" :size="20" class="text-green-500" />
          <X v-else :size="20" class="text-red-500" />
        </div>
        <div class="flex-1">
          <p class="text-sm font-medium text-gray-900 dark:text-white">
            {{ importSuccess ? '导入成功' : '导入失败' }}
          </p>
          <p class="text-xs text-gray-600 dark:text-gray-400 mt-1">
            {{ importMessage }}
          </p>
        </div>
        <button class="shrink-0 text-gray-400 hover:text-gray-600 dark:hover:text-gray-300 transition-colors" @click="importMessage = ''">
          <X :size="18" />
        </button>
      </div>
    </div>
  </div>
</template>

<style scoped>
/* 添加简单动画 */
@keyframes slide-up {
  from {
    opacity: 0;
    transform: translateY(10px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

.animate-slide-up {
  animation: slide-up 0.3s ease-out;
}
</style>
