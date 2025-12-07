<script setup lang="ts">
  import {
    Activity,
    AlertCircle,
    AlertTriangle,
    BarChart3,
    Bell,
    Calendar,
    CheckSquare,
    CreditCard,
    Heart,
    Loader2,
    RefreshCw,
    RotateCcw,
    Settings as SettingsIcon,
    Unlock,
    Volume2,
  } from 'lucide-vue-next';
  import { computed, ref, watchEffect } from 'vue';
  import { useRouter } from 'vue-router';
  import ToggleSwitch from '@/components/ToggleSwitch.vue';
  import Alert from '@/components/ui/Alert.vue';
  import Badge from '@/components/ui/Badge.vue';
  import Button from '@/components/ui/Button.vue';
  import Card from '@/components/ui/Card.vue';
  import { useNotificationPermission } from '@/composables/useNotificationPermission';
  import { useNotificationSettings } from '@/composables/useNotificationSettings';
  import type { NotificationSettingsForm } from '@/types/notification';
  import {
    NotificationType,
    NotificationTypeDescription,
    NotificationTypeLabel,
  } from '@/types/notification';
  import { toast } from '@/utils/toast';

  const router = useRouter();

  // 使用通知设置 composable
  const {
    isLoading,
    isAuthenticated,
    settings,
    settingsMap,
    enabledTypes,
    updateNotificationType,
    resetSettings,
  } = useNotificationSettings();

  // 使用通知权限 composable
  const {
    hasPermission,
    statusText,
    statusColor,
    checking,
    error: permissionError,
    isProcessing,
    checkPermission,
    requestPermission,
    openSettings: openSystemSettings,
    clearError,
  } = useNotificationPermission();

  // 图标映射
  const iconMap = {
    [NotificationType.TODO_REMINDER]: CheckSquare,
    [NotificationType.BILL_REMINDER]: CreditCard,
    [NotificationType.PERIOD_REMINDER]: Calendar,
    [NotificationType.OVULATION_REMINDER]: Heart,
    [NotificationType.PMS_REMINDER]: Activity,
    [NotificationType.SYSTEM_ALERT]: AlertCircle,
  };

  // 免打扰设置
  const dndEnabled = ref(false);
  const dndSchedule = ref({
    start: '22:00',
    end: '08:00',
    days: ['1', '2', '3', '4', '5'], // 工作日
  });

  // 声音设置
  const soundEnabled = ref(true);
  const vibrationEnabled = ref(true);
  const selectedSound = ref('default');

  // 通知持续时间（秒）
  const notificationDuration = ref(5);

  // 邮件通知设置
  const emailSummaryFrequency = ref('weekly');
  const marketingEmails = ref(false);

  // 声音选项
  const notificationSounds = [
    { id: 'default', name: '默认' },
    { id: 'gentle', name: '轻柔' },
    { id: 'alert', name: '警报' },
    { id: 'chime', name: '铃声' },
    { id: 'none', name: '无声' },
  ];

  // 持续时间选项
  const durationOptions = [
    { value: 3, label: '3秒' },
    { value: 5, label: '5秒' },
    { value: 10, label: '10秒' },
    { value: 0, label: '手动关闭' },
  ];

  // 邮件摘要频率选项
  const emailFrequencyOptions = [
    { value: 'never', label: '从不' },
    { value: 'daily', label: '每日' },
    { value: 'weekly', label: '每周' },
    { value: 'monthly', label: '每月' },
  ];

  // 通知类型列表
  const notificationTypes = computed(() => {
    return [
      NotificationType.TODO_REMINDER,
      NotificationType.BILL_REMINDER,
      NotificationType.PERIOD_REMINDER,
      NotificationType.OVULATION_REMINDER,
      NotificationType.PMS_REMINDER,
      NotificationType.SYSTEM_ALERT,
    ].map(type => ({
      type,
      label: NotificationTypeLabel[type],
      description: NotificationTypeDescription[type],
      icon: iconMap[type],
      enabled: enabledTypes.value.includes(type),
      settings: settingsMap.value.get(type),
    }));
  });

  // 星期选项
  const weekDays = computed(() => [
    { id: '1', name: '周一' },
    { id: '2', name: '周二' },
    { id: '3', name: '周三' },
    { id: '4', name: '周四' },
    { id: '5', name: '周五' },
    { id: '6', name: '周六' },
    { id: '0', name: '周日' },
  ]);

  // 切换通知类型
  async function toggleNotificationType(type: NotificationType, enabled: boolean) {
    if (!hasPermission.value) {
      toast.warning('请先授予通知权限');
      return;
    }

    try {
      await updateNotificationType(
        type,
        enabled,
        dndEnabled.value ? dndSchedule.value.start : undefined,
        dndEnabled.value ? dndSchedule.value.end : undefined,
        dndEnabled.value ? dndSchedule.value.days : undefined,
        soundEnabled.value,
        vibrationEnabled.value,
      );
    } catch (error) {
      // Error already handled in composable
    }
  }

  // 更新免打扰设置
  async function updateDndSettings() {
    if (!hasPermission.value) {
      toast.warning('请先授予通知权限');
      return;
    }

    try {
      // 批量更新所有启用的通知类型
      const updates: NotificationSettingsForm[] = enabledTypes.value.map(type => ({
        notificationType: type,
        enabled: true,
        quietHoursStart: dndEnabled.value ? dndSchedule.value.start : undefined,
        quietHoursEnd: dndEnabled.value ? dndSchedule.value.end : undefined,
        quietDays: dndEnabled.value ? dndSchedule.value.days : undefined,
        soundEnabled: soundEnabled.value,
        vibrationEnabled: vibrationEnabled.value,
      }));

      if (updates.length > 0) {
        const { updateSettings } = useNotificationSettings();
        await updateSettings(updates);
        toast.success('免打扰设置已更新');
      }
    } catch (error) {
      // Error already handled
    }
  }

  // 重置所有设置
  async function handleReset() {
    if (confirm('确定要重置所有通知设置吗？')) {
      try {
        await resetSettings();
      } catch (error) {
        // Error already handled
      }
    }
  }

  // 播放测试声音
  function playSound() {
    toast.info(
      `播放声音: ${notificationSounds.find(s => s.id === selectedSound.value)?.name || '默认'}`,
    );
  }

  // 发送测试通知
  function sendTestNotification() {
    toast.info('📬 测试通知已发送');
  }

  // 查看通知历史
  function viewNotificationHistory() {
    router.push({
      path: '/notifications',
      query: { from: 'settings' },
    });
  }

  // 授予权限
  async function handleRequestPermission() {
    await requestPermission();
    if (hasPermission.value) {
      toast.success('通知权限已授予');
    }
  }

  // 打开系统设置
  function handleOpenSettings() {
    openSystemSettings();
  }

  // 查看统计
  function viewStatistics() {
    router.push({
      path: '/notification-dashboard',
      query: { from: 'settings' },
    });
  }

  // 从现有设置加载免打扰配置
  watchEffect(() => {
    if (settings.value.length > 0) {
      const firstSetting = settings.value[0];
      if (firstSetting.quietHoursStart && firstSetting.quietHoursEnd) {
        dndEnabled.value = true;
        dndSchedule.value = {
          start: firstSetting.quietHoursStart,
          end: firstSetting.quietHoursEnd,
          days: firstSetting.quietDays || ['1', '2', '3', '4', '5'],
        };
      }
      soundEnabled.value = firstSetting.soundEnabled;
      vibrationEnabled.value = firstSetting.vibrationEnabled;
    }
  });
</script>

<template>
  <div class="max-w-4xl w-full space-y-6">
    <!-- 未登录提示 -->
    <div
      v-if="!isAuthenticated"
      class="p-6 bg-yellow-50 dark:bg-yellow-900/20 border border-yellow-200 dark:border-yellow-700 rounded-lg"
    >
      <div class="flex items-center gap-3">
        <AlertTriangle class="w-5 h-5 text-yellow-600 dark:text-yellow-400" />
        <p class="text-yellow-800 dark:text-yellow-200">请先登录以管理通知设置</p>
      </div>
    </div>

    <!-- 加载状态 -->
    <div
      v-else-if="isLoading && settings.length === 0"
      class="flex items-center justify-center py-12"
    >
      <Loader2 class="w-8 h-8 animate-spin text-blue-600" />
      <span class="ml-3 text-gray-600 dark:text-gray-400">加载通知设置中...</span>
    </div>

    <template v-else>
      <!-- 通知权限卡片 -->
      <Card>
        <template #header>
          <div class="flex items-center justify-between">
            <div class="flex items-center space-x-2">
              <Bell class="w-5 h-5" />
              <h3 class="font-semibold">通知权限</h3>
            </div>
            <div class="flex items-center gap-2">
              <Badge :color="statusColor">{{ statusText }}</Badge>
              <button
                @click="viewNotificationHistory"
                title="通知历史"
                class="p-2 flex items-center justify-center border border-gray-300 dark:border-gray-600 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-700 transition-colors text-gray-700 dark:text-gray-300"
              >
                <Bell class="w-4 h-4" />
              </button>
              <button
                @click="viewStatistics"
                title="查看统计"
                class="p-2 flex items-center justify-center border border-gray-300 dark:border-gray-600 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-700 transition-colors text-gray-700 dark:text-gray-300"
              >
                <BarChart3 class="w-4 h-4" />
              </button>
            </div>
          </div>
        </template>

        <div class="space-y-4">
          <!-- 权限说明 -->
          <p class="text-sm text-gray-600 dark:text-gray-400">
            {{
              hasPermission
                ? '通知权限已授予，您将收到及时的提醒通知'
                : '需要通知权限才能及时提醒您的待办、账单和健康事项'
            }}
          </p>

          <!-- 错误提示 -->
          <Alert v-if="permissionError" type="error" @close="clearError">
            {{ permissionError }}
          </Alert>

          <!-- 权限操作按钮 -->
          <div class="flex space-x-2">
            <Button
              v-if="!hasPermission"
              @click="handleRequestPermission"
              :loading="isProcessing"
              variant="primary"
            >
              <Unlock class="w-4 h-4 mr-2" />
              授予权限
            </Button>

            <button
              @click="handleOpenSettings"
              :disabled="isProcessing"
              title="系统设置"
              class="p-2 flex items-center justify-center border border-gray-300 dark:border-gray-600 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-700 transition-colors text-gray-700 dark:text-gray-300 disabled:opacity-50"
            >
              <SettingsIcon class="w-4 h-4" />
            </button>

            <button
              @click="checkPermission"
              :disabled="checking"
              title="刷新状态"
              class="p-2 flex items-center justify-center border border-gray-300 dark:border-gray-600 rounded-lg hover:bg-gray-50 dark:hover:bg-gray-700 transition-colors text-gray-700 dark:text-gray-300 disabled:opacity-50"
            >
              <RefreshCw class="w-4 h-4" :class="{ 'animate-spin': checking }" />
            </button>
          </div>
        </div>
      </Card>

      <!-- 通知类型 -->
      <Card>
        <template #header>
          <h3 class="font-semibold">通知类型</h3>
        </template>

        <div class="space-y-4">
          <div
            v-for="item in notificationTypes"
            :key="item.type"
            class="flex items-center justify-between p-4 rounded-lg border border-gray-200 dark:border-gray-700 transition-opacity"
            :class="{ 'opacity-50': isLoading || !hasPermission }"
          >
            <div class="flex items-center gap-4 flex-1">
              <component :is="item.icon" class="w-5 h-5 text-blue-600 dark:text-blue-400" />
              <div class="flex-1">
                <div class="flex items-center gap-2">
                  <h4 class="font-medium text-gray-900 dark:text-white">{{ item.label }}</h4>
                  <Badge v-if="!hasPermission" color="gray" size="sm">需要权限</Badge>
                </div>
                <p class="text-sm text-gray-600 dark:text-gray-400">{{ item.description }}</p>
              </div>
            </div>
            <ToggleSwitch
              :model-value="item.enabled"
              :disabled="isLoading || !hasPermission"
              @update:model-value="(val: boolean) => toggleNotificationType(item.type, val)"
            />
          </div>
        </div>
      </Card>

      <!-- 免打扰设置 -->
      <Card>
        <template #header>
          <h3 class="font-semibold">免打扰模式</h3>
        </template>

        <div class="space-y-6">
          <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between py-4">
            <div class="mb-4 sm:mb-0">
              <label class="block font-medium text-gray-900 dark:text-white mb-1">启用免打扰</label>
              <p class="text-sm text-gray-600 dark:text-gray-400">在指定时间段内不接收通知</p>
            </div>
            <div class="sm:ml-8">
              <ToggleSwitch
                v-model="dndEnabled"
                :disabled="isLoading || !hasPermission"
                @update:model-value="updateDndSettings"
              />
            </div>
          </div>

          <div v-if="dndEnabled" class="p-6 rounded-lg bg-gray-50 dark:bg-gray-900/50">
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-6">
              <div>
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1.5">
                  开始时间
                </label>
                <input
                  v-model="dndSchedule.start"
                  type="time"
                  :disabled="isLoading || !hasPermission"
                  class="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-white focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20 focus:outline-none disabled:opacity-50"
                  @change="updateDndSettings"
                />
              </div>
              <div>
                <label class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1.5">
                  结束时间
                </label>
                <input
                  v-model="dndSchedule.end"
                  type="time"
                  :disabled="isLoading || !hasPermission"
                  class="w-full px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-white focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20 focus:outline-none disabled:opacity-50"
                  @change="updateDndSettings"
                />
              </div>
            </div>
            <div>
              <div class="mb-3">
                <span class="text-sm font-medium text-gray-700 dark:text-gray-300">重复日期</span>
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
                    :disabled="isLoading || !hasPermission"
                    type="checkbox"
                    class="w-4 h-4 text-blue-600 bg-white dark:bg-gray-800 border-gray-300 dark:border-gray-600 rounded focus:ring-2 focus:ring-blue-500/20 disabled:opacity-50"
                    @change="updateDndSettings"
                  />
                  <span class="text-sm text-gray-900 dark:text-white">{{ day.name }}</span>
                </label>
              </div>
            </div>
          </div>
        </div>
      </Card>

      <!-- 声音和震动 -->
      <Card>
        <template #header>
          <h3 class="font-semibold">声音和震动</h3>
        </template>

        <div class="space-y-6">
          <!-- 启用声音 -->
          <div
            class="flex flex-col sm:flex-row sm:items-center sm:justify-between py-4 border-b border-gray-200 dark:border-gray-700"
          >
            <div class="mb-4 sm:mb-0">
              <label class="block font-medium text-gray-900 dark:text-white mb-1">启用声音</label>
              <p class="text-sm text-gray-600 dark:text-gray-400">接收通知时播放声音</p>
            </div>
            <div class="sm:ml-8">
              <ToggleSwitch
                v-model="soundEnabled"
                :disabled="isLoading || !hasPermission"
                @update:model-value="updateDndSettings"
              />
            </div>
          </div>

          <!-- 声音选择 -->
          <div
            v-if="soundEnabled"
            class="flex flex-col sm:flex-row sm:items-center sm:justify-between py-4 border-b border-gray-200 dark:border-gray-700"
          >
            <div class="mb-4 sm:mb-0">
              <label class="block font-medium text-gray-900 dark:text-white mb-1">通知声音</label>
              <p class="text-sm text-gray-600 dark:text-gray-400">选择通知提示音</p>
            </div>
            <div class="sm:ml-8 flex gap-2">
              <select
                v-model="selectedSound"
                :disabled="isLoading || !hasPermission"
                class="px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-white focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20 focus:outline-none disabled:opacity-50"
              >
                <option v-for="sound in notificationSounds" :key="sound.id" :value="sound.id">
                  {{ sound.name }}
                </option>
              </select>
              <Button
                size="sm"
                variant="outline"
                :disabled="isLoading || !hasPermission"
                @click="playSound"
              >
                <Volume2 class="w-4 h-4 mr-2" />
                测试
              </Button>
            </div>
          </div>

          <!-- 震动 -->
          <div
            class="flex flex-col sm:flex-row sm:items-center sm:justify-between py-4 border-b border-gray-200 dark:border-gray-700"
          >
            <div class="mb-4 sm:mb-0">
              <label class="block font-medium text-gray-900 dark:text-white mb-1">震动</label>
              <p class="text-sm text-gray-600 dark:text-gray-400">接收通知时设备震动（移动端）</p>
            </div>
            <div class="sm:ml-8">
              <ToggleSwitch
                v-model="vibrationEnabled"
                :disabled="isLoading || !hasPermission"
                @update:model-value="updateDndSettings"
              />
            </div>
          </div>

          <!-- 通知持续时间 -->
          <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between py-4">
            <div class="mb-4 sm:mb-0">
              <label class="block font-medium text-gray-900 dark:text-white mb-1">
                通知持续时间
              </label>
              <p class="text-sm text-gray-600 dark:text-gray-400">通知显示的时长</p>
            </div>
            <div class="sm:ml-8">
              <select
                v-model="notificationDuration"
                :disabled="isLoading || !hasPermission"
                class="w-full sm:w-48 px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-white focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20 focus:outline-none disabled:opacity-50"
              >
                <option v-for="option in durationOptions" :key="option.value" :value="option.value">
                  {{ option.label }}
                </option>
              </select>
            </div>
          </div>
        </div>
      </Card>

      <!-- 邮件通知 -->
      <Card>
        <template #header>
          <h3 class="font-semibold">邮件通知</h3>
        </template>

        <div class="space-y-6">
          <!-- 邮件摘要频率 -->
          <div
            class="flex flex-col sm:flex-row sm:items-center sm:justify-between py-4 border-b border-gray-200 dark:border-gray-700"
          >
            <div class="mb-4 sm:mb-0">
              <label class="block font-medium text-gray-900 dark:text-white mb-1">邮件摘要</label>
              <p class="text-sm text-gray-600 dark:text-gray-400">定期接收通知摘要邮件</p>
            </div>
            <div class="sm:ml-8">
              <select
                v-model="emailSummaryFrequency"
                :disabled="isLoading || !hasPermission"
                class="w-full sm:w-48 px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-lg bg-white dark:bg-gray-800 text-gray-900 dark:text-white focus:border-blue-500 focus:ring-2 focus:ring-blue-500/20 focus:outline-none disabled:opacity-50"
              >
                <option
                  v-for="option in emailFrequencyOptions"
                  :key="option.value"
                  :value="option.value"
                >
                  {{ option.label }}
                </option>
              </select>
            </div>
          </div>

          <!-- 营销邮件 -->
          <div class="flex flex-col sm:flex-row sm:items-center sm:justify-between py-4">
            <div class="mb-4 sm:mb-0">
              <label class="block font-medium text-gray-900 dark:text-white mb-1">营销邮件</label>
              <p class="text-sm text-gray-600 dark:text-gray-400">接收产品更新和优惠信息</p>
            </div>
            <div class="sm:ml-8">
              <ToggleSwitch v-model="marketingEmails" :disabled="isLoading || !hasPermission" />
            </div>
          </div>
        </div>
      </Card>

      <!-- 操作按钮 -->
      <div class="pt-6 flex justify-center gap-2">
        <button
          @click="sendTestNotification"
          :disabled="isLoading || !hasPermission"
          title="测试通知"
          class="flex items-center justify-center w-10 h-10 rounded-lg border border-gray-300 dark:border-gray-600 hover:bg-gray-50 dark:hover:bg-gray-700 text-gray-900 dark:text-white transition-colors disabled:opacity-50"
        >
          <Bell class="w-5 h-5" />
        </button>
        <button
          @click="handleReset"
          :disabled="isLoading || !hasPermission"
          title="重置设置"
          class="flex items-center justify-center w-10 h-10 rounded-lg bg-gray-100 hover:bg-gray-200 dark:bg-gray-700 dark:hover:bg-gray-600 text-gray-900 dark:text-white transition-colors disabled:opacity-50"
        >
          <RotateCcw class="w-5 h-5" />
        </button>
        <div
          v-if="isLoading"
          class="flex items-center justify-center w-10 h-10 text-blue-600 dark:text-blue-400"
        >
          <Loader2 class="w-5 h-5 animate-spin" />
        </div>
      </div>
    </template>
  </div>
</template>
