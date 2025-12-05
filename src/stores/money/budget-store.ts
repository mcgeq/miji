// src/stores/money/budget-store.ts
import { defineStore } from 'pinia';
import { AppError } from '@/errors/appError';
import { MoneyDb } from '@/services/money/money';
import { toast } from '@/utils/toast';
import type { PageQuery } from '@/schema/common';
import type { Budget, BudgetCreate, BudgetUpdate } from '@/schema/money';
import type { PagedResult } from '@/services/money/baseManager';
import type { BudgetFilters } from '@/services/money/budgets';

// ==================== Store Constants ====================

/** BudgetStore 错误代码 */
export enum BudgetStoreErrorCode {
  FETCH_FAILED = 'FETCH_FAILED',
  CREATE_FAILED = 'CREATE_FAILED',
  UPDATE_FAILED = 'UPDATE_FAILED',
  DELETE_FAILED = 'DELETE_FAILED',
  TOGGLE_FAILED = 'TOGGLE_FAILED',
  NOT_FOUND = 'NOT_FOUND',
}

interface BudgetStoreState {
  budgets: Budget[];
  budgetsPaged: PagedResult<Budget>;
  loading: boolean;
  error: AppError | null;
  /** 上次查询的筛选条件（用于优化刷新） */
  lastQuery: PageQuery<BudgetFilters> | null;
  /** 当前请求控制器（用于取消请求） */
  currentAbortController: AbortController | null;
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
    lastQuery: null,
    currentAbortController: null,
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
     * 带加载状态和错误处理的操作包装器
     */
    async withLoadingSafe<T>(
      operation: () => Promise<T>,
      errorCode: BudgetStoreErrorCode,
      errorMsg: string,
      showToast = true,
    ): Promise<T> {
      this.loading = true;
      this.error = null;
      try {
        return await operation();
      } catch (error: any) {
        const appError = AppError.wrap('BudgetStore', error, errorCode, errorMsg);
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
     * 获取预算列表（分页）
     * 支持请求取消，防止竞态条件
     */
    async fetchBudgetsPaged(query: PageQuery<BudgetFilters>) {
      // 取消上一个未完成的请求
      this.cancelCurrentRequest();

      // 创建新的 AbortController
      const abortController = new AbortController();
      this.currentAbortController = abortController;

      return this.withLoadingSafe(
        async () => {
          const result = await MoneyDb.listBudgetsPaged(query);

          // 检查请求是否已被取消
          if (abortController.signal.aborted) {
            return;
          }

          this.budgetsPaged = result;
          // 保存查询条件用于优化刷新
          this.lastQuery = query;

          // 清理当前控制器
          if (this.currentAbortController === abortController) {
            this.currentAbortController = null;
          }
        },
        BudgetStoreErrorCode.FETCH_FAILED,
        '获取预算列表失败',
      );
    },

    /**
     * 刷新当前分页数据（使用上次的查询条件）
     */
    async refreshCurrentPage() {
      if (this.lastQuery) {
        await this.fetchBudgetsPaged(this.lastQuery);
      }
    },

    /**
     * 创建预算
     */
    async createBudget(data: BudgetCreate): Promise<Budget> {
      return this.withLoadingSafe(
        async () => {
          const budget = await MoneyDb.createBudget(data);
          this.budgets.push(budget);

          // 如果有分页数据，刷新当前页（异步，不阻塞）
          if (this.lastQuery) {
            this.refreshCurrentPage().catch(err => {
              console.warn('刷新分页数据失败', err);
            });
          }

          return budget;
        },
        BudgetStoreErrorCode.CREATE_FAILED,
        '创建预算失败',
      );
    },

    /**
     * 更新预算
     */
    async updateBudget(serialNum: string, data: BudgetUpdate): Promise<Budget> {
      return this.withLoadingSafe(
        async () => {
          const budget = await MoneyDb.updateBudget(serialNum, data);
          const index = this.budgets.findIndex(b => b.serialNum === serialNum);
          if (index !== -1) {
            this.budgets[index] = budget;
          }
          return budget;
        },
        BudgetStoreErrorCode.UPDATE_FAILED,
        '更新预算失败',
      );
    },

    /**
     * 删除预算
     */
    async deleteBudget(serialNum: string): Promise<void> {
      return this.withLoadingSafe(
        async () => {
          await MoneyDb.deleteBudget(serialNum);
          this.budgets = this.budgets.filter(b => b.serialNum !== serialNum);

          // 刷新分页数据
          if (this.lastQuery) {
            this.refreshCurrentPage().catch(err => {
              console.warn('刷新分页数据失败', err);
            });
          }
        },
        BudgetStoreErrorCode.DELETE_FAILED,
        '删除预算失败',
      );
    },

    /**
     * 切换预算激活状态
     */
    async toggleBudgetActive(serialNum: string, isActive: boolean): Promise<void> {
      return this.withLoadingSafe(
        async () => {
          const updatedBudget = await MoneyDb.updateBudgetActive(serialNum, isActive);

          // 更新 budgets 数组
          const index = this.budgets.findIndex(b => b.serialNum === serialNum);
          if (index !== -1) {
            this.budgets[index] = updatedBudget;
          }

          // 刷新分页数据
          await this.fetchBudgetsPaged({
            currentPage: this.budgetsPaged.currentPage,
            pageSize: this.budgetsPaged.pageSize,
            sortOptions: {
              desc: true,
            },
            filter: {},
          });
        },
        BudgetStoreErrorCode.TOGGLE_FAILED,
        '更新预算状态失败',
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

      this.budgets = [];
      this.budgetsPaged = {
        rows: [],
        totalCount: 0,
        currentPage: 1,
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
