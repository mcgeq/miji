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
  <div class="general-settings-container">
    <!-- 通知偏好 -->
    <div class="general-settings-section">
      <h3 class="general-settings-title">
        通知偏好
      </h3>

      <div class="general-settings-items">
        <div class="general-setting-item">
          <div class="general-setting-label-wrapper">
            <label class="general-setting-label">启用通知</label>
            <p class="general-setting-description">
              接收应用和系统通知
            </p>
          </div>
          <div class="general-setting-control">
            <label class="toggle-switch">
              <input
                v-model="notificationsEnabled"
                type="checkbox"
                class="toggle-switch-input"
              >
              <div class="toggle-switch-track">
                <div class="toggle-switch-thumb" />
              </div>
            </label>
          </div>
        </div>

        <div v-if="notificationsEnabled" class="dnd-schedule general-settings-items">
          <div
            v-for="type in notificationTypes"
            :key="type.id"
            class="notification-type-card"
          >
            <div class="notification-type-header">
              <div class="notification-type-info">
                <component :is="type.icon" class="notification-type-icon" />
                <div>
                  <h4 class="notification-type-title">
                    {{ type.name }}
                  </h4>
                  <p class="notification-type-description">
                    {{ type.description }}
                  </p>
                </div>
              </div>
              <label class="toggle-switch">
                <input
                  v-model="type.enabled"
                  type="checkbox"
                  class="toggle-switch-input"
                >
                <div class="toggle-switch-track">
                  <div class="toggle-switch-thumb" />
                </div>
              </label>
            </div>

            <div v-if="type.enabled" class="notification-type-methods">
              <div class="notification-methods-label">
                <span>通知方式:</span>
                <div class="notification-methods-options">
                  <label
                    v-for="method in notificationMethods"
                    :key="method.id"
                    class="notification-method-checkbox"
                  >
                    <input
                      v-model="type.methods"
                      :value="method.id"
                      type="checkbox"
                      class="notification-method-checkbox-input"
                    >
                    <component :is="method.icon" class="notification-method-checkbox-icon" />
                    <span class="notification-method-checkbox-label">{{ method.name }}</span>
                  </label>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>

    <!-- 推送设置 -->
    <div v-if="notificationsEnabled" class="general-settings-section">
      <h3 class="general-settings-title">
        推送设置
      </h3>

      <div class="general-settings-items">
        <div class="general-setting-item">
          <div class="general-setting-label-wrapper">
            <label class="general-setting-label">免打扰模式</label>
            <p class="general-setting-description">
              在指定时间段内静音所有通知
            </p>
          </div>
          <div class="general-setting-control">
            <label class="toggle-switch">
              <input
                v-model="doNotDisturbEnabled"
                type="checkbox"
                class="toggle-switch-input"
              >
              <div class="toggle-switch-track">
                <div class="toggle-switch-thumb" />
              </div>
            </label>
          </div>
        </div>

        <div v-if="doNotDisturbEnabled" class="dnd-schedule">
          <div class="dnd-time-inputs">
            <div class="dnd-time-input-wrapper">
              <label>开始时间</label>
              <input
                v-model="dndSchedule.start"
                type="time"
                class="dnd-time-input"
              >
            </div>
            <div class="dnd-time-input-wrapper">
              <label>结束时间</label>
              <input
                v-model="dndSchedule.end"
                type="time"
                class="dnd-time-input"
              >
            </div>
          </div>
          <div>
            <div class="dnd-days-label">
              <span>重复:</span>
            </div>
            <div class="dnd-days-options">
              <label
                v-for="day in weekDays"
                :key="day.id"
                class="notification-method-checkbox"
              >
                <input
                  v-model="dndSchedule.days"
                  :value="day.id"
                  type="checkbox"
                  class="notification-method-checkbox-input"
                >
                <span class="notification-method-checkbox-label">{{ day.name }}</span>
              </label>
            </div>
          </div>
        </div>

        <div class="general-setting-item">
          <div class="general-setting-label-wrapper">
            <label class="general-setting-label">通知声音</label>
            <p class="general-setting-description">
              选择通知提示音
            </p>
          </div>
          <div class="general-setting-control">
            <div class="sound-selection">
              <select
                v-model="selectedSound"
                class="sound-select"
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
                class="sound-play-button"
                @click="playSound"
              >
                <Volume2 class="sound-play-icon" />
                试听
              </button>
            </div>
          </div>
        </div>

        <div class="general-setting-item">
          <div class="general-setting-label-wrapper">
            <label class="general-setting-label">通知持续时间</label>
            <p class="general-setting-description">
              通知在屏幕上显示的时间
            </p>
          </div>
          <div class="general-setting-control">
            <select
              v-model="notificationDuration"
              class="general-select"
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
    <div v-if="notificationsEnabled" class="general-settings-section">
      <h3 class="general-settings-title">
        邮件通知
      </h3>

      <div class="general-settings-items">
        <div class="general-setting-item">
          <div class="general-setting-label-wrapper">
            <label class="general-setting-label">邮件摘要</label>
            <p class="general-setting-description">
              定期发送活动摘要到您的邮箱
            </p>
          </div>
          <div class="general-setting-control">
            <select
              v-model="emailSummaryFrequency"
              class="general-select"
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

        <div class="general-setting-item">
          <div class="general-setting-label-wrapper">
            <label class="general-setting-label">营销邮件</label>
            <p class="general-setting-description">
              接收产品更新和营销信息
            </p>
          </div>
          <div class="general-setting-control">
            <label class="toggle-switch">
              <input
                v-model="marketingEmails"
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
    <div class="action-buttons">
      <button
        class="action-button-primary"
        @click="handleSave"
      >
        <Save class="action-button-primary-icon" />
        保存设置
      </button>
      <button
        class="action-button-secondary"
      >
        <Bell class="action-button-secondary-icon" />
        测试通知
      </button>
    </div>
  </div>
</template>
