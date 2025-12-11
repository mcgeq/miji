// src/stores/money/account-store.ts
import { defineStore } from 'pinia';
import { AppError } from '@/errors/appError';
import type { Account, CreateAccountRequest, UpdateAccountRequest } from '@/schema/money';
import type { AccountFilters } from '@/services/money/accounts';
import { MoneyDb } from '@/services/money/money';
import { Lg } from '@/utils/debugLog';
import { toast } from '@/utils/toast';
import { type EventCleanup, onStoreEvent } from './store-events';

// ==================== Store Constants ====================
const STORE_MODULE = 'AccountStore';

/** AccountStore 错误代码 */
export enum AccountStoreErrorCode {
  FETCH_FAILED = 'FETCH_FAILED',
  CREATE_FAILED = 'CREATE_FAILED',
  UPDATE_FAILED = 'UPDATE_FAILED',
  DELETE_FAILED = 'DELETE_FAILED',
  TOGGLE_FAILED = 'TOGGLE_FAILED',
  REFRESH_FAILED = 'REFRESH_FAILED',
  NOT_FOUND = 'NOT_FOUND',
}

interface AccountStoreState {
  /** 账户列表 */
  accounts: Account[];
  /** 加载状态 */
  loading: boolean;
  /** 错误信息 */
  error: AppError | null;
  /** 全局金额隐藏状态 */
  globalAmountHidden: boolean;
  /** 单个账户金额隐藏状态 */
  accountAmountHidden: Record<string, boolean>;
  /** 事件监听器清理函数 */
  eventCleanups: EventCleanup[];
}

/**
 * 创建初始状态
 */
function createInitialState(): AccountStoreState {
  return {
    accounts: [],
    loading: false,
    error: null,
    globalAmountHidden: false,
    accountAmountHidden: {},
    eventCleanups: [],
  };
}

/**
 * 账户管理 Store
 * 负责账户的CRUD操作和状态管理
 */
export const useAccountStore = defineStore('money-accounts', {
  state: (): AccountStoreState => createInitialState(),

  getters: {
    /**
     * 获取所有激活的账户
     */
    activeAccounts: state => state.accounts.filter(a => a.isActive),

    /**
     * 计算总余额
     */
    totalBalance: state => {
      return state.accounts.reduce((sum, a) => {
        return sum + Number.parseFloat(a.balance || '0');
      }, 0);
    },

    /**
     * 根据ID获取账户
     */
    getAccountById: state => (id: string) => {
      return state.accounts.find(a => a.serialNum === id);
    },

    /**
     * 检查单个账户金额是否隐藏
     */
    isAccountAmountHidden: state => (serialNum: string) => {
      return state.accountAmountHidden[serialNum] ?? false;
    },

    /**
     * 获取用户友好的错误消息
     */
    errorMessage: (state): string | null => {
      return state.error?.getUserMessage() ?? null;
    },
  },

  actions: {
    // ==================== 错误处理 ====================

    /**
     * 统一错误处理
     */
    handleError(
      err: unknown,
      code: AccountStoreErrorCode,
      message: string,
      showToast = true,
    ): AppError {
      const appError = AppError.wrap(STORE_MODULE, err, code, message);
      this.error = appError;
      appError.log();
      if (showToast) {
        toast.error(appError.getUserMessage());
      }
      return appError;
    },

    /**
     * 清除错误状态
     */
    clearError() {
      this.error = null;
    },

    /**
     * 带加载状态和错误处理的操作包装器
     */
    async withLoadingSafe<T>(
      operation: () => Promise<T>,
      errorCode: AccountStoreErrorCode,
      errorMsg: string,
      showToast = true,
    ): Promise<T> {
      this.loading = true;
      this.error = null;
      try {
        return await operation();
      } catch (err) {
        const appError = this.handleError(err, errorCode, errorMsg, showToast);
        throw appError;
      } finally {
        this.loading = false;
      }
    },

    // ==================== CRUD 操作 ====================

    /**
     * 获取账户列表
     */
    async fetchAccounts(filters?: AccountFilters) {
      Lg.i(STORE_MODULE, '获取账户列表', { hasFilters: !!filters });
      return this.withLoadingSafe(
        async () => {
          const result = filters
            ? await MoneyDb.listAccountsPaged({
                currentPage: 1,
                pageSize: 1000,
                sortOptions: { desc: true },
                filter: filters,
              }).then(r => r.rows)
            : await MoneyDb.listAccounts();

          // 不可变更新
          this.accounts = [...result];
          Lg.i(STORE_MODULE, '账户列表获取成功', { count: result.length });
        },
        AccountStoreErrorCode.FETCH_FAILED,
        '获取账户列表失败',
      );
    },

    /**
     * 创建账户
     */
    async createAccount(data: CreateAccountRequest): Promise<Account> {
      Lg.i(STORE_MODULE, '创建账户', { name: data.name, type: data.type });
      return this.withLoadingSafe(
        async () => {
          const account = await MoneyDb.createAccount(data);
          // 不可变更新
          this.accounts = [...this.accounts, account];
          Lg.i(STORE_MODULE, '账户创建成功', { serialNum: account.serialNum });
          return account;
        },
        AccountStoreErrorCode.CREATE_FAILED,
        '创建账户失败',
      );
    },

    /**
     * 更新账户
     */
    async updateAccount(serialNum: string, data: UpdateAccountRequest): Promise<Account> {
      Lg.i(STORE_MODULE, '更新账户', { serialNum, updates: Object.keys(data) });
      return this.withLoadingSafe(
        async () => {
          const account = await MoneyDb.updateAccount(serialNum, data);
          // 不可变更新
          this.accounts = this.accounts.map(a => (a.serialNum === serialNum ? account : a));
          Lg.i(STORE_MODULE, '账户更新成功', { serialNum });
          return account;
        },
        AccountStoreErrorCode.UPDATE_FAILED,
        '更新账户失败',
      );
    },

    /**
     * 删除账户
     */
    async deleteAccount(serialNum: string): Promise<void> {
      Lg.i(STORE_MODULE, '删除账户', { serialNum });
      return this.withLoadingSafe(
        async () => {
          await MoneyDb.deleteAccount(serialNum);
          // 不可变更新
          this.accounts = this.accounts.filter(a => a.serialNum !== serialNum);
          Lg.i(STORE_MODULE, '账户删除成功', { serialNum });
        },
        AccountStoreErrorCode.DELETE_FAILED,
        '删除账户失败',
      );
    },

    /**
     * 切换账户激活状态
     */
    async toggleAccountActive(serialNum: string): Promise<void> {
      const account = this.getAccountById(serialNum);
      if (!account) {
        Lg.w(STORE_MODULE, '账户不存在', { serialNum });
        return;
      }

      Lg.i(STORE_MODULE, '切换账户状态', { serialNum, currentActive: account.isActive });
      return this.withLoadingSafe(
        async () => {
          const updatedAccount = await MoneyDb.updateAccountActive(serialNum, !account.isActive);
          // 不可变更新
          this.accounts = this.accounts.map(a => (a.serialNum === serialNum ? updatedAccount : a));
          Lg.i(STORE_MODULE, '账户状态切换成功', { serialNum, newActive: updatedAccount.isActive });
        },
        AccountStoreErrorCode.TOGGLE_FAILED,
        '更新账户状态失败',
      );
    },

    // ==================== UI 状态管理 ====================

    /**
     * 切换全局金额隐藏
     */
    toggleGlobalAmountHidden() {
      this.globalAmountHidden = !this.globalAmountHidden;
      Lg.d(STORE_MODULE, '切换全局金额隐藏', { hidden: this.globalAmountHidden });
    },

    /**
     * 切换单个账户金额隐藏
     */
    toggleAccountAmountHidden(serialNum: string) {
      // 不可变更新
      this.accountAmountHidden = {
        ...this.accountAmountHidden,
        [serialNum]: !this.accountAmountHidden[serialNum],
      };
      Lg.d(STORE_MODULE, '切换账户金额隐藏', {
        serialNum,
        hidden: this.accountAmountHidden[serialNum],
      });
    },

    // ==================== 刷新操作 ====================

    /**
     * 刷新单个账户（用于交易后更新余额）
     */
    async refreshAccount(serialNum: string): Promise<void> {
      try {
        const account = await MoneyDb.getAccount(serialNum);
        if (account) {
          const index = this.accounts.findIndex(a => a.serialNum === serialNum);
          if (index !== -1) {
            // 不可变更新
            this.accounts = this.accounts.map(a => (a.serialNum === serialNum ? account : a));
          } else {
            // 不可变更新：添加新账户
            this.accounts = [...this.accounts, account];
          }
          Lg.d(STORE_MODULE, '账户刷新成功', { serialNum });
        }
      } catch (err) {
        // 不抛出错误，避免影响主流程，但记录日志
        Lg.w(STORE_MODULE, '刷新账户失败', { serialNum, error: err });
      }
    },

    /**
     * 批量刷新账户（用于转账后更新两个账户）
     */
    async refreshAccounts(serialNums: string[]): Promise<void> {
      Lg.d(STORE_MODULE, '批量刷新账户', { count: serialNums.length });
      try {
        await Promise.all(serialNums.map(id => this.refreshAccount(id)));
      } catch (err) {
        Lg.w(STORE_MODULE, '批量刷新账户失败', { serialNums, error: err });
      }
    },

    // ==================== 事件监听 ====================

    /**
     * 初始化事件监听器
     * 监听交易相关事件，自动刷新受影响的账户
     */
    initEventListeners() {
      Lg.i(STORE_MODULE, '初始化事件监听器');

      // 先清理旧的监听器
      this.cleanupEventListeners();

      // 监听交易创建事件
      this.eventCleanups.push(
        onStoreEvent('transaction:created', async ({ accountSerialNum }) => {
          await this.refreshAccount(accountSerialNum);
        }),
      );

      // 监听交易更新事件
      this.eventCleanups.push(
        onStoreEvent('transaction:updated', async ({ accountSerialNum }) => {
          await this.refreshAccount(accountSerialNum);
        }),
      );

      // 监听交易删除事件
      this.eventCleanups.push(
        onStoreEvent('transaction:deleted', async ({ accountSerialNum }) => {
          await this.refreshAccount(accountSerialNum);
        }),
      );

      // 监听转账创建事件
      this.eventCleanups.push(
        onStoreEvent('transfer:created', async ({ fromAccountSerialNum, toAccountSerialNum }) => {
          await this.refreshAccounts([fromAccountSerialNum, toAccountSerialNum]);
        }),
      );

      // 监听转账更新事件
      this.eventCleanups.push(
        onStoreEvent('transfer:updated', async ({ fromAccountSerialNum, toAccountSerialNum }) => {
          await this.refreshAccounts([fromAccountSerialNum, toAccountSerialNum]);
        }),
      );

      // 监听转账删除事件
      this.eventCleanups.push(
        onStoreEvent('transfer:deleted', async ({ fromAccountSerialNum, toAccountSerialNum }) => {
          await this.refreshAccounts([fromAccountSerialNum, toAccountSerialNum]);
        }),
      );

      // 监听批量交易事件（避免事件风暴）
      this.eventCleanups.push(
        onStoreEvent('transactions:batch-created', async ({ accountSerialNums }) => {
          Lg.d(STORE_MODULE, '处理批量交易创建事件', { count: accountSerialNums.length });
          await this.refreshAccounts(accountSerialNums);
        }),
      );

      this.eventCleanups.push(
        onStoreEvent('transactions:batch-updated', async ({ accountSerialNums }) => {
          Lg.d(STORE_MODULE, '处理批量交易更新事件', { count: accountSerialNums.length });
          await this.refreshAccounts(accountSerialNums);
        }),
      );

      this.eventCleanups.push(
        onStoreEvent('transactions:batch-deleted', async ({ accountSerialNums }) => {
          Lg.d(STORE_MODULE, '处理批量交易删除事件', { count: accountSerialNums.length });
          await this.refreshAccounts(accountSerialNums);
        }),
      );

      Lg.i(STORE_MODULE, '事件监听器初始化完成', { count: this.eventCleanups.length });
    },

    /**
     * 清理事件监听器
     * 在 store 销毁或重新初始化时调用
     */
    cleanupEventListeners() {
      if (this.eventCleanups.length > 0) {
        Lg.i(STORE_MODULE, '清理事件监听器', { count: this.eventCleanups.length });
        this.eventCleanups.forEach(cleanup => {
          cleanup();
        });
        this.eventCleanups = [];
      }
    },

    // ==================== 状态重置 ====================

    /**
     * 重置整个 store 状态
     */
    $reset() {
      Lg.i(STORE_MODULE, '重置 store 状态');

      // 先清理事件监听器
      this.cleanupEventListeners();

      const initialState = createInitialState();
      this.accounts = initialState.accounts;
      this.loading = initialState.loading;
      this.error = initialState.error;
      this.globalAmountHidden = initialState.globalAmountHidden;
      this.accountAmountHidden = initialState.accountAmountHidden;
      this.eventCleanups = initialState.eventCleanups;
    },
  },
});
