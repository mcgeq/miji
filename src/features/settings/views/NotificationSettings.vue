<script setup lang="ts">
import {
  AlertTriangle,
  Mail,
  MessageSquare,
  Monitor,
  RotateCcw,
  Smartphone,
  Users,
  Volume2,
} from 'lucide-vue-next';
import { useI18n } from 'vue-i18n';
import { useAutoSaveSettings, createDatabaseSetting } from '@/composables/useAutoSaveSettings';
import ToggleSwitch from '@/components/ToggleSwitch.vue';
import { toast } from '@/utils/toast';

const { t } = useI18n();

// 默认通知类型配置
const defaultNotificationTypes = computed(() => [
  {
    id: 'messages',
    name: t('settings.notification.messages'),
    description: t('settings.notification.messagesDesc'),
    icon: MessageSquare,
    enabled: true,
    methods: ['desktop', 'mobile'],
  },
  {
    id: 'emails',
    name: t('settings.notification.emails'),
    description: t('settings.notification.emailsDesc'),
    icon: Mail,
    enabled: true,
    methods: ['desktop', 'email'],
  },
  {
    id: 'alerts',
    name: t('settings.notification.alerts'),
    description: t('settings.notification.alertsDesc'),
    icon: AlertTriangle,
    enabled: true,
    methods: ['desktop', 'mobile', 'email'],
  },
  {
    id: 'social',
    name: t('settings.notification.social'),
    description: t('settings.notification.socialDesc'),
    icon: Users,
    enabled: false,
    methods: ['desktop'],
  },
]);

// 通知方式
const notificationMethods = computed(() => [
  { id: 'desktop', name: t('settings.notification.desktop'), icon: Monitor },
  { id: 'mobile', name: t('settings.notification.mobile'), icon: Smartphone },
  { id: 'email', name: t('settings.notification.email'), icon: Mail },
]);

// 使用自动保存设置系统
const { fields, isSaving, resetAll } = useAutoSaveSettings({
  moduleName: 'notification',
  fields: {
    notificationsEnabled: createDatabaseSetting({
      key: 'settings.notification.enabled',
      defaultValue: true,
    }),
    notificationTypes: createDatabaseSetting({
      key: 'settings.notification.types',
      defaultValue: defaultNotificationTypes.value,
    }),
    doNotDisturbEnabled: createDatabaseSetting({
      key: 'settings.notification.doNotDisturb',
      defaultValue: false,
    }),
    dndSchedule: createDatabaseSetting({
      key: 'settings.notification.dndSchedule',
      defaultValue: {
        start: '22:00',
        end: '08:00',
        days: ['1', '2', '3', '4', '5'],
      },
    }),
    selectedSound: createDatabaseSetting({
      key: 'settings.notification.sound',
      defaultValue: 'default',
    }),
    notificationDuration: createDatabaseSetting({
      key: 'settings.notification.duration',
      defaultValue: 5,
    }),
    emailSummaryFrequency: createDatabaseSetting({
      key: 'settings.notification.emailSummaryFrequency',
      defaultValue: 'weekly',
    }),
    marketingEmails: createDatabaseSetting({
      key: 'settings.notification.marketingEmails',
      defaultValue: false,
    }),
  },
});

const weekDays = computed(() => [
  { id: '1', name: t('settings.notification.weekDays.monday') },
  { id: '2', name: t('settings.notification.weekDays.tuesday') },
  { id: '3', name: t('settings.notification.weekDays.wednesday') },
  { id: '4', name: t('settings.notification.weekDays.thursday') },
  { id: '5', name: t('settings.notification.weekDays.friday') },
  { id: '6', name: t('settings.notification.weekDays.saturday') },
  { id: '0', name: t('settings.notification.weekDays.sunday') },
]);

const notificationSounds = computed(() => [
  { id: 'default', name: t('settings.notification.soundOptions.default') },
  { id: 'gentle', name: t('settings.notification.soundOptions.gentle') },
  { id: 'alert', name: t('settings.notification.soundOptions.alert') },
  { id: 'chime', name: t('settings.notification.soundOptions.chime') },
  { id: 'none', name: t('settings.notification.soundOptions.none') },
]);

// 播放声音
function playSound() {
  toast.info(`播放声音: ${fields.selectedSound.value.value}`);
}

// 重置设置
async function handleReset() {
  await resetAll();
  toast.info(t('settings.notification.resetNotification'));
}
</script>

<template>
  <div class="max-w-4xl w-full">
    <!-- 通知偏好 -->
    <div class="mb-10">
      <h3 class="text-xl font-semibold text-gray-900 dark:text-white mb-6 pb-2 border-b-2 border-gray-200 dark:border-gray-700">
        {{ $t('settings.notification.preferences') }}
      </h3>

      <div class="space-y-6">
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between py-6 border-b border-gray-200 dark:border-gray-700">
          <div class="mb-4 sm:mb-0">
            <label class="block font-medium text-gray-900 dark:text-white mb-1">{{ $t('settings.notification.enable') }}</label>
            <p class="text-sm text-gray-600 dark:text-gray-400">
              {{ $t('settings.notification.enableDesc') }}
            </p>
          </div>
          <div class="sm:ml-8">
            <ToggleSwitch v-model="fields.notificationsEnabled.value.value" />
          </div>
        </div>

        <div v-if="fields.notificationsEnabled.value.value" class="space-y-4">
          <div
            v-for="type in fields.notificationTypes.value.value"
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
              <ToggleSwitch v-model="type.enabled" />
            </div>

            <div v-if="type.enabled" class="pt-4 border-t border-gray-200 dark:border-gray-700">
              <div class="flex flex-col sm:flex-row sm:items-center gap-4">
                <span class="text-sm font-medium text-gray-700 dark:text-gray-300 whitespace-nowrap">{{ $t('settings.notification.methodsLabel') }}</span>
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
    <div v-if="fields.notificationsEnabled.value.value" class="mb-10">
      <h3 class="text-xl font-semibold text-gray-900 dark:text-white mb-6 pb-2 border-b-2 border-gray-200 dark:border-gray-700">
        {{ $t('settings.notification.pushSettings') }}
      </h3>

      <div class="space-y-6">
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between py-6 border-b border-gray-200 dark:border-gray-700">
          <div class="mb-4 sm:mb-0">
            <label class="block font-medium text-gray-900 dark:text-white mb-1">{{ $t('settings.notification.doNotDisturb') }}</label>
            <p class="text-sm text-gray-600 dark:text-gray-400">
              {{ $t('settings.notification.doNotDisturbDesc') }}
            </p>
          </div>
          <div class="sm:ml-8">
            <ToggleSwitch v-model="fields.doNotDisturbEnabled.value.value" />
          </div>
        </div>

        <div v-if="fields.doNotDisturbEnabled.value.value" class="p-6 rounded-lg bg-gray-50 dark:bg-gray-900/50">
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-6">
            <div>
              <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1.5">{{ $t('settings.notification.startTime') }}</label>
              <input
                v-model="fields.dndSchedule.value.value.start"
                type="time"
                class="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-white focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20 focus:outline-none"
              >
            </div>
            <div>
              <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1.5">{{ $t('settings.notification.endTime') }}</label>
              <input
                v-model="fields.dndSchedule.value.value.end"
                type="time"
                class="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-white focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20 focus:outline-none"
              >
            </div>
          </div>
          <div>
            <div class="mb-3">
              <span class="text-sm font-medium text-gray-700 dark:text-gray-300">{{ $t('settings.notification.repeat') }}</span>
            </div>
            <div class="flex flex-wrap gap-2">
              <label
                v-for="day in weekDays"
                :key="day.id"
                class="flex items-center gap-2 cursor-pointer"
              >
                <input
                  v-model="fields.dndSchedule.value.value.days"
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
            <label class="block font-medium text-gray-900 dark:text-white mb-1">{{ $t('settings.notification.sound') }}</label>
            <p class="text-sm text-gray-600 dark:text-gray-400">
              {{ $t('settings.notification.soundDesc') }}
            </p>
          </div>
          <div class="sm:ml-8">
            <div class="flex gap-2">
              <select
                v-model="fields.selectedSound.value.value"
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
                {{ $t('settings.notification.testSound') }}
              </button>
            </div>
          </div>
        </div>

        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between py-6 border-b border-gray-200 dark:border-gray-700">
          <div class="mb-4 sm:mb-0">
            <label class="block font-medium text-gray-900 dark:text-white mb-1">{{ $t('settings.notification.duration') }}</label>
            <p class="text-sm text-gray-600 dark:text-gray-400">
              {{ $t('settings.notification.durationDesc') }}
            </p>
          </div>
          <div class="sm:ml-8">
            <select
              v-model="fields.notificationDuration.value.value"
              class="w-full sm:w-48 px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-white focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20 focus:outline-none"
            >
              <option :value="3">
                {{ $t('settings.notification.durationOptions.3s') }}
              </option>
              <option :value="5">
                {{ $t('settings.notification.durationOptions.5s') }}
              </option>
              <option :value="10">
                {{ $t('settings.notification.durationOptions.10s') }}
              </option>
              <option :value="0">
                {{ $t('settings.notification.durationOptions.manual') }}
              </option>
            </select>
          </div>
        </div>
      </div>
    </div>

    <!-- 邮件通知 -->
    <div v-if="fields.notificationsEnabled.value.value" class="mb-10">
      <h3 class="text-xl font-semibold text-gray-900 dark:text-white mb-6 pb-2 border-b-2 border-gray-200 dark:border-gray-700">
        {{ $t('settings.notification.emailNotification') }}
      </h3>

      <div class="space-y-6">
        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between py-6 border-b border-gray-200 dark:border-gray-700">
          <div class="mb-4 sm:mb-0">
            <label class="block font-medium text-gray-900 dark:text-white mb-1">{{ $t('settings.notification.emailSummary') }}</label>
            <p class="text-sm text-gray-600 dark:text-gray-400">
              {{ $t('settings.notification.emailSummaryDesc') }}
            </p>
          </div>
          <div class="sm:ml-8">
            <select
              v-model="fields.emailSummaryFrequency.value.value"
              class="w-full sm:w-48 px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-white focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20 focus:outline-none"
            >
              <option value="never">
                {{ $t('settings.notification.frequencyOptions.never') }}
              </option>
              <option value="daily">
                {{ $t('settings.notification.frequencyOptions.daily') }}
              </option>
              <option value="weekly">
                {{ $t('settings.notification.frequencyOptions.weekly') }}
              </option>
              <option value="monthly">
                {{ $t('settings.notification.frequencyOptions.monthly') }}
              </option>
            </select>
          </div>
        </div>

        <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between py-6 border-b border-gray-200 dark:border-gray-700">
          <div class="mb-4 sm:mb-0">
            <label class="block font-medium text-gray-900 dark:text-white mb-1">{{ $t('settings.notification.marketingEmails') }}</label>
            <p class="text-sm text-gray-600 dark:text-gray-400">
              {{ $t('settings.notification.marketingEmailsDesc') }}
            </p>
          </div>
          <div class="sm:ml-8">
            <ToggleSwitch v-model="fields.marketingEmails.value.value" />
          </div>
        </div>
      </div>
    </div>

    <!-- 操作按钮 -->
    <div class="pt-8 border-t border-gray-200 dark:border-gray-700 flex justify-center gap-4">
      <button
        :title="$t('settings.general.resetSettings')"
        class="flex items-center justify-center w-12 h-12 rounded-full bg-gray-100 hover:bg-gray-200 dark:bg-gray-700 dark:hover:bg-gray-600 text-gray-900 dark:text-white transition-colors"
        @click="handleReset"
      >
        <RotateCcw class="w-5 h-5" />
      </button>
      <button
        :title="$t('settings.notification.testNotification')"
        class="flex items-center justify-center w-12 h-12 rounded-full border border-gray-300 dark:border-gray-600 hover:bg-gray-50 dark:hover:bg-gray-700 text-gray-900 dark:text-white transition-colors"
        @click="playSound"
      >
        <Volume2 class="w-5 h-5" />
      </button>
      <div v-if="isSaving" class="flex items-center justify-center w-12 h-12 text-gray-600 dark:text-gray-400">
        <span class="animate-spin text-xl">⏳</span>
      </div>
    </div>
  </div>
</template>
