<template>
  <div class="notification-settings">
    <!-- 页面标题 -->
    <div class="settings-header">
      <div class="flex items-center justify-between">
        <div>
          <h2 class="text-2xl font-bold">通知设置</h2>
          <p class="text-sm text-gray-500 mt-2">
            管理应用的通知权限和偏好设置
          </p>
        </div>
        <Button variant="outline" @click="$router.push('/notification-dashboard')">
          <component :is="BarChart3" class="w-4 h-4 mr-2" />
          查看统计
        </Button>
      </div>
    </div>

    <!-- 权限状态卡片 -->
    <Card class="permission-card mt-6">
      <template #header>
        <div class="flex items-center justify-between">
          <div class="flex items-center space-x-2">
            <component :is="Bell" class="w-5 h-5" />
            <h3 class="font-semibold">通知权限</h3>
          </div>
          <Badge :color="statusColor">{{ statusText }}</Badge>
        </div>
      </template>

      <div class="space-y-4">
        <!-- 权限说明 -->
        <p class="text-sm text-gray-600">
          {{
            hasPermission
              ? '通知权限已授予，您将收到及时的提醒通知'
              : '需要通知权限才能及时提醒您的待办、账单和健康事项'
          }}
        </p>

        <!-- 错误提示 -->
        <Alert v-if="error" type="error" @close="clearError">
          {{ error }}
        </Alert>

        <!-- 权限操作按钮 -->
        <div class="flex space-x-3">
          <Button
            v-if="!hasPermission"
            @click="handleRequestPermission"
            :loading="isProcessing"
            variant="primary"
          >
            <component :is="Unlock" class="w-4 h-4 mr-2" />
            授予权限
          </Button>

          <Button
            @click="handleOpenSettings"
            :loading="isProcessing"
            variant="outline"
          >
            <component :is="Settings" class="w-4 h-4 mr-2" />
            系统设置
          </Button>

          <Button
            @click="checkPermission"
            :loading="checking"
            variant="ghost"
          >
            <component :is="RefreshCw" class="w-4 h-4 mr-2" />
            刷新状态
          </Button>
        </div>
      </div>
    </Card>

    <!-- 通知类型设置 -->
    <Card class="notification-types-card mt-6">
      <template #header>
        <h3 class="font-semibold">通知类型</h3>
      </template>

      <div class="space-y-4">
        <!-- 通知类型列表 -->
        <div
          v-for="type in notificationTypes"
          :key="type.value"
          class="notification-type-item"
        >
          <div class="flex items-start justify-between">
            <div class="flex items-start space-x-3 flex-1">
              <component
                :is="type.icon"
                class="w-5 h-5 mt-0.5 text-gray-500"
              />
              <div class="flex-1">
                <div class="flex items-center space-x-2">
                  <span class="font-medium">{{ type.label }}</span>
                  <Badge v-if="!hasPermission" color="gray" size="sm">
                    需要权限
                  </Badge>
                </div>
                <p class="text-sm text-gray-500 mt-1">
                  {{ type.description }}
                </p>
              </div>
            </div>
            <Switch
              :model-value="settings[type.key] as boolean"
              @update:model-value="(val) => { (settings as any)[type.key] = val; handleSettingChange(); }"
              :disabled="!hasPermission || loading"
            />
          </div>
        </div>
      </div>
    </Card>

    <!-- 免打扰设置 -->
    <Card class="dnd-settings-card mt-6">
      <template #header>
        <div class="flex items-center space-x-2">
          <component :is="Moon" class="w-5 h-5" />
          <h3 class="font-semibold">免打扰设置</h3>
        </div>
      </template>

      <div class="space-y-6">
        <!-- 免打扰时段 -->
        <div class="dnd-hours">
          <label class="block text-sm font-medium mb-3">
            免打扰时段
          </label>
          <div class="flex items-center space-x-4">
            <div class="flex-1">
              <label class="text-xs text-gray-500 mb-1 block">开始时间</label>
              <input
                v-model="settings.quietHoursStart"
                type="time"
                class="input-time w-full"
                :disabled="!hasPermission || loading"
                @change="handleSettingChange"
              />
            </div>
            <span class="text-gray-400 mt-6">-</span>
            <div class="flex-1">
              <label class="text-xs text-gray-500 mb-1 block">结束时间</label>
              <input
                v-model="settings.quietHoursEnd"
                type="time"
                class="input-time w-full"
                :disabled="!hasPermission || loading"
                @change="handleSettingChange"
              />
            </div>
          </div>
          <p class="text-xs text-gray-500 mt-2">
            在此时间段内将不会收到通知（紧急通知除外）
          </p>
        </div>

        <!-- 免打扰日期 -->
        <div class="dnd-days">
          <label class="block text-sm font-medium mb-3">
            免打扰日期
          </label>
          <div class="flex flex-wrap gap-2">
            <Button
              v-for="day in weekDays"
              :key="day.value"
              :variant="isDaySelected(day.value) ? 'primary' : 'outline'"
              size="sm"
              @click="toggleDay(day.value)"
              :disabled="!hasPermission || loading"
            >
              {{ day.label }}
            </Button>
          </div>
          <p class="text-xs text-gray-500 mt-2">
            选中的日期将不会收到通知（紧急通知除外）
          </p>
        </div>
      </div>
    </Card>

    <!-- 操作按钮 -->
    <div class="actions mt-6 flex justify-end space-x-3">
      <Button @click="handleReset" variant="outline" :disabled="loading">
        重置
      </Button>
      <Button
        @click="handleSave"
        variant="primary"
        :loading="loading"
        :disabled="!hasPermission"
      >
        保存设置
      </Button>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue';
import { useNotificationPermission } from '@/composables/useNotificationPermission';
import {
  NotificationType,
  NotificationTypeLabel,
  NotificationTypeDescription,
  type NotificationSettingsForm,
} from '@/types/notification';
import Card from '@/components/ui/Card.vue';
import Button from '@/components/ui/Button.vue';
import Switch from '@/components/ui/Switch.vue';
import Badge from '@/components/ui/Badge.vue';
import Alert from '@/components/ui/Alert.vue';
import {
  Bell,
  Unlock,
  Settings,
  RefreshCw,
  Moon,
  CheckSquare,
  CreditCard,
  Calendar,
  Heart,
  Activity,
  AlertCircle,
  BarChart3,
} from 'lucide-vue-next';

// ==================== Composables ====================

const {
  hasPermission,
  statusText,
  statusColor,
  checking,
  error,
  isProcessing,
  checkPermission,
  requestPermission,
  openSettings,
  clearError,
} = useNotificationPermission();

// ==================== 状态 ====================

const loading = ref(false);

const settings = reactive<NotificationSettingsForm>({
  todoReminder: true,
  billReminder: true,
  periodReminder: true,
  ovulationReminder: true,
  pmsReminder: true,
  systemAlert: true,
  quietHoursStart: undefined,
  quietHoursEnd: undefined,
  quietDays: [],
});

// ==================== 数据 ====================

const notificationTypes = [
  {
    value: NotificationType.TODO_REMINDER,
    key: 'todoReminder' as keyof NotificationSettingsForm,
    label: NotificationTypeLabel[NotificationType.TODO_REMINDER],
    description: NotificationTypeDescription[NotificationType.TODO_REMINDER],
    icon: CheckSquare,
  },
  {
    value: NotificationType.BILL_REMINDER,
    key: 'billReminder' as keyof NotificationSettingsForm,
    label: NotificationTypeLabel[NotificationType.BILL_REMINDER],
    description: NotificationTypeDescription[NotificationType.BILL_REMINDER],
    icon: CreditCard,
  },
  {
    value: NotificationType.PERIOD_REMINDER,
    key: 'periodReminder' as keyof NotificationSettingsForm,
    label: NotificationTypeLabel[NotificationType.PERIOD_REMINDER],
    description: NotificationTypeDescription[NotificationType.PERIOD_REMINDER],
    icon: Calendar,
  },
  {
    value: NotificationType.OVULATION_REMINDER,
    key: 'ovulationReminder' as keyof NotificationSettingsForm,
    label: NotificationTypeLabel[NotificationType.OVULATION_REMINDER],
    description:
      NotificationTypeDescription[NotificationType.OVULATION_REMINDER],
    icon: Heart,
  },
  {
    value: NotificationType.PMS_REMINDER,
    key: 'pmsReminder' as keyof NotificationSettingsForm,
    label: NotificationTypeLabel[NotificationType.PMS_REMINDER],
    description: NotificationTypeDescription[NotificationType.PMS_REMINDER],
    icon: Activity,
  },
  {
    value: NotificationType.SYSTEM_ALERT,
    key: 'systemAlert' as keyof NotificationSettingsForm,
    label: NotificationTypeLabel[NotificationType.SYSTEM_ALERT],
    description: NotificationTypeDescription[NotificationType.SYSTEM_ALERT],
    icon: AlertCircle,
  },
];

const weekDays = [
  { value: 1, label: '周一' },
  { value: 2, label: '周二' },
  { value: 3, label: '周三' },
  { value: 4, label: '周四' },
  { value: 5, label: '周五' },
  { value: 6, label: '周六' },
  { value: 7, label: '周日' },
];

// ==================== 方法 ====================

/**
 * 请求通知权限
 */
async function handleRequestPermission() {
  const granted = await requestPermission();
  if (granted) {
    // TODO: 显示成功提示
    console.log('✅ 权限授予成功');
  }
}

/**
 * 打开系统设置
 */
async function handleOpenSettings() {
  await openSettings();
}

/**
 * 设置改变处理
 */
function handleSettingChange() {
  // 自动保存或标记为已修改
  console.log('设置已修改:', settings);
}

/**
 * 判断日期是否选中
 */
function isDaySelected(day: number): boolean {
  return settings.quietDays?.includes(day) ?? false;
}

/**
 * 切换日期选择
 */
function toggleDay(day: number) {
  if (!settings.quietDays) {
    settings.quietDays = [];
  }

  const index = settings.quietDays.indexOf(day);
  if (index > -1) {
    settings.quietDays.splice(index, 1);
  } else {
    settings.quietDays.push(day);
  }

  handleSettingChange();
}

/**
 * 保存设置
 */
async function handleSave() {
  loading.value = true;

  try {
    // TODO: 调用后端 API 保存设置
    console.log('保存设置:', settings);

    // 模拟延迟
    await new Promise((resolve) => setTimeout(resolve, 500));

    // TODO: 显示成功提示
    console.log('✅ 设置保存成功');
  } catch (err) {
    console.error('❌ 保存设置失败:', err);
    // TODO: 显示错误提示
  } finally {
    loading.value = false;
  }
}

/**
 * 重置设置
 */
function handleReset() {
  // 恢复默认设置
  settings.todoReminder = true;
  settings.billReminder = true;
  settings.periodReminder = true;
  settings.ovulationReminder = true;
  settings.pmsReminder = true;
  settings.systemAlert = true;
  settings.quietHoursStart = undefined;
  settings.quietHoursEnd = undefined;
  settings.quietDays = [];

  console.log('✅ 设置已重置');
}

/**
 * 加载设置
 */
async function loadSettings() {
  loading.value = true;

  try {
    // TODO: 从后端 API 加载设置
    console.log('加载设置...');

    // 模拟延迟
    await new Promise((resolve) => setTimeout(resolve, 500));

    // TODO: 更新 settings
  } catch (err) {
    console.error('❌ 加载设置失败:', err);
  } finally {
    loading.value = false;
  }
}

// ==================== 生命周期 ====================

onMounted(async () => {
  await loadSettings();
});
</script>

<style scoped>
.notification-settings {
  max-width: 800px;
  margin: 0 auto;
  padding: 24px;
}

.settings-header {
  margin-bottom: 24px;
}

.permission-card,
.notification-types-card,
.dnd-settings-card {
  background: white;
  border-radius: 8px;
  padding: 20px;
  box-shadow: 0 1px 3px rgba(0, 0, 0, 0.1);
}

.notification-type-item {
  padding: 16px 0;
  border-bottom: 1px solid #f0f0f0;
}

.notification-type-item:last-child {
  border-bottom: none;
}

.input-time {
  padding: 8px 12px;
  border: 1px solid #d9d9d9;
  border-radius: 4px;
  font-size: 14px;
}

.input-time:hover {
  border-color: #4096ff;
}

.input-time:focus {
  outline: none;
  border-color: #4096ff;
  box-shadow: 0 0 0 2px rgba(64, 150, 255, 0.1);
}

.input-time:disabled {
  background-color: #f5f5f5;
  cursor: not-allowed;
}

.actions {
  padding-top: 16px;
  border-top: 1px solid #f0f0f0;
}
</style>
