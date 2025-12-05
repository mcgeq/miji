/**
 * 通知相关 API
 * @module api/notification
 */

import { invoke } from '@tauri-apps/api/core';
import type {
  NotificationSettings,
  NotificationLog,
  NotificationStatistics,
  NotificationSettingsForm,
} from '@/types/notification';

/**
 * 通知设置 API
 */
export const notificationSettingsApi = {
  /**
   * 获取所有通知设置
   */
  async getAll(): Promise<NotificationSettings[]> {
    try {
      return await invoke<NotificationSettings[]>('notification_settings_get_all');
    } catch (error) {
      console.error('获取通知设置失败:', error);
      throw error;
    }
  },

  /**
   * 更新通知设置
   */
  async update(settings: NotificationSettingsForm): Promise<void> {
    try {
      await invoke('notification_settings_update', { settings });
    } catch (error) {
      console.error('更新通知设置失败:', error);
      throw error;
    }
  },

  /**
   * 批量更新通知设置
   */
  async batchUpdate(settingsList: NotificationSettings[]): Promise<void> {
    try {
      await invoke('notification_settings_batch_update', { settingsList });
    } catch (error) {
      console.error('批量更新通知设置失败:', error);
      throw error;
    }
  },

  /**
   * 重置通知设置为默认值
   */
  async reset(): Promise<void> {
    try {
      await invoke('notification_settings_reset');
    } catch (error) {
      console.error('重置通知设置失败:', error);
      throw error;
    }
  },
};

/**
 * 通知日志 API
 */
export const notificationLogsApi = {
  /**
   * 获取通知日志列表
   */
  async list(params: {
    page?: number;
    size?: number;
    type?: string;
    status?: 'Pending' | 'Sent' | 'Failed';
    startDate?: string;
    endDate?: string;
  }): Promise<{
    logs: NotificationLog[];
    total: number;
    page: number;
    size: number;
  }> {
    try {
      return await invoke('notification_logs_list', { params });
    } catch (error) {
      console.error('获取通知日志列表失败:', error);
      throw error;
    }
  },

  /**
   * 获取通知日志详情
   */
  async get(id: string): Promise<NotificationLog> {
    try {
      return await invoke<NotificationLog>('notification_log_get', { id });
    } catch (error) {
      console.error('获取通知日志详情失败:', error);
      throw error;
    }
  },

  /**
   * 重试失败的通知
   */
  async retry(id: string): Promise<void> {
    try {
      await invoke('notification_log_retry', { id });
    } catch (error) {
      console.error('重试通知失败:', error);
      throw error;
    }
  },

  /**
   * 删除通知日志
   */
  async delete(id: string): Promise<void> {
    try {
      await invoke('notification_log_delete', { id });
    } catch (error) {
      console.error('删除通知日志失败:', error);
      throw error;
    }
  },

  /**
   * 批量删除通知日志
   */
  async batchDelete(ids: string[]): Promise<void> {
    try {
      await invoke('notification_logs_batch_delete', { ids });
    } catch (error) {
      console.error('批量删除通知日志失败:', error);
      throw error;
    }
  },
};

/**
 * 通知统计 API
 */
export const notificationStatisticsApi = {
  /**
   * 获取通知统计信息
   */
  async get(period: '7d' | '30d' | '90d' = '7d'): Promise<NotificationStatistics> {
    try {
      return await invoke<NotificationStatistics>('notification_statistics_get', {
        period,
      });
    } catch (error) {
      console.error('获取通知统计信息失败:', error);
      throw error;
    }
  },
};

/**
 * 通知权限 API (已在 useNotificationPermission 中实现)
 */
export const notificationPermissionApi = {
  /**
   * 检查通知权限
   */
  async check(): Promise<boolean> {
    try {
      return await invoke<boolean>('check_notification_permission');
    } catch (error) {
      console.error('检查通知权限失败:', error);
      return false;
    }
  },

  /**
   * 请求通知权限
   */
  async request(): Promise<boolean> {
    try {
      return await invoke<boolean>('request_notification_permission');
    } catch (error) {
      console.error('请求通知权限失败:', error);
      return false;
    }
  },

  /**
   * 打开系统通知设置
   */
  async openSettings(): Promise<void> {
    try {
      await invoke('open_notification_settings');
    } catch (error) {
      console.error('打开系统通知设置失败:', error);
      throw error;
    }
  },
};
