// src/stores/money/budget-store.ts
import { defineStore } from 'pinia';
import { MoneyDb } from '@/services/money/money';
import type { PageQuery } from '@/schema/common';
import type { Budget, BudgetCreate, BudgetUpdate } from '@/schema/money';
import type { PagedResult } from '@/services/money/baseManager';
import type { BudgetFilters } from '@/services/money/budgets';

interface BudgetStoreState {
  budgets: Budget[];
  budgetsPaged: PagedResult<Budget>;
  loading: boolean;
  error: string | null;
}

/**
 * 预算管理 Store
 */
export const useBudgetStore = defineStore('money-budgets', {
  state: (): BudgetStoreState => ({
    budgets: [],
    budgetsPaged: {
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
     * 获取活跃的预算
     */
    activeBudgets: state => state.budgets.filter(b => b.isActive),

    /**
     * 根据ID获取预算
     */
    getBudgetById: state => (id: string) => {
      return state.budgets.find(b => b.serialNum === id);
    },
  },

  actions: {
    /**
     * 获取预算列表（分页）
     */
    async fetchBudgetsPaged(query: PageQuery<BudgetFilters>) {
      this.loading = true;
      this.error = null;

      try {
        this.budgetsPaged = await MoneyDb.listBudgetsPaged(query);
      } catch (error: any) {
        this.error = error.message || '获取预算列表失败';
        throw error;
      } finally {
        this.loading = false;
      }
    },

    /**
     * 创建预算
     */
    async createBudget(data: BudgetCreate): Promise<Budget> {
      this.loading = true;
      this.error = null;

      try {
        const budget = await MoneyDb.createBudget(data);
        this.budgets.push(budget);
        return budget;
      } catch (error: any) {
        this.error = error.message || '创建预算失败';
        throw error;
      } finally {
        this.loading = false;
      }
    },

    /**
     * 更新预算
     */
    async updateBudget(serialNum: string, data: BudgetUpdate): Promise<Budget> {
      this.loading = true;
      this.error = null;

      try {
        const budget = await MoneyDb.updateBudget(serialNum, data);
        const index = this.budgets.findIndex(b => b.serialNum === serialNum);
        if (index !== -1) {
          this.budgets[index] = budget;
        }
        return budget;
      } catch (error: any) {
        this.error = error.message || '更新预算失败';
        throw error;
      } finally {
        this.loading = false;
      }
    },

    /**
     * 删除预算
     */
    async deleteBudget(serialNum: string): Promise<void> {
      this.loading = true;
      this.error = null;

      try {
        await MoneyDb.deleteBudget(serialNum);
        this.budgets = this.budgets.filter(b => b.serialNum !== serialNum);
      } catch (error: any) {
        this.error = error.message || '删除预算失败';
        throw error;
      } finally {
        this.loading = false;
      }
    },

    /**
     * 切换预算激活状态
     */
    async toggleBudgetActive(serialNum: string): Promise<void> {
      const budget = this.getBudgetById(serialNum);
      if (!budget) return;

      await MoneyDb.updateBudgetActive(serialNum, !budget.isActive);
      await this.fetchBudgetsPaged({
        currentPage: this.budgetsPaged.currentPage,
        pageSize: this.budgetsPaged.pageSize,
        sortOptions: {
          desc: true,
        },
        filter: {},
      });
    },

    /**
     * 清除错误
     */
    clearError() {
      this.error = null;
    },
  },
});
