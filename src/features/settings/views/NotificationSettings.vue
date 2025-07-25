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
  <div class="max-w-4xl">
    <!-- 通知偏好 -->
    <div class="mb-10">
      <h3 class="mb-6 border-b-2 border-slate-200 pb-2 text-xl text-slate-800 font-semibold">
        通知偏好
      </h3>

      <div class="space-y-6">
        <div class="flex flex-col border-b border-slate-100 py-6 sm:flex-row sm:items-center sm:justify-between">
          <div class="mb-4 sm:mb-0">
            <label class="mb-1 block text-slate-700 font-medium">启用通知</label>
            <p class="text-sm text-slate-500">
              接收应用和系统通知
            </p>
          </div>
          <div class="sm:ml-8">
            <label class="relative inline-flex cursor-pointer items-center">
              <input
                v-model="notificationsEnabled"
                type="checkbox"
                class="peer sr-only"
              >
              <div class="peer relative h-6 w-12 rounded-full bg-slate-300 after:absolute after:left-0.5 after:top-0.5 after:h-5 after:w-5 after:rounded-full after:bg-white peer-checked:bg-blue-500 peer-focus:ring-2 peer-focus:ring-blue-500 after:transition-all after:content-[''] peer-checked:after:translate-x-6 peer-checked:after:border-white" />
            </label>
          </div>
        </div>

        <div v-if="notificationsEnabled" class="rounded-xl bg-slate-50 p-6 space-y-6">
          <div
            v-for="type in notificationTypes"
            :key="type.id"
            class="border border-slate-200 rounded-lg bg-white p-6"
          >
            <div class="mb-4 flex items-center justify-between">
              <div class="flex items-center gap-4">
                <component :is="type.icon" class="h-5 w-5 text-blue-500" />
                <div>
                  <h4 class="text-slate-800 font-medium">
                    {{ type.name }}
                  </h4>
                  <p class="text-sm text-slate-500">
                    {{ type.description }}
                  </p>
                </div>
              </div>
              <label class="relative inline-flex cursor-pointer items-center">
                <input
                  v-model="type.enabled"
                  type="checkbox"
                  class="peer sr-only"
                >
                <div class="peer relative h-6 w-12 rounded-full bg-slate-300 after:absolute after:left-0.5 after:top-0.5 after:h-5 after:w-5 after:rounded-full after:bg-white peer-checked:bg-blue-500 peer-focus:ring-2 peer-focus:ring-blue-500 after:transition-all after:content-[''] peer-checked:after:translate-x-6 peer-checked:after:border-white" />
              </label>
            </div>

            <div v-if="type.enabled" class="border-t border-slate-100 pt-4">
              <div class="flex flex-col gap-4 sm:flex-row sm:items-center">
                <span class="whitespace-nowrap text-sm text-slate-600 font-medium">通知方式:</span>
                <div class="flex flex-wrap gap-2">
                  <label
                    v-for="method in notificationMethods"
                    :key="method.id"
                    class="flex cursor-pointer items-center gap-2"
                  >
                    <input
                      v-model="type.methods"
                      :value="method.id"
                      type="checkbox"
                      class="h-4 w-4 border-gray-300 rounded bg-gray-100 text-blue-600 focus:ring-blue-500"
                    >
                    <component :is="method.icon" class="h-4 w-4 text-slate-500" />
                    <span class="text-sm text-slate-700">{{ method.name }}</span>
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
      <h3 class="mb-6 border-b-2 border-slate-200 pb-2 text-xl text-slate-800 font-semibold">
        推送设置
      </h3>

      <div class="space-y-6">
        <div class="flex flex-col border-b border-slate-100 py-6 sm:flex-row sm:items-center sm:justify-between">
          <div class="mb-4 sm:mb-0">
            <label class="mb-1 block text-slate-700 font-medium">免打扰模式</label>
            <p class="text-sm text-slate-500">
              在指定时间段内静音所有通知
            </p>
          </div>
          <div class="sm:ml-8">
            <label class="relative inline-flex cursor-pointer items-center">
              <input
                v-model="doNotDisturbEnabled"
                type="checkbox"
                class="peer sr-only"
              >
              <div class="peer relative h-6 w-12 rounded-full bg-slate-300 after:absolute after:left-0.5 after:top-0.5 after:h-5 after:w-5 after:rounded-full after:bg-white peer-checked:bg-blue-500 peer-focus:ring-2 peer-focus:ring-blue-500 after:transition-all after:content-[''] peer-checked:after:translate-x-6 peer-checked:after:border-white" />
            </label>
          </div>
        </div>

        <div v-if="doNotDisturbEnabled" class="rounded-xl bg-slate-50 p-6">
          <div class="grid grid-cols-1 mb-6 gap-4 md:grid-cols-2">
            <div>
              <label class="mb-2 block text-sm text-slate-700 font-medium">开始时间</label>
              <input
                v-model="dndSchedule.start"
                type="time"
                class="w-full border border-slate-300 rounded-lg px-3 py-2 focus:border-blue-500 focus:ring-2 focus:ring-blue-500"
              >
            </div>
            <div>
              <label class="mb-2 block text-sm text-slate-700 font-medium">结束时间</label>
              <input
                v-model="dndSchedule.end"
                type="time"
                class="w-full border border-slate-300 rounded-lg px-3 py-2 focus:border-blue-500 focus:ring-2 focus:ring-blue-500"
              >
            </div>
          </div>
          <div>
            <div class="mb-3">
              <span class="text-sm text-slate-700 font-medium">重复:</span>
            </div>
            <div class="flex flex-wrap gap-2">
              <label
                v-for="day in weekDays"
                :key="day.id"
                class="flex cursor-pointer items-center gap-2"
              >
                <input
                  v-model="dndSchedule.days"
                  :value="day.id"
                  type="checkbox"
                  class="h-4 w-4 border-gray-300 rounded bg-gray-100 text-blue-600 focus:ring-blue-500"
                >
                <span class="text-sm text-slate-700">{{ day.name }}</span>
              </label>
            </div>
          </div>
        </div>

        <div class="flex flex-col border-b border-slate-100 py-6 sm:flex-row sm:items-center sm:justify-between">
          <div class="mb-4 sm:mb-0">
            <label class="mb-1 block text-slate-700 font-medium">通知声音</label>
            <p class="text-sm text-slate-500">
              选择通知提示音
            </p>
          </div>
          <div class="sm:ml-8">
            <div class="flex gap-2">
              <select
                v-model="selectedSound"
                class="border border-slate-300 rounded-lg bg-white px-4 py-2 focus:border-blue-500 focus:ring-2 focus:ring-blue-500"
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
                class="flex items-center gap-2 border border-slate-300 rounded-lg bg-slate-100 px-4 py-2 text-slate-700 transition-all duration-200 hover:bg-slate-200"
                @click="playSound"
              >
                <Volume2 class="h-4 w-4" />
                试听
              </button>
            </div>
          </div>
        </div>

        <div class="flex flex-col border-b border-slate-100 py-6 sm:flex-row sm:items-center sm:justify-between">
          <div class="mb-4 sm:mb-0">
            <label class="mb-1 block text-slate-700 font-medium">通知持续时间</label>
            <p class="text-sm text-slate-500">
              通知在屏幕上显示的时间
            </p>
          </div>
          <div class="sm:ml-8">
            <select
              v-model="notificationDuration"
              class="w-full border border-slate-300 rounded-lg bg-white px-4 py-2 sm:w-40 focus:border-blue-500 focus:ring-2 focus:ring-blue-500"
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
      <h3 class="mb-6 border-b-2 border-slate-200 pb-2 text-xl text-slate-800 font-semibold">
        邮件通知
      </h3>

      <div class="space-y-6">
        <div class="flex flex-col border-b border-slate-100 py-6 sm:flex-row sm:items-center sm:justify-between">
          <div class="mb-4 sm:mb-0">
            <label class="mb-1 block text-slate-700 font-medium">邮件摘要</label>
            <p class="text-sm text-slate-500">
              定期发送活动摘要到您的邮箱
            </p>
          </div>
          <div class="sm:ml-8">
            <select
              v-model="emailSummaryFrequency"
              class="w-full border border-slate-300 rounded-lg bg-white px-4 py-2 sm:w-40 focus:border-blue-500 focus:ring-2 focus:ring-blue-500"
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

        <div class="flex flex-col py-6 sm:flex-row sm:items-center sm:justify-between">
          <div class="mb-4 sm:mb-0">
            <label class="mb-1 block text-slate-700 font-medium">营销邮件</label>
            <p class="text-sm text-slate-500">
              接收产品更新和营销信息
            </p>
          </div>
          <div class="sm:ml-8">
            <label class="relative inline-flex cursor-pointer items-center">
              <input
                v-model="marketingEmails"
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
      >
        <Bell class="h-4 w-4" />
        测试通知
      </button>
    </div>
  </div>
</template>
