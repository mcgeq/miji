<script setup lang="ts">
import { invoke } from '@tauri-apps/api/core';
import { Monitor, Moon, RotateCcw, Save, Sun } from 'lucide-vue-next';
import { useLocaleStore } from '@/stores/locales';
import { useThemeStore } from '@/stores/theme';

const localeStore = useLocaleStore();
const themeStore = useThemeStore();

// 使用响应式引用，初始值从 store 获取
const selectedLocale = ref(localeStore.currentLocale || 'zh-CN');
const selectedTimezone = ref('Asia/Shanghai');
const selectedTheme = ref(themeStore.currentTheme || 'system');
const compactMode = ref(false);
const autoStart = ref(false);
const minimizeToTray = ref(false); // 默认关闭最小化到托盘
const closeBehaviorPreference = ref('ask'); // 默认每次询问
const isLoadingSettings = ref(false); // 标志是否正在加载设置

// 关闭行为选项
const closeBehaviorOptions = computed(() => {
  const options = [
    { value: 'ask', label: '每次询问' },
    { value: 'close', label: '直接关闭' },
  ];

  // 如果启用了最小化到托盘，添加最小化选项
  if (minimizeToTray.value) {
    options.splice(1, 0, { value: 'minimize', label: '最小化到托盘' });
  }

  return options;
});

// 监听 store 的变化，同步到 selectedLocale
watch(() => localeStore.currentLocale, newLocale => {
  if (newLocale && newLocale !== selectedLocale.value) {
    selectedLocale.value = newLocale;
  }
}, { immediate: true });

// 监听主题store的变化，同步到 selectedTheme
watch(() => themeStore.currentTheme, newTheme => {
  if (newTheme && newTheme !== selectedTheme.value) {
    selectedTheme.value = newTheme;
  }
}, { immediate: true });

// 监听最小化到托盘开关的变化
watch(minimizeToTray, async newValue => {
  if (isLoadingSettings.value) return; // 加载设置时不触发保存

  if (newValue) {
    // 如果开启了最小化到托盘，则关闭行为偏好应选择最小化到托盘
    closeBehaviorPreference.value = 'minimize';
  } else {
    // 如果关闭了最小化到托盘，则关闭行为偏好应选择每次询问
    closeBehaviorPreference.value = 'ask';
  }
  await handleCloseBehaviorChange(); // 保存新的偏好设置
});

// 监听关闭行为偏好的变化
watch(closeBehaviorPreference, async newValue => {
  if (isLoadingSettings.value) return; // 加载设置时不触发保存

  if (newValue === 'minimize') {
    // 如果选择最小化到托盘，则开启最小化到托盘开关
    minimizeToTray.value = true;
  } else if (newValue === 'ask' || newValue === 'close') {
    // 如果选择每次询问或直接关闭，则关闭最小化到托盘开关
    minimizeToTray.value = false;
  }
  await handleCloseBehaviorChange(); // 保存新的偏好设置
});

// 组件挂载时加载关闭行为偏好
onMounted(async () => {
  isLoadingSettings.value = true; // 开始加载设置

  try {
    const preference = await invoke('get_close_behavior_preference');
    if (preference) {
      closeBehaviorPreference.value = preference;
      // 根据偏好设置同步最小化开关
      if (preference === 'minimize') {
        minimizeToTray.value = true;
      } else {
        minimizeToTray.value = false;
      }
    }
  } catch (error) {
    console.error('Failed to load close behavior preference:', error);
  } finally {
    isLoadingSettings.value = false; // 结束加载设置
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

const themes = [
  { value: 'light', label: '浅色', icon: Sun },
  { value: 'dark', label: '深色', icon: Moon },
  { value: 'system', label: '跟随系统', icon: Monitor },
];

async function handleLocaleChange() {
  await localeStore.setLocale(selectedLocale.value);
}

async function handleThemeChange(theme: string) {
  selectedTheme.value = theme;
  await themeStore.setTheme(theme as any);
}

async function handleCloseBehaviorChange() {
  try {
    await invoke('set_close_behavior_preference', { preference: closeBehaviorPreference.value });
  } catch (error) {
    console.error('Failed to save close behavior preference:', error);
  }
}

function handleSave() {
  const settings = {
    locale: selectedLocale.value,
    timezone: selectedTimezone.value,
    theme: selectedTheme.value,
    compactMode: compactMode.value,
    autoStart: autoStart.value,
    minimizeToTray: minimizeToTray.value,
    closeBehaviorPreference: closeBehaviorPreference.value,
  };

  // 在开发环境下显示设置信息
  if (import.meta.env?.DEV) {
    console.warn('保存设置', settings);
  }

  // TODO: 实现实际的保存逻辑
  // await saveUserSettings(settings)
}

async function handleReset() {
  selectedLocale.value = 'zh-CN';
  selectedTimezone.value = 'Asia/Shanghai';
  selectedTheme.value = 'system';
  compactMode.value = false;
  autoStart.value = false;
  minimizeToTray.value = false; // 重置为关闭状态
  closeBehaviorPreference.value = 'ask'; // 重置为每次询问

  // 重置store中的值
  await localeStore.setLocale('zh-CN');
  await themeStore.setTheme('system');

  // 重置关闭行为偏好
  try {
    await invoke('set_close_behavior_preference', { preference: 'ask' });
  } catch (error) {
    console.error('Failed to reset close behavior preference:', error);
  }
}
</script>

<template>
  <div class="general-settings-container">
    <!-- 语言和地区 -->
    <div class="general-settings-section">
      <h3 class="general-settings-title">
        语言和地区
      </h3>

      <div class="general-settings-items">
        <div class="general-setting-item">
          <div class="general-setting-label-wrapper">
            <label class="general-setting-label">界面语言</label>
            <p class="general-setting-description">
              选择您偏好的界面语言
            </p>
          </div>
          <div class="general-setting-control">
            <select
              v-model="selectedLocale"
              class="general-select"
              @change="handleLocaleChange"
            >
              <option
                v-for="locale in availableLocales"
                :key="locale.code"
                :value="locale.code"
              >
                {{ locale.name }}
              </option>
            </select>
          </div>
        </div>

        <div class="general-setting-item">
          <div class="general-setting-label-wrapper">
            <label class="general-setting-label">时区</label>
            <p class="general-setting-description">
              设置您所在的时区
            </p>
          </div>
          <div class="general-setting-control">
            <select
              v-model="selectedTimezone"
              class="general-select"
            >
              <option
                v-for="timezone in availableTimezones"
                :key="timezone.value"
                :value="timezone.value"
              >
                {{ timezone.label }}
              </option>
            </select>
          </div>
        </div>
      </div>
    </div>

    <!-- 显示设置 -->
    <div class="general-settings-section">
      <h3 class="general-settings-title">
        显示设置
      </h3>

      <div class="general-settings-items">
        <div class="general-setting-item">
          <div class="general-setting-label-wrapper">
            <label class="general-setting-label">主题模式</label>
            <p class="general-setting-description">
              选择浅色或深色主题
            </p>
          </div>
          <div class="general-setting-control">
            <div class="theme-buttons">
              <button
                v-for="theme in themes"
                :key="theme.value"
                class="theme-button"
                :class="selectedTheme === theme.value ? 'theme-button-active' : 'theme-button-inactive'"
                @click="handleThemeChange(theme.value)"
              >
                <component :is="theme.icon" class="theme-button-icon" />
                {{ theme.label }}
              </button>
            </div>
          </div>
        </div>

        <div class="general-setting-item">
          <div class="general-setting-label-wrapper">
            <label class="general-setting-label">紧凑模式</label>
            <p class="general-setting-description">
              使用更紧凑的界面布局
            </p>
          </div>
          <div class="general-setting-control">
            <label class="toggle-switch">
              <input
                v-model="compactMode"
                type="checkbox"
                class="toggle-switch-input"
              >
              <div class="toggle-switch-track">
                <div class="toggle-switch-thumb" />
              </div>
            </label>
          </div>
        </div>
      </div>
    </div>

    <!-- 系统设置 -->
    <div class="general-settings-section">
      <h3 class="general-settings-title">
        系统设置
      </h3>

      <div class="general-settings-items">
        <div class="general-setting-item">
          <div class="general-setting-label-wrapper">
            <label class="general-setting-label">开机自启动</label>
            <p class="general-setting-description">
              系统启动时自动运行应用
            </p>
          </div>
          <div class="general-setting-control">
            <label class="toggle-switch">
              <input
                v-model="autoStart"
                type="checkbox"
                class="toggle-switch-input"
              >
              <div class="toggle-switch-track">
                <div class="toggle-switch-thumb" />
              </div>
            </label>
          </div>
        </div>

        <div class="general-setting-item">
          <div class="general-setting-label-wrapper">
            <label class="general-setting-label">最小化到系统托盘</label>
            <p class="general-setting-description">
              关闭窗口时最小化到系统托盘
            </p>
          </div>
          <div class="general-setting-control">
            <label class="toggle-switch">
              <input
                v-model="minimizeToTray"
                type="checkbox"
                class="toggle-switch-input"
              >
              <div class="toggle-switch-track">
                <div class="toggle-switch-thumb" />
              </div>
            </label>
          </div>
        </div>

        <div class="general-setting-item">
          <div class="general-setting-label-wrapper">
            <label class="general-setting-label">关闭行为偏好</label>
            <p class="general-setting-description">
              设置点击关闭按钮时的默认行为
            </p>
          </div>
          <div class="general-setting-control">
            <select
              v-model="closeBehaviorPreference"
              class="general-select"
              @change="handleCloseBehaviorChange"
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
      </div>
    </div>

    <!-- 操作按钮 -->
    <div class="setting-action-buttons">
      <button
        class="action-button-primary"
        @click="handleSave"
      >
        <Save class="action-button-primary-icon" />
        保存设置
      </button>
      <button
        class="action-button-secondary"
        @click="handleReset"
      >
        <RotateCcw class="action-button-secondary-icon" />
        重置为默认
      </button>
    </div>
  </div>
</template>
