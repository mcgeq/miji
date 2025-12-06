/**
 * 通知状态管理
 * @module stores/notification
 */

import { defineStore } from 'pinia';
import { computed, ref } from 'vue';
import {
  notificationLogsApi,
  notificationSettingsApi,
  notificationStatisticsApi,
} from '@/api/notification';
import type {
  NotificationLog,
  NotificationSettings,
  NotificationSettingsForm,
  NotificationStatistics,
  NotificationType,
} from '@/types/notification';

export const useNotificationStore = defineStore('notification', () => {
  // ==================== 状态 ====================

  /**
   * 通知设置列表
   */
  const settings = ref<NotificationSettings[]>([]);

  /**
   * 通知日志列表
   */
  const logs = ref<NotificationLog[]>([]);

  /**
   * 通知日志总数
   */
  const logsTotal = ref(0);

  /**
   * 通知统计信息
   */
  const statistics = ref<NotificationStatistics | null>(null);

  /**
   * 加载状态
   */
  const loading = ref(false);

  /**
   * 错误信息
   */
  const error = ref<string | null>(null);

  // ==================== 计算属性 ====================

  /**
   * 已启用的通知类型
   */
  const enabledTypes = computed(() => {
    return settings.value.filter(s => s.enabled).map(s => s.notificationType);
  });

  /**
   * 最近的通知日志 (前10条)
   */
  const recentLogs = computed(() => {
    return logs.value.slice(0, 10);
  });

  /**
   * 失败的通知数量
   */
  const failedCount = computed(() => {
    return logs.value.filter(log => log.status === 'Failed').length;
  });

  /**
   * 待发送的通知数量
   */
  const pendingCount = computed(() => {
    return logs.value.filter(log => log.status === 'Pending').length;
  });

  /**
   * 通知类型的设置映射
   */
  const settingsMap = computed(() => {
    const map = new Map<NotificationType, NotificationSettings>();
    settings.value.forEach(s => {
      map.set(s.notificationType, s);
    });
    return map;
  });

  // ==================== Actions ====================

  /**
   * 加载通知设置
   */
  async function loadSettings(userId: string) {
    loading.value = true;
    error.value = null;

    try {
      settings.value = await notificationSettingsApi.getAll(userId);
      console.log('✅ 通知设置加载成功', settings.value.length);
    } catch (err) {
      error.value = err instanceof Error ? err.message : '加载通知设置失败';
      console.error('❌ 加载通知设置失败:', err);
      throw err;
    } finally {
      loading.value = false;
    }
  }

  /**
   * 更新通知设置
   */
  async function updateSettings(userId: string, newSettings: NotificationSettingsForm[]) {
    loading.value = true;
    error.value = null;

    try {
      const updated = await notificationSettingsApi.batchUpdate(userId, newSettings);
      console.log('✅ 通知设置更新成功', updated.length);

      // 更新本地状态
      updated.forEach(updatedSetting => {
        const index = settings.value.findIndex(
          s => s.notificationType === updatedSetting.notificationType,
        );
        if (index !== -1) {
          settings.value[index] = updatedSetting;
        } else {
          settings.value.push(updatedSetting);
        }
      });
    } catch (err) {
      error.value = err instanceof Error ? err.message : '更新通知设置失败';
      console.error('❌ 更新通知设置失败:', err);
      throw err;
    } finally {
      loading.value = false;
    }
  }

  /**
   * 重置通知设置
   */
  async function resetSettings(userId: string) {
    loading.value = true;
    error.value = null;

    try {
      await notificationSettingsApi.reset(userId);
      await loadSettings(userId); // 重新加载
      console.log('✅ 通知设置重置成功');
    } catch (err) {
      error.value = err instanceof Error ? err.message : '重置通知设置失败';
      console.error('❌ 重置通知设置失败:', err);
      throw err;
    } finally {
      loading.value = false;
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
    startDate?: string;
    endDate?: string;
  }) {
    loading.value = true;
    error.value = null;

    try {
      const result = await notificationLogsApi.list(params || {});
      logs.value = result.logs;
      logsTotal.value = result.total;
      console.log('✅ 通知日志加载成功', result.total);
    } catch (err) {
      error.value = err instanceof Error ? err.message : '加载通知日志失败';
      console.error('❌ 加载通知日志失败:', err);
      throw err;
    } finally {
      loading.value = false;
    }
  }

  /**
   * 重试失败的通知
   */
  async function retryLog(id: string) {
    loading.value = true;
    error.value = null;

    try {
      await notificationLogsApi.retry(id);
      // 更新本地状态
      const log = logs.value.find(l => l.id === id);
      if (log) {
        log.status = 'Pending';
      }
      console.log('✅ 通知重试成功', id);

      // 刷新统计数据（后台异步）
      refreshStatistics();
    } catch (err) {
      error.value = err instanceof Error ? err.message : '重试通知失败';
      console.error('❌ 重试通知失败:', err);
      throw err;
    } finally {
      loading.value = false;
    }
  }

  /**
   * 删除通知日志
   */
  async function deleteLog(id: string) {
    loading.value = true;
    error.value = null;

    try {
      await notificationLogsApi.delete(id);
      // 从本地状态移除
      logs.value = logs.value.filter(l => l.id !== id);
      logsTotal.value -= 1;
      console.log('✅ 通知日志删除成功', id);

      // 刷新统计数据（后台异步）
      refreshStatistics();
    } catch (err) {
      error.value = err instanceof Error ? err.message : '删除通知日志失败';
      console.error('❌ 删除通知日志失败:', err);
      throw err;
    } finally {
      loading.value = false;
    }
  }

  /**
   * 批量删除通知日志
   */
  async function batchDeleteLogs(ids: string[]) {
    loading.value = true;
    error.value = null;

    try {
      await notificationLogsApi.batchDelete(ids);
      // 从本地状态移除
      logs.value = logs.value.filter(l => !ids.includes(l.id));
      logsTotal.value -= ids.length;
      console.log('✅ 通知日志批量删除成功', ids.length);

      // 刷新统计数据（后台异步）
      refreshStatistics();
    } catch (err) {
      error.value = err instanceof Error ? err.message : '批量删除通知日志失败';
      console.error('❌ 批量删除通知日志失败:', err);
      throw err;
    } finally {
      loading.value = false;
    }
  }

  /**
   * 后台刷新统计数据（不阻塞用户操作）
   */
  function refreshStatistics() {
    if (statistics.value) {
      // 只有在统计数据已经加载过的情况下才刷新
      notificationStatisticsApi
        .get('7d')
        .then(data => {
          statistics.value = data;
          console.log('✅ 统计数据已刷新');
        })
        .catch(err => {
          console.warn('⚠️ 统计数据刷新失败:', err);
          // 不抛出错误，避免影响用户操作
        });
    }
  }

  /**
   * 加载通知统计
   */
  async function loadStatistics(period: '7d' | '30d' | '90d' = '7d') {
    loading.value = true;
    error.value = null;

    try {
      statistics.value = await notificationStatisticsApi.get(period);
      console.log('✅ 通知统计加载成功');
    } catch (err) {
      error.value = err instanceof Error ? err.message : '加载通知统计失败';
      console.error('❌ 加载通知统计失败:', err);
      throw err;
    } finally {
      loading.value = false;
    }
  }

  /**
   * 获取指定类型的设置
   */
  function getSettingByType(type: NotificationType): NotificationSettings | undefined {
    return settingsMap.value.get(type);
  }

  /**
   * 检查指定类型是否启用
   */
  function isTypeEnabled(type: NotificationType): boolean {
    const setting = getSettingByType(type);
    return setting?.enabled ?? false;
  }

  /**
   * 清空错误
   */
  function clearError() {
    error.value = null;
  }

  // ==================== 返回 ====================

  return {
    // 状态
    settings,
    logs,
    logsTotal,
    statistics,
    loading,
    error,

    // 计算属性
    enabledTypes,
    recentLogs,
    failedCount,
    pendingCount,
    settingsMap,

    // Actions
    loadSettings,
    updateSettings,
    resetSettings,
    loadLogs,
    retryLog,
    deleteLog,
    batchDeleteLogs,
    loadStatistics,
    getSettingByType,
    isTypeEnabled,
    clearError,
  };
});
