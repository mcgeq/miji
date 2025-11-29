<script setup lang="ts">
import {
  AlertTriangle,
  Bell,
  Mail,
  MessageSquare,
  Monitor,
  Save,
  Smartphone,
  Users,
  Volume2,
} from 'lucide-vue-next';
import { ref } from 'vue';
import { Lg } from '@/utils/debugLog';
import { toast } from '@/utils/toast';

// 通知总开关
const notificationsEnabled = ref(true);

// 通知类型
const notificationTypes = ref([
  {
    id: 'messages',
    name: '消息通知',
    description: '新消息和聊天通知',
    icon: MessageSquare,
    enabled: true,
    methods: ['desktop', 'mobile'],
  },
  {
    id: 'emails',
    name: '邮件通知',
    description: '新邮件提醒',
    icon: Mail,
    enabled: true,
    methods: ['desktop', 'email'],
  },
  {
    id: 'alerts',
    name: '系统警报',
    description: '重要系统消息和警告',
    icon: AlertTriangle,
    enabled: true,
    methods: ['desktop', 'mobile', 'email'],
  },
  {
    id: 'social',
    name: '社交通知',
    description: '好友请求、提及等社交活动',
    icon: Users,
    enabled: false,
    methods: ['desktop'],
  },
]);

// 通知方式
const notificationMethods = [
  { id: 'desktop', name: '桌面通知', icon: Monitor },
  { id: 'mobile', name: '移动推送', icon: Smartphone },
  { id: 'email', name: '邮件', icon: Mail },
];

// 免打扰模式
const doNotDisturbEnabled = ref(false);
const dndSchedule = ref({
  start: '22:00',
  end: '08:00',
  days: ['1', '2', '3', '4', '5'],
});

const weekDays = [
  { id: '1', name: '周一' },
  { id: '2', name: '周二' },
  { id: '3', name: '周三' },
  { id: '4', name: '周四' },
  { id: '5', name: '周五' },
  { id: '6', name: '周六' },
  { id: '0', name: '周日' },
];

// 通知声音
const selectedSound = ref('default');
const notificationSounds = [
  { id: 'default', name: '默认' },
  { id: 'gentle', name: '轻柔' },
  { id: 'alert', name: '警报' },
  { id: 'chime', name: '钟声' },
  { id: 'none', name: '静音' },
];

// 通知持续时间
const notificationDuration = ref(5);

// 邮件设置
const emailSummaryFrequency = ref('weekly');
const marketingEmails = ref(false);

// 播放声音
function playSound() {
  toast.info(`播放声音: ${selectedSound.value}`);
}

// 保存设置
function handleSave() {
  const settings = {
    notificationsEnabled: notificationsEnabled.value,
    notificationTypes: notificationTypes.value,
    doNotDisturbEnabled: doNotDisturbEnabled.value,
    dndSchedule: dndSchedule.value,
    selectedSound: selectedSound.value,
    notificationDuration: notificationDuration.value,
    emailSummaryFrequency: emailSummaryFrequency.value,
    marketingEmails: marketingEmails.value,
  };

  Lg.i('Settings Notification', '保存通知设置:', settings);
}
</script>

<template>
  <div class="max-w-4xl w-full">
    <!-- 通知偏好 -->
    <div class="mb-10">
      <h3 class="text-xl font-semibold text-gray-900 dark:text-white mb-6 pb-2 border-b-2 border-gray-200 dark:border-gray-700">
        通知偏好
      </h3>

      <div class="space-y-6">
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between py-6 border-b border-gray-200 dark:border-gray-700">
          <div class="mb-4 sm:mb-0">
            <label class="block font-medium text-gray-900 dark:text-white mb-1">启用通知</label>
            <p class="text-sm text-gray-600 dark:text-gray-400">
              接收应用和系统通知
            </p>
          </div>
          <div class="sm:ml-8">
            <label class="inline-flex cursor-pointer items-center relative">
              <input
                v-model="notificationsEnabled"
                type="checkbox"
                class="sr-only peer"
              >
              <div class="w-12 h-6 bg-gray-300 dark:bg-gray-600 rounded-full peer peer-checked:bg-blue-600 transition-colors relative">
                <div class="absolute w-5 h-5 bg-white rounded-full top-0.5 left-0.5 peer-checked:translate-x-6 transition-transform" />
              </div>
            </label>
          </div>
        </div>

        <div v-if="notificationsEnabled" class="space-y-4">
          <div
            v-for="type in notificationTypes"
            :key="type.id"
            class="p-6 border border-gray-200 dark:border-gray-700 rounded-lg bg-white dark:bg-gray-800"
          >
            <div class="flex items-center justify-between mb-4">
              <div class="flex items-center gap-4">
                <component :is="type.icon" class="w-5 h-5 text-blue-600 dark:text-blue-400" />
                <div>
                  <h4 class="font-medium text-gray-900 dark:text-white">
                    {{ type.name }}
                  </h4>
                  <p class="text-sm text-gray-600 dark:text-gray-400">
                    {{ type.description }}
                  </p>
                </div>
              </div>
              <label class="inline-flex cursor-pointer items-center relative">
                <input
                  v-model="type.enabled"
                  type="checkbox"
                  class="sr-only peer"
                >
                <div class="w-12 h-6 bg-gray-300 dark:bg-gray-600 rounded-full peer peer-checked:bg-blue-600 transition-colors relative">
                  <div class="absolute w-5 h-5 bg-white rounded-full top-0.5 left-0.5 peer-checked:translate-x-6 transition-transform" />
                </div>
              </label>
            </div>

            <div v-if="type.enabled" class="pt-4 border-t border-gray-200 dark:border-gray-700">
              <div class="flex flex-col sm:flex-row sm:items-center gap-4">
                <span class="text-sm font-medium text-gray-700 dark:text-gray-300 whitespace-nowrap">通知方式:</span>
                <div class="flex flex-wrap gap-2">
                  <label
                    v-for="method in notificationMethods"
                    :key="method.id"
                    class="flex items-center gap-2 cursor-pointer"
                  >
                    <input
                      v-model="type.methods"
                      :value="method.id"
                      type="checkbox"
                      class="w-4 h-4 text-blue-600 bg-white dark:bg-gray-800 border-gray-300 dark:border-gray-600 rounded focus:ring-2 focus:ring-blue-500/20"
                    >
                    <component :is="method.icon" class="w-4 h-4 text-gray-600 dark:text-gray-400" />
                    <span class="text-sm text-gray-900 dark:text-white">{{ method.name }}</span>
                  </label>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- 推送设置 -->
    <div v-if="notificationsEnabled" class="mb-10">
      <h3 class="text-xl font-semibold text-gray-900 dark:text-white mb-6 pb-2 border-b-2 border-gray-200 dark:border-gray-700">
        推送设置
      </h3>

      <div class="space-y-6">
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between py-6 border-b border-gray-200 dark:border-gray-700">
          <div class="mb-4 sm:mb-0">
            <label class="block font-medium text-gray-900 dark:text-white mb-1">免打扰模式</label>
            <p class="text-sm text-gray-600 dark:text-gray-400">
              在指定时间段内静音所有通知
            </p>
          </div>
          <div class="sm:ml-8">
            <label class="inline-flex cursor-pointer items-center relative">
              <input
                v-model="doNotDisturbEnabled"
                type="checkbox"
                class="sr-only peer"
              >
              <div class="w-12 h-6 bg-gray-300 dark:bg-gray-600 rounded-full peer peer-checked:bg-blue-600 transition-colors relative">
                <div class="absolute w-5 h-5 bg-white rounded-full top-0.5 left-0.5 peer-checked:translate-x-6 transition-transform" />
              </div>
            </label>
          </div>
        </div>

        <div v-if="doNotDisturbEnabled" class="p-6 rounded-lg bg-gray-50 dark:bg-gray-900/50">
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-6">
            <div>
              <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1.5">开始时间</label>
              <input
                v-model="dndSchedule.start"
                type="time"
                class="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-white focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20 focus:outline-none"
              >
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1.5">结束时间</label>
              <input
                v-model="dndSchedule.end"
                type="time"
                class="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-white focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20 focus:outline-none"
              >
            </div>
          </div>
          <div>
            <div class="mb-3">
              <span class="text-sm font-medium text-gray-700 dark:text-gray-300">重复:</span>
            </div>
            <div class="flex flex-wrap gap-2">
              <label
                v-for="day in weekDays"
                :key="day.id"
                class="flex items-center gap-2 cursor-pointer"
              >
                <input
                  v-model="dndSchedule.days"
                  :value="day.id"
                  type="checkbox"
                  class="w-4 h-4 text-blue-600 bg-white dark:bg-gray-800 border-gray-300 dark:border-gray-600 rounded focus:ring-2 focus:ring-blue-500/20"
                >
                <span class="text-sm text-gray-900 dark:text-white">{{ day.name }}</span>
              </label>
            </div>
          </div>
        </div>

        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between py-6 border-b border-gray-200 dark:border-gray-700">
          <div class="mb-4 sm:mb-0">
            <label class="block font-medium text-gray-900 dark:text-white mb-1">通知声音</label>
            <p class="text-sm text-gray-600 dark:text-gray-400">
              选择通知提示音
            </p>
          </div>
          <div class="sm:ml-8">
            <div class="flex gap-2">
              <select
                v-model="selectedSound"
                class="px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-white focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20 focus:outline-none"
              >
                <option
                  v-for="sound in notificationSounds"
                  :key="sound.id"
                  :value="sound.id"
                >
                  {{ sound.name }}
                </option>
              </select>
              <button
                class="flex items-center gap-2 px-4 py-2 border border-gray-300 dark:border-gray-600 hover:bg-gray-50 dark:hover:bg-gray-700 rounded-lg transition-colors"
                @click="playSound"
              >
                <Volume2 class="w-4 h-4" />
                试听
              </button>
            </div>
          </div>
        </div>

        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between py-6 border-b border-gray-200 dark:border-gray-700">
          <div class="mb-4 sm:mb-0">
            <label class="block font-medium text-gray-900 dark:text-white mb-1">通知持续时间</label>
            <p class="text-sm text-gray-600 dark:text-gray-400">
              通知在屏幕上显示的时间
            </p>
          </div>
          <div class="sm:ml-8">
            <select
              v-model="notificationDuration"
              class="w-full sm:w-48 px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-white focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20 focus:outline-none"
            >
              <option :value="3">
                3 秒
              </option>
              <option :value="5">
                5 秒
              </option>
              <option :value="10">
                10 秒
              </option>
              <option :value="0">
                手动关闭
              </option>
            </select>
          </div>
        </div>
      </div>
    </div>

    <!-- 邮件通知 -->
    <div v-if="notificationsEnabled" class="mb-10">
      <h3 class="text-xl font-semibold text-gray-900 dark:text-white mb-6 pb-2 border-b-2 border-gray-200 dark:border-gray-700">
        邮件通知
      </h3>

      <div class="space-y-6">
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between py-6 border-b border-gray-200 dark:border-gray-700">
          <div class="mb-4 sm:mb-0">
            <label class="block font-medium text-gray-900 dark:text-white mb-1">邮件摘要</label>
            <p class="text-sm text-gray-600 dark:text-gray-400">
              定期发送活动摘要到您的邮箱
            </p>
          </div>
          <div class="sm:ml-8">
            <select
              v-model="emailSummaryFrequency"
              class="w-full sm:w-48 px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-white focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20 focus:outline-none"
            >
              <option value="never">
                从不
              </option>
              <option value="daily">
                每日
              </option>
              <option value="weekly">
                每周
              </option>
              <option value="monthly">
                每月
              </option>
            </select>
          </div>
        </div>

        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between py-6 border-b border-gray-200 dark:border-gray-700">
          <div class="mb-4 sm:mb-0">
            <label class="block font-medium text-gray-900 dark:text-white mb-1">营销邮件</label>
            <p class="text-sm text-gray-600 dark:text-gray-400">
              接收产品更新和营销信息
            </p>
          </div>
          <div class="sm:ml-8">
            <label class="inline-flex cursor-pointer items-center relative">
              <input
                v-model="marketingEmails"
                type="checkbox"
                class="sr-only peer"
              >
              <div class="w-12 h-6 bg-gray-300 dark:bg-gray-600 rounded-full peer peer-checked:bg-blue-600 transition-colors relative">
                <div class="absolute w-5 h-5 bg-white rounded-full top-0.5 left-0.5 peer-checked:translate-x-6 transition-transform" />
              </div>
            </label>
          </div>
        </div>
      </div>
    </div>

    <!-- 操作按钮 -->
    <div class="pt-8 border-t border-gray-200 dark:border-gray-700 flex flex-col sm:flex-row gap-4">
      <button
        class="flex items-center justify-center gap-2 px-6 py-3 bg-blue-600 hover:bg-blue-700 text-white font-medium rounded-lg transition-colors"
        @click="handleSave"
      >
        <Save class="w-4 h-4" />
        保存设置
      </button>
      <button
        class="flex items-center justify-center gap-2 px-6 py-3 border border-gray-300 dark:border-gray-600 hover:bg-gray-50 dark:hover:bg-gray-700 text-gray-900 dark:text-white font-medium rounded-lg transition-colors"
      >
        <Bell class="w-4 h-4" />
        测试通知
      </button>
    </div>
  </div>
</template>
