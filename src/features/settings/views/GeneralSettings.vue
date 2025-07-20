<script setup lang="ts">
import { Monitor, Moon, RotateCcw, Save, Sun } from 'lucide-vue-next';
import { useLocaleStores } from '@/stores/locales';

const localeStore = useLocaleStores();

const selectedLocale = ref(localeStore.getCurrentLocale());
const selectedTimezone = ref('Asia/Shanghai');
const selectedTheme = ref('system');
const compactMode = ref(false);
const autoStart = ref(false);
const minimizeToTray = ref(true);

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

function handleReset() {
  selectedLocale.value = 'zh-CN';
  selectedTimezone.value = 'Asia/Shanghai';
  selectedTheme.value = 'system';
  compactMode.value = false;
  autoStart.value = false;
  minimizeToTray.value = true;
}

onMounted(() => {
  selectedLocale.value = localeStore.getCurrentLocale();
});
</script>

<template>
  <div class="max-w-4xl">
    <!-- 语言和地区 -->
    <div class="mb-10">
      <h3 class="mb-6 border-b-2 border-slate-200 pb-2 text-xl text-slate-800 font-semibold">
        语言和地区
      </h3>

      <div class="space-y-6">
        <div class="flex flex-col border-b border-slate-100 py-6 sm:flex-row sm:items-center sm:justify-between">
          <div class="mb-4 sm:mb-0">
            <label class="mb-1 block text-slate-700 font-medium">界面语言</label>
            <p class="text-sm text-slate-500">
              选择您偏好的界面语言
            </p>
          </div>
          <div class="sm:ml-8">
            <select
              v-model="selectedLocale"
              class="w-full border border-slate-300 rounded-lg bg-white px-4 py-2 transition-all duration-200 sm:w-48 focus:border-blue-500 focus:ring-2 focus:ring-blue-500"
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

        <div class="flex flex-col border-b border-slate-100 py-6 sm:flex-row sm:items-center sm:justify-between">
          <div class="mb-4 sm:mb-0">
            <label class="mb-1 block text-slate-700 font-medium">时区</label>
            <p class="text-sm text-slate-500">
              设置您所在的时区
            </p>
          </div>
          <div class="sm:ml-8">
            <select
              v-model="selectedTimezone"
              class="w-full border border-slate-300 rounded-lg bg-white px-4 py-2 transition-all duration-200 sm:w-48 focus:border-blue-500 focus:ring-2 focus:ring-blue-500"
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
    <div class="mb-10">
      <h3 class="mb-6 border-b-2 border-slate-200 pb-2 text-xl text-slate-800 font-semibold">
        显示设置
      </h3>

      <div class="space-y-6">
        <div class="flex flex-col border-b border-slate-100 py-6 sm:flex-row sm:items-center sm:justify-between">
          <div class="mb-4 sm:mb-0">
            <label class="mb-1 block text-slate-700 font-medium">主题模式</label>
            <p class="text-sm text-slate-500">
              选择浅色或深色主题
            </p>
          </div>
          <div class="sm:ml-8">
            <div class="flex gap-2">
              <button
                v-for="theme in themes"
                :key="theme.value"
                class="flex items-center gap-2 border rounded-lg px-4 py-2 text-sm font-medium transition-all duration-200" :class="[
                  selectedTheme === theme.value
                    ? 'border-blue-500 bg-blue-500 text-white'
                    : 'border-slate-300 bg-white text-slate-700 hover:border-blue-300 hover:bg-slate-50',
                ]"
                @click="selectedTheme = theme.value"
              >
                <component :is="theme.icon" class="h-4 w-4" />
                {{ theme.label }}
              </button>
            </div>
          </div>
        </div>

        <div class="flex flex-col border-b border-slate-100 py-6 sm:flex-row sm:items-center sm:justify-between">
          <div class="mb-4 sm:mb-0">
            <label class="mb-1 block text-slate-700 font-medium">紧凑模式</label>
            <p class="text-sm text-slate-500">
              使用更紧凑的界面布局
            </p>
          </div>
          <div class="sm:ml-8">
            <label class="relative inline-flex cursor-pointer items-center">
              <input
                v-model="compactMode"
                type="checkbox"
                class="peer sr-only"
              >
              <div class="peer relative h-6 w-12 rounded-full bg-slate-300 after:absolute after:left-0.5 after:top-0.5 after:h-5 after:w-5 after:rounded-full after:bg-white peer-checked:bg-blue-500 peer-focus:ring-2 peer-focus:ring-blue-500 after:transition-all after:content-[''] peer-checked:after:translate-x-6 peer-checked:after:border-white" />
            </label>
          </div>
        </div>
      </div>
    </div>

    <!-- 系统设置 -->
    <div class="mb-10">
      <h3 class="mb-6 border-b-2 border-slate-200 pb-2 text-xl text-slate-800 font-semibold">
        系统设置
      </h3>

      <div class="space-y-6">
        <div class="flex flex-col border-b border-slate-100 py-6 sm:flex-row sm:items-center sm:justify-between">
          <div class="mb-4 sm:mb-0">
            <label class="mb-1 block text-slate-700 font-medium">开机自启动</label>
            <p class="text-sm text-slate-500">
              系统启动时自动运行应用
            </p>
          </div>
          <div class="sm:ml-8">
            <label class="relative inline-flex cursor-pointer items-center">
              <input
                v-model="autoStart"
                type="checkbox"
                class="peer sr-only"
              >
              <div class="peer relative h-6 w-12 rounded-full bg-slate-300 after:absolute after:left-0.5 after:top-0.5 after:h-5 after:w-5 after:rounded-full after:bg-white peer-checked:bg-blue-500 peer-focus:ring-2 peer-focus:ring-blue-500 after:transition-all after:content-[''] peer-checked:after:translate-x-6 peer-checked:after:border-white" />
            </label>
          </div>
        </div>

        <div class="flex flex-col py-6 sm:flex-row sm:items-center sm:justify-between">
          <div class="mb-4 sm:mb-0">
            <label class="mb-1 block text-slate-700 font-medium">最小化到系统托盘</label>
            <p class="text-sm text-slate-500">
              关闭窗口时最小化到系统托盘
            </p>
          </div>
          <div class="sm:ml-8">
            <label class="relative inline-flex cursor-pointer items-center">
              <input
                v-model="minimizeToTray"
                type="checkbox"
                class="peer sr-only"
              >
              <div class="peer relative h-6 w-12 rounded-full bg-slate-300 after:absolute after:left-0.5 after:top-0.5 after:h-5 after:w-5 after:rounded-full after:bg-white peer-checked:bg-blue-500 peer-focus:ring-2 peer-focus:ring-blue-500 after:transition-all after:content-[''] peer-checked:after:translate-x-6 peer-checked:after:border-white" />
            </label>
          </div>
        </div>
      </div>
    </div>

    <!-- 操作按钮 -->
    <div class="flex flex-col gap-4 border-t border-slate-200 pt-8 sm:flex-row">
      <button
        class="flex items-center justify-center gap-2 rounded-lg bg-blue-500 px-6 py-3 text-white font-medium transition-all duration-200 hover:bg-blue-600"
        @click="handleSave"
      >
        <Save class="h-4 w-4" />
        保存设置
      </button>
      <button
        class="flex items-center justify-center gap-2 border border-slate-300 rounded-lg bg-slate-100 px-6 py-3 text-slate-700 font-medium transition-all duration-200 hover:bg-slate-200"
        @click="handleReset"
      >
        <RotateCcw class="h-4 w-4" />
        重置为默认
      </button>
    </div>
  </div>
</template>
