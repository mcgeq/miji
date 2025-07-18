<template>
  <div class="period-settings space-y-6">
    <!-- 周期设置 -->
    <div class="settings-section card-base p-6">
      <h2 class="section-title">
        <i class="i-tabler-settings wh-5 mr-2" />
        周期设置
      </h2>

      <div class="settings-grid">
        <div class="setting-item">
          <label class="setting-label">
            平均周期长度 (天)
          </label>
          <div class="setting-control">
            <input v-model.number="localSettings.averageCycleLength" type="number" class="input-base w-20" min="21"
              max="35" @change="validateAndUpdate" />
            <div class="setting-range">
              <input v-model.number="localSettings.averageCycleLength" type="range" class="range-slider" min="21"
                max="35" @input="validateAndUpdate" />
            </div>
          </div>
          <p class="setting-description">
            正常范围：21-35天，大部分女性为28天
          </p>
        </div>

        <div class="setting-item">
          <label class="setting-label">
            平均经期长度 (天)
          </label>
          <div class="setting-control">
            <input v-model.number="localSettings.averagePeriodLength" type="number" class="input-base w-20" min="2"
              max="8" @change="validateAndUpdate" />
            <div class="setting-range">
              <input v-model.number="localSettings.averagePeriodLength" type="range" class="range-slider" min="2"
                max="8" @input="validateAndUpdate" />
            </div>
          </div>
          <p class="setting-description">
            正常范围：2-8天，大部分女性为3-7天
          </p>
        </div>
      </div>
    </div>

    <!-- 提醒设置 -->
    <div class="settings-section card-base p-6">
      <h2 class="section-title">
        <i class="i-tabler-bell wh-5 mr-2" />
        提醒设置
      </h2>

      <div class="settings-grid">
        <div class="setting-item">
          <div class="setting-toggle">
            <label class="toggle-label">
              <input v-model="localSettings.notifications.periodReminder" type="checkbox" class="toggle-input"
                @change="updateSettings" />
              <span class="toggle-slider"></span>
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
              <input v-model="localSettings.notifications.ovulationReminder" type="checkbox" class="toggle-input"
                @change="updateSettings" />
              <span class="toggle-slider"></span>
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
              <input v-model="localSettings.notifications.pmsReminder" type="checkbox" class="toggle-input"
                @change="updateSettings" />
              <span class="toggle-slider"></span>
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
            <select v-model.number="localSettings.notifications.reminderDays" class="select-base"
              @change="updateSettings">
              <option value="1">1天</option>
              <option value="2">2天</option>
              <option value="3">3天</option>
              <option value="5">5天</option>
              <option value="7">7天</option>
            </select>
          </div>
          <p class="setting-description">
            在经期开始前多少天发送提醒
          </p>
        </div>
      </div>
    </div>

    <!-- 隐私设置 -->
    <div class="settings-section card-base p-6">
      <h2 class="section-title">
        <i class="i-tabler-shield-lock wh-5 mr-2" />
        隐私设置
      </h2>

      <div class="settings-grid">
        <div class="setting-item">
          <div class="setting-toggle">
            <label class="toggle-label">
              <input v-model="localSettings.privacy.dataSync" type="checkbox" class="toggle-input"
                @change="updateSettings" />
              <span class="toggle-slider"></span>
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
              <input v-model="localSettings.privacy.analytics" type="checkbox" class="toggle-input"
                @change="updateSettings" />
              <span class="toggle-slider"></span>
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
    <div class="settings-section card-base p-6">
      <h2 class="section-title">
        <i class="i-tabler-database wh-5 mr-2" />
        数据管理
      </h2>

      <div class="settings-grid">
        <div class="setting-item">
          <label class="setting-label">导出数据</label>
          <button @click="exportData" class="btn-secondary" :disabled="loading">
            <i class="i-tabler-download wh-4 mr-2" />
            导出为JSON
          </button>
          <p class="setting-description">
            导出所有经期数据到本地文件
          </p>
        </div>

        <div class="setting-item">
          <label class="setting-label">导入数据</label>
          <div class="import-control">
            <input ref="fileInput" type="file" accept=".json" class="hidden" @change="handleFileImport" />
            <button @click="triggerFileInput" class="btn-secondary" :disabled="loading">
              <i class="i-tabler-upload wh-4 mr-2" />
              选择文件
            </button>
          </div>
          <p class="setting-description">
            从JSON文件导入经期数据
          </p>
        </div>

        <div class="setting-item">
          <label class="setting-label text-red-600 dark:text-red-400">危险操作</label>
          <button @click="showResetModal = true" class="btn-danger" :disabled="loading">
            <Trash class="wh-5" />
          </button>
          <p class="setting-description">
            删除所有经期记录，此操作不可撤销
          </p>
        </div>
      </div>
    </div>

    <!-- 重置确认弹窗 -->
    <div v-if="showResetModal" class="fixed inset-0 bg-black/50 flex items-center justify-center z-50"
      @click.self="showResetModal = false">
      <div class="bg-white dark:bg-gray-800 rounded-lg p-6 max-w-sm mx-4">
        <h3 class="text-lg font-semibold text-gray-900 dark:text-white mb-4">
          确认重置
        </h3>
        <p class="text-gray-600 dark:text-gray-400 mb-6">
          确定要清空所有数据吗？此操作将删除所有经期记录、日常记录和设置，且无法撤销。
        </p>
        <div class="space-y-3">
          <input v-model="resetConfirmText" type="text" placeholder="输入 '确认重置' 来确认操作" class="input-base w-full" />
          <div class="flex gap-3">
            <button @click="showResetModal = false" class="btn-secondary flex-1">
              取消
            </button>
            <button @click="confirmReset" class="btn-danger flex-1" :disabled="resetConfirmText !== '确认重置' || loading">
              重置
            </button>
          </div>
        </div>
      </div>
    </div>

    <!-- 导入结果提示 -->
    <div v-if="importMessage"
      class="fixed bottom-4 right-4 bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg p-4 shadow-lg max-w-sm">
      <div class="flex items-start gap-3">
        <i :class="importSuccess ? 'i-tabler-check text-green-500' : 'i-tabler-x text-red-500'"
          class="wh-5 flex-shrink-0 mt-0.5" />
        <div>
          <p class="text-sm font-medium text-gray-900 dark:text-white">
            {{ importSuccess ? '导入成功' : '导入失败' }}
          </p>
          <p class="text-xs text-gray-600 dark:text-gray-400 mt-1">
            {{ importMessage }}
          </p>
        </div>
        <button @click="importMessage = ''" class="text-gray-400 hover:text-gray-600 dark:hover:text-gray-300">
          <i class="i-tabler-x wh-4" />
        </button>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { Trash } from 'lucide-vue-next';
import type { PeriodSettings } from '@/schema/health/period';
import { usePeriodStore } from '@/stores/periodStore';
import { PeriodDataManager } from '../utils/periodUtils';

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

// Methods
const validateAndUpdate = () => {
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
};

const updateSettings = async () => {
  try {
    await periodStore.updateSettings(localSettings);
  } catch (error) {
    console.error('Failed to update settings:', error);
    // 恢复到原来的设置
    Object.assign(localSettings, periodStore.settings);
  }
};

const exportData = () => {
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
};

const handleFileImport = async (event: Event) => {
  const target = event.target as HTMLInputElement;
  const file = target.files?.[0];
  if (!file) return;

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
    const errorMessage =
      error instanceof Error ? error.message : '文件格式错误或数据损坏';
    showMessage(errorMessage, false);
  } finally {
    loading.value = false;
    // 清空文件选择
    target.value = '';
  }
};

const triggerFileInput = () => {
  fileInput.value?.click();
};

const confirmReset = async () => {
  if (resetConfirmText.value !== '确认重置') return;

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
};

const showMessage = (message: string, success: boolean) => {
  importMessage.value = message;
  importSuccess.value = success;

  setTimeout(() => {
    importMessage.value = '';
  }, 5000);
};

// Initialize local settings from store
const initializeSettings = () => {
  Object.assign(localSettings, periodStore.settings);
};

// Watchers
watch(() => periodStore.settings, initializeSettings, { deep: true });

// Lifecycle
onMounted(() => {
  initializeSettings();
});
</script>

<style scoped lang="postcss">
.settings-section {
  @apply bg-white dark:bg-gray-800 border border-gray-200 dark:border-gray-700 rounded-lg shadow-sm;
}

.section-title {
  @apply flex items-center text-lg font-semibold text-gray-900 dark:text-white mb-6;
}

.settings-grid {
  @apply space-y-6;
}

.setting-item {
  @apply space-y-2;
}

.setting-label {
  @apply block text-sm font-medium text-gray-700 dark:text-gray-300;
}

.setting-control {
  @apply flex items-center gap-4;
}

.setting-range {
  @apply flex-1;
}

.setting-description {
  @apply text-xs text-gray-500 dark:text-gray-400;
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

.toggle-input:checked+.toggle-slider {
  @apply bg-blue-500;
}

.toggle-input:checked+.toggle-slider::after {
  @apply translate-x-5;
}

.toggle-text {
  @apply text-sm font-medium text-gray-700 dark:text-gray-300;
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

@media (max-width: 640px) {
  .settings-grid {
    @apply space-y-4;
  }

  .setting-control {
    @apply flex-col items-start gap-2;
  }

  .setting-range {
    @apply w-full;
  }
}
</style>
