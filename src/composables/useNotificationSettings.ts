/**
 * 通知设置 Composable
 * 自动集成认证和通知 API
 */

import { computed, onMounted, ref } from 'vue';
import { useAuthStore } from '@/stores/auth';
import { useNotificationStore } from '@/stores/notification';
import type { NotificationSettingsForm } from '@/types/notification';
import { toast } from '@/utils/toast';

export function useNotificationSettings() {
  const authStore = useAuthStore();
  const notificationStore = useNotificationStore();

  const isLoading = ref(false);
  const error = ref<string | null>(null);

  /**
   * 获取当前用户 ID
   */
  const currentUserId = computed(() => {
    return authStore.user?.serialNum || '';
  });

  /**
   * 是否已登录
   */
  const isAuthenticated = computed(() => {
    return authStore.isAuthenticated;
  });

  /**
   * 加载通知设置
   */
  async function loadSettings() {
    if (!currentUserId.value) {
      error.value = '用户未登录';
      return;
    }

    isLoading.value = true;
    error.value = null;

    try {
      await notificationStore.loadSettings(currentUserId.value);
    } catch (err) {
      error.value = err instanceof Error ? err.message : '加载通知设置失败';
      toast.error(error.value);
    } finally {
      isLoading.value = false;
    }
  }

  /**
   * 更新通知设置
   */
  async function updateSettings(settings: NotificationSettingsForm[]) {
    if (!currentUserId.value) {
      toast.error('用户未登录');
      return;
    }

    isLoading.value = true;
    error.value = null;

    try {
      await notificationStore.updateSettings(currentUserId.value, settings);
      toast.success('通知设置已更新');
    } catch (err) {
      error.value = err instanceof Error ? err.message : '更新通知设置失败';
      toast.error(error.value);
      throw err;
    } finally {
      isLoading.value = false;
    }
  }

  /**
   * 更新单个通知类型的设置
   */
  async function updateNotificationType(
    notificationType: string,
    enabled: boolean,
    quietHoursStart?: string,
    quietHoursEnd?: string,
    quietDays?: string[],
    soundEnabled?: boolean,
    vibrationEnabled?: boolean,
  ) {
    const settings: NotificationSettingsForm = {
      notificationType,
      enabled,
      quietHoursStart,
      quietHoursEnd,
      quietDays,
      soundEnabled,
      vibrationEnabled,
    };

    return updateSettings([settings]);
  }

  /**
   * 重置通知设置
   */
  async function resetSettings() {
    if (!currentUserId.value) {
      toast.error('用户未登录');
      return;
    }

    isLoading.value = true;
    error.value = null;

    try {
      await notificationStore.resetSettings(currentUserId.value);
      toast.success('通知设置已重置');
      // 重新加载设置
      await loadSettings();
    } catch (err) {
      error.value = err instanceof Error ? err.message : '重置通知设置失败';
      toast.error(error.value);
      throw err;
    } finally {
      isLoading.value = false;
    }
  }

  /**
   * 加载通知日志
   */
  async function loadLogs(params?: {
    page?: number;
    size?: number;
    type?: string;
    status?: 'Pending' | 'Sent' | 'Failed';
  }) {
    isLoading.value = true;
    error.value = null;

    try {
      await notificationStore.loadLogs(params);
    } catch (err) {
      error.value = err instanceof Error ? err.message : '加载通知日志失败';
      toast.error(error.value);
    } finally {
      isLoading.value = false;
    }
  }

  /**
   * 加载通知统计
   */
  async function loadStatistics(period: '7d' | '30d' | '90d' = '30d') {
    isLoading.value = true;
    error.value = null;

    try {
      await notificationStore.loadStatistics(period);
    } catch (err) {
      error.value = err instanceof Error ? err.message : '加载通知统计失败';
      toast.error(error.value);
    } finally {
      isLoading.value = false;
    }
  }

  /**
   * 删除通知日志
   */
  async function deleteLog(id: string) {
    isLoading.value = true;
    error.value = null;

    try {
      await notificationStore.deleteLog(id);
      toast.success('日志已删除');
    } catch (err) {
      error.value = err instanceof Error ? err.message : '删除日志失败';
      toast.error(error.value);
      throw err;
    } finally {
      isLoading.value = false;
    }
  }

  /**
   * 批量删除通知日志
   */
  async function batchDeleteLogs(ids: string[]) {
    isLoading.value = true;
    error.value = null;

    try {
      await notificationStore.batchDeleteLogs(ids);
      toast.success(`已删除 ${ids.length} 条日志`);
    } catch (err) {
      error.value = err instanceof Error ? err.message : '批量删除日志失败';
      toast.error(error.value);
      throw err;
    } finally {
      isLoading.value = false;
    }
  }

  // 自动加载设置
  onMounted(() => {
    if (isAuthenticated.value) {
      loadSettings();
    }
  });

  return {
    // 状态
    isLoading,
    error,
    currentUserId,
    isAuthenticated,

    // Store 数据
    settings: computed(() => notificationStore.settings),
    logs: computed(() => notificationStore.logs),
    statistics: computed(() => notificationStore.statistics),
    settingsMap: computed(() => notificationStore.settingsMap),
    enabledTypes: computed(() => notificationStore.enabledTypes),

    // 方法
    loadSettings,
    updateSettings,
    updateNotificationType,
    resetSettings,
    loadLogs,
    loadStatistics,
    deleteLog,
    batchDeleteLogs,
  };
}
