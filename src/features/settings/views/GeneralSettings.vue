<script setup lang="ts">
import { invoke } from '@tauri-apps/api/core';
import { Monitor, Moon, RotateCcw, Sun } from 'lucide-vue-next';
import { useI18n } from 'vue-i18n';
import { useAutoSaveSettings, createDatabaseSetting } from '@/composables/useAutoSaveSettings';
import { useLocaleStore } from '@/stores/locales';
import { useThemeStore } from '@/stores/theme';
import { isDesktop } from '@/utils/platform';
import ToggleSwitch from '@/components/ToggleSwitch.vue';

const { t } = useI18n();

const localeStore = useLocaleStore();
const themeStore = useThemeStore();

// 平台检测
const isDesktopPlatform = ref(isDesktop());

// 使用自动保存设置系统
const { fields, isSaving, resetAll, loadAll } = useAutoSaveSettings({
  moduleName: 'general',
  fields: {
    locale: {
      key: 'settings.general.locale',
      defaultValue: 'zh-CN',
      saveFn: async (val) => {
        await localeStore.setLocale(val);
      },
      loadFn: async () => {
        return localeStore.currentLocale || 'zh-CN';
      },
    },
    timezone: createDatabaseSetting({
      key: 'settings.general.timezone',
      defaultValue: 'Asia/Shanghai',
    }),
    theme: {
      key: 'settings.general.theme',
      defaultValue: 'system',
      saveFn: async (val) => {
        await themeStore.setTheme(val as 'light' | 'dark' | 'system');
      },
      loadFn: async () => {
        return themeStore.currentTheme || 'system';
      },
    },
    compactMode: createDatabaseSetting({
      key: 'settings.general.compactMode',
      defaultValue: false,
    }),
    autoStart: createDatabaseSetting({
      key: 'settings.general.autoStart',
      defaultValue: false,
    }),
    minimizeToTray: createDatabaseSetting({
      key: 'settings.general.minimizeToTray',
      defaultValue: false,
    }),
    closeBehaviorPreference: createDatabaseSetting({
      key: 'settings.general.closeBehaviorPreference',
      defaultValue: 'ask',
    }),
  },
});

// 保留原有的关闭行为选项逻辑
const isLoadingSettings = ref(false);

// 关闭行为选项
const closeBehaviorOptions = computed(() => {
  const options = [
    { value: 'ask', label: t('settings.general.closeBehaviorOptions.ask') },
    { value: 'close', label: t('settings.general.closeBehaviorOptions.close') },
  ];

  // 如果启用了最小化到托盘，添加最小化选项
  if (fields.minimizeToTray.value.value) {
    options.splice(1, 0, { value: 'minimize', label: t('settings.general.closeBehaviorOptions.minimize') });
  }

  return options;
});

// 监听 store 的变化，同步到设置
watch(() => localeStore.currentLocale, newLocale => {
  if (newLocale && newLocale !== fields.locale.value.value) {
    fields.locale.value.value = newLocale;
  }
}, { immediate: true });

// 监听主题store的变化，同步到设置
watch(() => themeStore.currentTheme, newTheme => {
  if (newTheme && newTheme !== fields.theme.value.value) {
    fields.theme.value.value = newTheme;
  }
}, { immediate: true });

// 监听最小化到托盘开关的变化
watch(() => fields.minimizeToTray.value.value, async newValue => {
  if (isLoadingSettings.value) return; // 加载设置时不触发保存

  if (newValue) {
    fields.closeBehaviorPreference.value.value = 'minimize';
  } else {
    fields.closeBehaviorPreference.value.value = 'ask';
  }
  await handleCloseBehaviorChange();
});

// 监听关闭行为偏好的变化
watch(() => fields.closeBehaviorPreference.value.value, async newValue => {
  if (isLoadingSettings.value) return; // 加载设置时不触发保存

  if (newValue === 'minimize') {
    fields.minimizeToTray.value.value = true;
  } else if (newValue === 'ask' || newValue === 'close') {
    fields.minimizeToTray.value.value = false;
  }
  await handleCloseBehaviorChange();
});

// 事件处理器引用，用于清理
let handlePreferenceChange: ((event: CustomEvent) => void) | null = null;

// 组件挂载时加载所有设置
onMounted(async () => {
  isLoadingSettings.value = true;

  // 加载所有自动保存的设置
  await loadAll();
  
  // 确保时区有默认值（防止显示空白）
  if (!fields.timezone.value.value) {
    console.log('[GeneralSettings] Timezone is empty, setting default value');
    fields.timezone.value.value = 'Asia/Shanghai';
  }
  
  console.log('[GeneralSettings] Settings loaded:', {
    locale: fields.locale.value.value,
    timezone: fields.timezone.value.value,
    theme: fields.theme.value.value,
  });

  // 加载关闭行为偏好（Tauri 特定）
  try {
    const preference = await invoke('get_close_behavior_preference') as string | null;
    if (preference) {
      fields.closeBehaviorPreference.value.value = preference;
      if (preference === 'minimize') {
        fields.minimizeToTray.value.value = true;
      } else {
        fields.minimizeToTray.value.value = false;
      }
    }
  } catch (error) {
    console.error('Failed to load close behavior preference:', error);
  } finally {
    isLoadingSettings.value = false;
  }

  // 监听关闭偏好变化事件
  handlePreferenceChange = (event: CustomEvent) => {
    const { preference } = event.detail;
    isLoadingSettings.value = true;

    fields.closeBehaviorPreference.value.value = preference;
    if (preference === 'minimize') {
      fields.minimizeToTray.value.value = true;
    } else {
      fields.minimizeToTray.value.value = false;
    }

    isLoadingSettings.value = false;
  };

  window.addEventListener('close-preference-changed', handlePreferenceChange as EventListener);
});

// 组件卸载时移除事件监听器
onUnmounted(() => {
  if (handlePreferenceChange) {
    window.removeEventListener('close-preference-changed', handlePreferenceChange as EventListener);
  }
});

const availableLocales = [
  { code: 'zh-CN', name: '简体中文' },
  { code: 'zh-TW', name: '繁體中文' },
  { code: 'en-US', name: 'English' },
  { code: 'ja-JP', name: '日本語' },
  { code: 'ko-KR', name: '한국어' },
];

const availableTimezones = [
  { value: 'Asia/Shanghai', label: '中国标准时间 (UTC+8)' },
  { value: 'Asia/Tokyo', label: '日本标准时间 (UTC+9)' },
  { value: 'Asia/Seoul', label: '韩国标准时间 (UTC+9)' },
  { value: 'America/New_York', label: '美国东部时间 (UTC-5)' },
  { value: 'America/Los_Angeles', label: '美国西部时间 (UTC-8)' },
  { value: 'Europe/London', label: '格林威治标准时间 (UTC+0)' },
  { value: 'Europe/Berlin', label: '中欧时间 (UTC+1)' },
];

const themes = computed(() => [
  { value: 'light', label: t('settings.general.themes.light'), icon: Sun },
  { value: 'dark', label: t('settings.general.themes.dark'), icon: Moon },
  { value: 'system', label: t('settings.general.themes.system'), icon: Monitor },
]);

async function handleCloseBehaviorChange() {
  try {
    await invoke('set_close_behavior_preference', { preference: fields.closeBehaviorPreference.value.value });
  } catch (error) {
    console.error('Failed to save close behavior preference:', error);
  }
}

// 重置函数使用 resetAll
async function handleReset() {
  // 使用自动保存系统的重置功能
  await resetAll();

  // 重置 Tauri 特定的关闭行为偏好
  try {
    await invoke('set_close_behavior_preference', { preference: 'ask' });
  } catch (error) {
    console.error('Failed to reset close behavior preference:', error);
  }
}
</script>

<template>
  <div class="max-w-4xl w-full">
    <!-- 语言和地区 -->
    <div class="mb-10">
      <h3 class="text-xl font-semibold text-gray-900 dark:text-white mb-6 pb-2 border-b-2 border-gray-200 dark:border-gray-700">
        {{ $t('settings.general.language') }}
      </h3>

      <div class="space-y-6">
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between py-6 border-b border-gray-200 dark:border-gray-700">
          <div class="mb-4 sm:mb-0">
            <label class="block font-medium text-gray-900 dark:text-white mb-1">{{ $t('settings.general.language') }}</label>
            <p class="text-sm text-gray-600 dark:text-gray-400">
              {{ $t('settings.general.languageDesc') }}
            </p>
          </div>
          <div class="sm:ml-8 flex items-center gap-2">
            <select
              v-model="fields.locale.value.value"
              class="w-full sm:w-48 px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-white transition-all focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20 focus:outline-none"
            >
              <option
                v-for="locale in availableLocales"
                :key="locale.code"
                :value="locale.code"
              >
                {{ locale.name }}
              </option>
            </select>
            <span v-if="fields.locale.isSaving.value" class="text-xs text-gray-500 whitespace-nowrap">
              {{ $t('settings.general.saving') }}
            </span>
          </div>
        </div>

        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between py-6 border-b border-gray-200 dark:border-gray-700">
          <div class="mb-4 sm:mb-0">
            <label class="block font-medium text-gray-900 dark:text-white mb-1">{{ $t('settings.general.timezone') }}</label>
            <p class="text-sm text-gray-600 dark:text-gray-400">
              {{ $t('settings.general.timezoneDesc') }}
            </p>
          </div>
          <div class="sm:ml-8 flex items-center gap-2">
            <select
              v-model="fields.timezone.value.value"
              class="w-full sm:w-48 px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-white transition-all focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20 focus:outline-none"
            >
              <option
                v-for="timezone in availableTimezones"
                :key="timezone.value"
                :value="timezone.value"
              >
                {{ timezone.label }}
              </option>
            </select>
            <span v-if="fields.timezone.isSaving.value" class="text-xs text-gray-500 whitespace-nowrap">
              {{ $t('settings.general.saving') }}
            </span>
          </div>
        </div>
      </div>
    </div>

    <!-- 显示设置 -->
    <div class="mb-10">
      <h3 class="text-xl font-semibold text-gray-900 dark:text-white mb-6 pb-2 border-b-2 border-gray-200 dark:border-gray-700">
        {{ $t('settings.general.theme') }}
      </h3>

      <div class="space-y-6">
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between py-6 border-b border-gray-200 dark:border-gray-700">
          <div class="mb-4 sm:mb-0">
            <label class="block font-medium text-gray-900 dark:text-white mb-1">{{ $t('settings.general.theme') }}</label>
            <p class="text-sm text-gray-600 dark:text-gray-400">
              {{ $t('settings.general.themeDesc') }}
            </p>
          </div>
          <div class="sm:ml-8">
            <div class="flex gap-2">
              <button
                v-for="themeOption in themes"
                :key="themeOption.value"
                class="text-sm font-medium px-4 py-2 border rounded-lg flex items-center gap-2 transition-all"
                :class="fields.theme.value.value === themeOption.value
                  ? 'border-blue-600 bg-blue-600 text-white'
                  : 'border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-900 dark:text-white hover:border-blue-600 hover:bg-gray-50 dark:hover:bg-gray-700'"
                @click="fields.theme.value.value = themeOption.value"
              >
                <component :is="themeOption.icon" class="w-4 h-4" />
                {{ themeOption.label }}
              </button>
            </div>
            <span v-if="fields.theme.isSaving.value" class="text-xs text-gray-500 ml-2">
              {{ $t('settings.general.saving') }}
            </span>
          </div>
        </div>

        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between py-6 border-b border-gray-200 dark:border-gray-700">
          <div class="mb-4 sm:mb-0">
            <label class="block font-medium text-gray-900 dark:text-white mb-1">{{ $t('settings.general.compactMode') }}</label>
            <p class="text-sm text-gray-600 dark:text-gray-400">
              {{ $t('settings.general.compactModeDesc') }}
            </p>
          </div>
          <div class="sm:ml-8">
            <ToggleSwitch v-model="fields.compactMode.value.value" />
          </div>
        </div>
      </div>
    </div>

    <!-- 系统设置 -->
    <div class="mb-10">
      <h3 class="text-xl font-semibold text-gray-900 dark:text-white mb-6 pb-2 border-b-2 border-gray-200 dark:border-gray-700">
        {{ $t('settings.general.title') }}
      </h3>

      <div class="space-y-6">
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between py-6 border-b border-gray-200 dark:border-gray-700">
          <div class="mb-4 sm:mb-0">
            <label class="block font-medium text-gray-900 dark:text-white mb-1">{{ $t('settings.general.autoStart') }}</label>
            <p class="text-sm text-gray-600 dark:text-gray-400">
              {{ $t('settings.general.autoStartDesc') }}
            </p>
          </div>
          <div class="sm:ml-8">
            <ToggleSwitch v-model="fields.autoStart.value.value" />
          </div>
        </div>

        <!-- 只在桌面端显示托盘相关设置 -->
        <template v-if="isDesktopPlatform">
          <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between py-6 border-b border-gray-200 dark:border-gray-700">
            <div class="mb-4 sm:mb-0">
              <label class="block font-medium text-gray-900 dark:text-white mb-1">{{ $t('settings.general.minimizeToTray') }}</label>
              <p class="text-sm text-gray-600 dark:text-gray-400">
                {{ $t('settings.general.minimizeToTrayDesc') }}
              </p>
            </div>
            <div class="sm:ml-8">
              <ToggleSwitch v-model="fields.minimizeToTray.value.value" />
            </div>
          </div>

          <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between py-6 border-b border-gray-200 dark:border-gray-700">
            <div class="mb-4 sm:mb-0">
              <label class="block font-medium text-gray-900 dark:text-white mb-1">{{ $t('settings.general.closeBehavior') }}</label>
              <p class="text-sm text-gray-600 dark:text-gray-400">
                {{ $t('settings.general.closeBehaviorDesc') }}
              </p>
            </div>
            <div class="sm:ml-8">
              <select
                v-model="fields.closeBehaviorPreference.value.value"
                class="w-full sm:w-48 px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-white transition-all focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20 focus:outline-none"
              >
                <option
                  v-for="option in closeBehaviorOptions"
                  :key="option.value"
                  :value="option.value"
                >
                  {{ option.label }}
                </option>
              </select>
            </div>
          </div>
        </template>
      </div>
    </div>

    <!-- 操作按钮 -->
    <div class="pt-8 border-t border-gray-200 dark:border-gray-700 flex justify-center gap-4">
      <button
        :disabled="isSaving"
        :title="$t('settings.general.resetSettings')"
        class="flex items-center justify-center w-12 h-12 rounded-full border border-gray-300 dark:border-gray-600 hover:bg-gray-50 dark:hover:bg-gray-700 text-gray-900 dark:text-white transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
        @click="handleReset"
      >
        <RotateCcw class="w-5 h-5" />
      </button>
      
      <!-- 全局保存状态提示 -->
      <div v-if="isSaving" class="flex items-center justify-center w-12 h-12 text-gray-600 dark:text-gray-400">
        <span class="animate-spin text-xl">⏳</span>
      </div>
    </div>
  </div>
</template>
