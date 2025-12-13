// src/stores/money/reminder-store.ts
import { defineStore } from 'pinia';
import { AppError } from '@/errors/appError';
import type { PageQuery } from '@/schema/common';
import type { BilReminder, BilReminderCreate, BilReminderUpdate } from '@/schema/money';
import type { PagedResult } from '@/services/base/types';
import type { BilReminderFilters } from '@/services/money/billReminder';
import { billReminderService } from '@/services/money/billReminderService';
import { toast } from '@/utils/toast';

// ==================== Store Constants ====================

/** ReminderStore 错误代码 */
export enum ReminderStoreErrorCode {
  FETCH_FAILED = 'FETCH_FAILED',
  CREATE_FAILED = 'CREATE_FAILED',
  UPDATE_FAILED = 'UPDATE_FAILED',
  DELETE_FAILED = 'DELETE_FAILED',
  TOGGLE_FAILED = 'TOGGLE_FAILED',
  NOT_FOUND = 'NOT_FOUND',
}

interface ReminderStoreState {
  reminders: BilReminder[];
  remindersPaged: PagedResult<BilReminder>;
  loading: boolean;
  error: AppError | null;
  /** 上次查询的筛选条件（用于优化刷新） */
  lastQuery: PageQuery<BilReminderFilters> | null;
  /** 当前请求控制器（用于取消请求） */
  currentAbortController: AbortController | null;
}

/**
 * 账单提醒管理 Store
 */
export const useReminderStore = defineStore('money-reminders', {
  state: (): ReminderStoreState => ({
    reminders: [],
    remindersPaged: {
      items: [],
      total: 0,
      page: 1,
      pageSize: 10,
      totalPages: 0,
    },
    loading: false,
    error: null,
    lastQuery: null,
    currentAbortController: null,
  }),

  getters: {
    /**
     * 根据ID获取提醒
     */
    getReminderById: state => (id: string) => {
      return state.reminders.find(r => r.serialNum === id);
    },

    /**
     * 获取活跃的提醒
     */
    activeReminders: state => state.reminders.filter(r => r.enabled),

    /**
     * 获取即将到期的提醒（未来7天内）
     */
    upcomingReminders: state => {
      const now = new Date();
      const sevenDaysLater = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000);

      return state.reminders.filter(r => {
        if (!(r.enabled && r.remindDate)) return false;
        const nextDate = new Date(r.remindDate);
        return nextDate >= now && nextDate <= sevenDaysLater;
      });
    },
  },

  actions: {
    /**
     * 带加载状态和错误处理的操作包装器
     */
    async withLoadingSafe<T>(
      operation: () => Promise<T>,
      errorCode: ReminderStoreErrorCode,
      errorMsg: string,
      showToast = true,
    ): Promise<T> {
      this.loading = true;
      this.error = null;
      try {
        return await operation();
      } catch (error: unknown) {
        const appError = AppError.wrap('ReminderStore', error, errorCode, errorMsg);
        this.error = appError;
        if (showToast) {
          toast.error(errorMsg);
        }
        throw appError;
      } finally {
        this.loading = false;
      }
    },

    /**
     * 取消当前请求（防止竞态条件）
     */
    cancelCurrentRequest() {
      if (this.currentAbortController) {
        this.currentAbortController.abort();
        this.currentAbortController = null;
      }
    },

    /**
     * 获取提醒列表（分页）
     * 支持请求取消，防止竞态条件
     */
    async fetchRemindersPaged(query: PageQuery<BilReminderFilters>) {
      // 取消上一个未完成的请求
      this.cancelCurrentRequest();

      // 创建新的 AbortController
      const abortController = new AbortController();
      this.currentAbortController = abortController;

      return this.withLoadingSafe(
        async () => {
          const result = await billReminderService.listPagedWithFilters(query);

          // 检查请求是否已被取消
          if (abortController.signal.aborted) {
            return;
          }

          this.remindersPaged = result;
          // 保存查询条件用于优化刷新
          this.lastQuery = query;

          // 清理当前控制器
          if (this.currentAbortController === abortController) {
            this.currentAbortController = null;
          }
        },
        ReminderStoreErrorCode.FETCH_FAILED,
        '获取提醒列表失败',
      );
    },

    /**
     * 刷新当前分页数据（使用上次的查询条件）
     */
    async refreshCurrentPage() {
      if (this.lastQuery) {
        await this.fetchRemindersPaged(this.lastQuery);
      }
    },

    /**
     * 获取提醒列表（全部）
     */
    async fetchReminders() {
      return this.withLoadingSafe(
        async () => {
          this.reminders = await billReminderService.list();
        },
        ReminderStoreErrorCode.FETCH_FAILED,
        '获取提醒列表失败',
      );
    },

    /**
     * 创建提醒
     */
    async createReminder(data: BilReminderCreate): Promise<BilReminder> {
      return this.withLoadingSafe(
        async () => {
          const reminder = await billReminderService.create(data);
          this.reminders.unshift(reminder);

          // 如果有分页数据，刷新当前页（异步，不阻塞）
          if (this.lastQuery) {
            this.refreshCurrentPage().catch(err => {
              console.warn('刷新分页数据失败', err);
            });
          }

          return reminder;
        },
        ReminderStoreErrorCode.CREATE_FAILED,
        '创建提醒失败',
      );
    },

    /**
     * 更新提醒
     */
    async updateReminder(serialNum: string, data: BilReminderUpdate): Promise<BilReminder> {
      return this.withLoadingSafe(
        async () => {
          const reminder = await billReminderService.update(serialNum, data);
          const index = this.reminders.findIndex(r => r.serialNum === serialNum);
          if (index !== -1) {
            this.reminders[index] = reminder;
          }
          return reminder;
        },
        ReminderStoreErrorCode.UPDATE_FAILED,
        '更新提醒失败',
      );
    },

    /**
     * 删除提醒
     */
    async deleteReminder(serialNum: string): Promise<void> {
      return this.withLoadingSafe(
        async () => {
          await billReminderService.delete(serialNum);
          this.reminders = this.reminders.filter(r => r.serialNum !== serialNum);

          // 刷新分页数据
          if (this.lastQuery) {
            this.refreshCurrentPage().catch(err => {
              console.warn('刷新分页数据失败', err);
            });
          }
        },
        ReminderStoreErrorCode.DELETE_FAILED,
        '删除提醒失败',
      );
    },

    /**
     * 切换提醒激活状态
     */
    async toggleReminderActive(serialNum: string): Promise<void> {
      const reminder = this.getReminderById(serialNum);
      if (!reminder) {
        const error = AppError.wrap(
          'ReminderStore',
          new Error('提醒不存在'),
          ReminderStoreErrorCode.NOT_FOUND,
          '提醒不存在',
        );
        this.error = error;
        throw error;
      }

      return this.withLoadingSafe(
        async () => {
          const updatedReminder = await billReminderService.updateActive(
            serialNum,
            !reminder.enabled,
          );

          // 更新 reminders 数组
          const index = this.reminders.findIndex(r => r.serialNum === serialNum);
          if (index !== -1) {
            this.reminders[index] = updatedReminder;
          }

          // 重新获取列表
          await this.fetchRemindersPaged({
            currentPage: this.remindersPaged.page,
            pageSize: this.remindersPaged.pageSize,
            sortOptions: {
              desc: true,
            },
            filter: {},
          });
        },
        ReminderStoreErrorCode.TOGGLE_FAILED,
        '更新提醒状态失败',
      );
    },

    /**
     * 清除错误
     */
    clearError() {
      this.error = null;
    },

    /**
     * 重置整个 store 状态
     */
    $reset() {
      // 取消未完成的请求
      this.cancelCurrentRequest();

      this.reminders = [];
      this.remindersPaged = {
        items: [],
        total: 0,
        page: 1,
        pageSize: 10,
        totalPages: 0,
      };
      this.loading = false;
      this.error = null;
      this.lastQuery = null;
      this.currentAbortController = null;
    },
  },
});
