// src/stores/money/reminder-store.ts
import { defineStore } from 'pinia';
import { MoneyDb } from '@/services/money/money';
import type { PageQuery } from '@/schema/common';
import type { BilReminder, BilReminderCreate, BilReminderUpdate } from '@/schema/money';
import type { PagedResult } from '@/services/money/baseManager';
import type { BilReminderFilters } from '@/services/money/billReminder';

interface ReminderStoreState {
  reminders: BilReminder[];
  remindersPaged: PagedResult<BilReminder>;
  loading: boolean;
  error: string | null;
}

/**
 * 账单提醒管理 Store
 */
export const useReminderStore = defineStore('money-reminders', {
  state: (): ReminderStoreState => ({
    reminders: [],
    remindersPaged: {
      rows: [],
      totalCount: 0,
      currentPage: 1,
      pageSize: 10,
      totalPages: 0,
    },
    loading: false,
    error: null,
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
        if (!r.enabled || !r.remindDate) return false;
        const nextDate = new Date(r.remindDate);
        return nextDate >= now && nextDate <= sevenDaysLater;
      });
    },
  },

  actions: {
    /**
     * 获取提醒列表（分页）
     */
    async fetchRemindersPaged(query: PageQuery<BilReminderFilters>) {
      this.loading = true;
      this.error = null;

      try {
        this.remindersPaged = await MoneyDb.listBilRemindersPaged(query);
      } catch (error: any) {
        this.error = error.message || '获取提醒列表失败';
        throw error;
      } finally {
        this.loading = false;
      }
    },

    /**
     * 获取提醒列表（全部）
     */
    async fetchReminders() {
      this.loading = true;
      this.error = null;

      try {
        this.reminders = await MoneyDb.listBilReminders();
      } catch (error: any) {
        this.error = error.message || '获取提醒列表失败';
        throw error;
      } finally {
        this.loading = false;
      }
    },

    /**
     * 创建提醒
     */
    async createReminder(data: BilReminderCreate): Promise<BilReminder> {
      this.loading = true;
      this.error = null;

      try {
        const reminder = await MoneyDb.createBilReminder(data);
        this.reminders.unshift(reminder);
        return reminder;
      } catch (error: any) {
        this.error = error.message || '创建提醒失败';
        throw error;
      } finally {
        this.loading = false;
      }
    },

    /**
     * 更新提醒
     */
    async updateReminder(serialNum: string, data: BilReminderUpdate): Promise<BilReminder> {
      this.loading = true;
      this.error = null;

      try {
        const reminder = await MoneyDb.updateBilReminder(serialNum, data);
        const index = this.reminders.findIndex(r => r.serialNum === serialNum);
        if (index !== -1) {
          this.reminders[index] = reminder;
        }
        return reminder;
      } catch (error: any) {
        this.error = error.message || '更新提醒失败';
        throw error;
      } finally {
        this.loading = false;
      }
    },

    /**
     * 删除提醒
     */
    async deleteReminder(serialNum: string): Promise<void> {
      this.loading = true;
      this.error = null;

      try {
        await MoneyDb.deleteBilReminder(serialNum);
        this.reminders = this.reminders.filter(r => r.serialNum !== serialNum);
      } catch (error: any) {
        this.error = error.message || '删除提醒失败';
        throw error;
      } finally {
        this.loading = false;
      }
    },

    /**
     * 切换提醒激活状态
     */
    async toggleReminderActive(serialNum: string): Promise<void> {
      const reminder = this.getReminderById(serialNum);
      if (!reminder) return;

      this.loading = true;
      this.error = null;

      try {
        const updatedReminder = await MoneyDb.updateBilReminderActive(serialNum, !reminder.enabled);

        // 更新 reminders 数组
        const index = this.reminders.findIndex(r => r.serialNum === serialNum);
        if (index !== -1) {
          this.reminders[index] = updatedReminder;
        }

        // 重新获取列表
        await this.fetchRemindersPaged({
          currentPage: this.remindersPaged.currentPage,
          pageSize: this.remindersPaged.pageSize,
          sortOptions: {
            desc: true,
          },
          filter: {},
        });
      } catch (error: any) {
        this.error = error.message || '更新提醒状态失败';
        throw error;
      } finally {
        this.loading = false;
      }
    },

    /**
     * 清除错误
     */
    clearError() {
      this.error = null;
    },
  },
});
