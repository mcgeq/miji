<script setup lang="ts">
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
const minimizeToTray = ref(true);

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

function handleSave() {
  const settings = {
    locale: selectedLocale.value,
    timezone: selectedTimezone.value,
    theme: selectedTheme.value,
    compactMode: compactMode.value,
    autoStart: autoStart.value,
    minimizeToTray: minimizeToTray.value,
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
  minimizeToTray.value = true;

  // 重置store中的值
  await localeStore.setLocale('zh-CN');
  await themeStore.setTheme('system');
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
