/**
 * 提醒调度器 API
 * @module api/reminderScheduler
 */

import { invoke } from '@tauri-apps/api/core';

/**
 * 调度器状态
 */
export interface SchedulerState {
  /** 是否运行中 */
  isRunning: boolean;
  /** 上次扫描时间 */
  lastScanAt?: string;
  /** 待处理任务数 */
  pendingTasks: number;
  /** 今日已执行 */
  executedToday: number;
  /** 今日失败数 */
  failedToday: number;
}

/**
 * 提醒调度器 API
 */
export const reminderSchedulerApi = {
  /**
   * 获取调度器状态
   */
  async getState(): Promise<SchedulerState> {
    try {
      return await invoke<SchedulerState>('reminder_scheduler_get_state');
    } catch (error) {
      console.error('获取调度器状态失败:', error);
      throw error;
    }
  },

  /**
   * 启动调度器
   */
  async start(): Promise<string> {
    try {
      return await invoke<string>('reminder_scheduler_start');
    } catch (error) {
      console.error('启动调度器失败:', error);
      throw error;
    }
  },

  /**
   * 停止调度器
   */
  async stop(): Promise<string> {
    try {
      return await invoke<string>('reminder_scheduler_stop');
    } catch (error) {
      console.error('停止调度器失败:', error);
      throw error;
    }
  },

  /**
   * 立即扫描一次（手动触发）
   * @returns 扫描到的任务数量
   */
  async scanNow(): Promise<number> {
    try {
      return await invoke<number>('reminder_scheduler_scan_now');
    } catch (error) {
      console.error('扫描提醒失败:', error);
      throw error;
    }
  },

  /**
   * 发送测试通知
   */
  async testNotification(title: string, body: string): Promise<string> {
    try {
      return await invoke<string>('reminder_scheduler_test_notification', {
        title,
        body,
      });
    } catch (error) {
      console.error('发送测试通知失败:', error);
      throw error;
    }
  },
};

/**
 * 使用调度器状态的 Composable
 */
export function useSchedulerState() {
  const state = ref<SchedulerState | null>(null);
  const loading = ref(false);
  const error = ref<string | null>(null);

  /**
   * 加载状态
   */
  async function loadState() {
    loading.value = true;
    error.value = null;

    try {
      state.value = await reminderSchedulerApi.getState();
    } catch (err) {
      error.value = err instanceof Error ? err.message : '加载状态失败';
      console.error('加载调度器状态失败:', err);
    } finally {
      loading.value = false;
    }
  }

  /**
   * 切换调度器状态
   */
  async function toggle() {
    if (!state.value) {
      await loadState();
      return;
    }

    loading.value = true;
    error.value = null;

    try {
      if (state.value.isRunning) {
        await reminderSchedulerApi.stop();
      } else {
        await reminderSchedulerApi.start();
      }
      await loadState();
    } catch (err) {
      error.value = err instanceof Error ? err.message : '操作失败';
      console.error('切换调度器状态失败:', err);
    } finally {
      loading.value = false;
    }
  }

  /**
   * 手动扫描
   */
  async function scan() {
    loading.value = true;
    error.value = null;

    try {
      const count = await reminderSchedulerApi.scanNow();
      await loadState();
      return count;
    } catch (err) {
      error.value = err instanceof Error ? err.message : '扫描失败';
      console.error('扫描提醒失败:', err);
      throw err;
    } finally {
      loading.value = false;
    }
  }

  /**
   * 发送测试通知
   */
  async function test(title = '测试通知', body = '这是一条测试通知消息') {
    loading.value = true;
    error.value = null;

    try {
      const result = await reminderSchedulerApi.testNotification(title, body);
      return result;
    } catch (err) {
      error.value = err instanceof Error ? err.message : '测试失败';
      console.error('发送测试通知失败:', err);
      throw err;
    } finally {
      loading.value = false;
    }
  }

  // 自动加载
  onMounted(() => {
    loadState();
  });

  return {
    state,
    loading,
    error,
    loadState,
    toggle,
    scan,
    test,
  };
}
