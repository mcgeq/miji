/**
 * 调度器配置相关 API
 * @module api/scheduler
 */

import { invoke } from '@tauri-apps/api/core';
import type {
  SchedulerConfig,
  SchedulerConfigCreateRequest,
  SchedulerConfigUpdateRequest,
  SchedulerTaskType,
} from '@/types/scheduler';

/**
 * 调度器配置 API
 */
export const schedulerApi = {
  /**
   * 获取单个调度器配置
   * @param taskType 任务类型
   * @param userId 用户ID（可选）
   * @returns 配置信息
   */
  async getConfig(taskType: SchedulerTaskType, userId?: string): Promise<SchedulerConfig> {
    try {
      return await invoke<SchedulerConfig>('scheduler_config_get', {
        taskType,
        userId,
      });
    } catch (error) {
      console.error('获取调度器配置失败:', error);
      throw error;
    }
  },

  /**
   * 获取所有调度器配置列表
   * @param userId 用户ID（可选）
   * @returns 配置列表
   */
  async list(userId?: string): Promise<SchedulerConfig[]> {
    try {
      return await invoke<SchedulerConfig[]>('scheduler_config_list', {
        userId,
      });
    } catch (error) {
      console.error('获取调度器配置列表失败:', error);
      throw error;
    }
  },

  /**
   * 更新调度器配置
   * @param request 更新请求
   * @returns 更新后的配置
   */
  async update(request: SchedulerConfigUpdateRequest): Promise<SchedulerConfig> {
    try {
      return await invoke<SchedulerConfig>('scheduler_config_update', {
        request,
      });
    } catch (error) {
      console.error('更新调度器配置失败:', error);
      throw error;
    }
  },

  /**
   * 创建调度器配置
   * @param request 创建请求
   * @returns 创建的配置
   */
  async create(request: SchedulerConfigCreateRequest): Promise<SchedulerConfig> {
    try {
      return await invoke<SchedulerConfig>('scheduler_config_create', {
        request,
      });
    } catch (error) {
      console.error('创建调度器配置失败:', error);
      throw error;
    }
  },

  /**
   * 删除调度器配置
   * @param serialNum 配置ID
   */
  async delete(serialNum: string): Promise<void> {
    try {
      await invoke('scheduler_config_delete', { serialNum });
    } catch (error) {
      console.error('删除调度器配置失败:', error);
      throw error;
    }
  },

  /**
   * 重置调度器配置到默认值
   * @param taskType 任务类型
   * @param userId 用户ID（可选）
   */
  async reset(taskType: SchedulerTaskType, userId?: string): Promise<void> {
    try {
      await invoke('scheduler_config_reset', {
        taskType,
        userId,
      });
    } catch (error) {
      console.error('重置调度器配置失败:', error);
      throw error;
    }
  },

  /**
   * 清除配置缓存
   */
  async clearCache(): Promise<void> {
    try {
      await invoke('scheduler_config_clear_cache');
    } catch (error) {
      console.error('清除配置缓存失败:', error);
      throw error;
    }
  },
};
