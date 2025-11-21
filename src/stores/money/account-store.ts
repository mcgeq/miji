// src/stores/money/account-store.ts
import { defineStore } from 'pinia';
import { MoneyDb } from '@/services/money/money';
import { onStoreEvent } from './store-events';
import type { Account, CreateAccountRequest, UpdateAccountRequest } from '@/schema/money';
import type { AccountFilters } from '@/services/money/accounts';

interface AccountStoreState {
  accounts: Account[];
  loading: boolean;
  error: string | null;
  // 单个账户金额隐藏状态
  accountAmountHidden: Record<string, boolean>;
}

/**
 * 账户管理 Store
 * 负责账户的CRUD操作和状态管理
 */
export const useAccountStore = defineStore('money-accounts', {
  state: (): AccountStoreState => ({
    accounts: [],
    loading: false,
    error: null,
    accountAmountHidden: {},
  }),

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
      return state.accountAmountHidden[serialNum] || false;
    },
  },

  actions: {
    /**
     * 获取账户列表
     */
    async fetchAccounts(filters?: AccountFilters) {
      this.loading = true;
      this.error = null;

      try {
        this.accounts = filters
          ? await MoneyDb.listAccountsPaged({
              currentPage: 1,
              pageSize: 1000,
              sortOptions: {
                desc: true,
              },
              filter: filters,
            }).then(r => r.rows)
          : await MoneyDb.listAccounts();
      } catch (error: any) {
        this.error = error.message || '获取账户列表失败';
        throw error;
      } finally {
        this.loading = false;
      }
    },

    /**
     * 创建账户
     */
    async createAccount(data: CreateAccountRequest): Promise<Account> {
      this.loading = true;
      this.error = null;

      try {
        const account = await MoneyDb.createAccount(data);
        this.accounts.push(account);
        return account;
      } catch (error: any) {
        this.error = error.message || '创建账户失败';
        throw error;
      } finally {
        this.loading = false;
      }
    },

    /**
     * 更新账户
     */
    async updateAccount(serialNum: string, data: UpdateAccountRequest): Promise<Account> {
      this.loading = true;
      this.error = null;

      try {
        const account = await MoneyDb.updateAccount(serialNum, data);
        const index = this.accounts.findIndex(a => a.serialNum === serialNum);
        if (index !== -1) {
          this.accounts[index] = account;
        }
        return account;
      } catch (error: any) {
        this.error = error.message || '更新账户失败';
        throw error;
      } finally {
        this.loading = false;
      }
    },

    /**
     * 删除账户
     */
    async deleteAccount(serialNum: string): Promise<void> {
      this.loading = true;
      this.error = null;

      try {
        await MoneyDb.deleteAccount(serialNum);
        this.accounts = this.accounts.filter(a => a.serialNum !== serialNum);
      } catch (error: any) {
        this.error = error.message || '删除账户失败';
        throw error;
      } finally {
        this.loading = false;
      }
    },

    /**
     * 切换账户激活状态
     */
    async toggleAccountActive(serialNum: string): Promise<void> {
      const account = this.getAccountById(serialNum);
      if (!account) return;

      this.loading = true;
      this.error = null;

      try {
        const updatedAccount = await MoneyDb.updateAccountActive(serialNum, !account.isActive);
        const index = this.accounts.findIndex(a => a.serialNum === serialNum);
        if (index !== -1) {
          this.accounts[index] = updatedAccount;
        }
      } catch (error: any) {
        this.error = error.message || '更新账户状态失败';
        throw error;
      } finally {
        this.loading = false;
      }
    },

    /**
     * 切换单个账户金额隐藏
     */
    toggleAccountAmountHidden(serialNum: string) {
      this.accountAmountHidden[serialNum] = !this.accountAmountHidden[serialNum];
    },

    /**
     * 刷新单个账户（用于交易后更新余额）
     */
    async refreshAccount(serialNum: string): Promise<void> {
      try {
        const account = await MoneyDb.getAccount(serialNum);
        if (account) {
          const index = this.accounts.findIndex(a => a.serialNum === serialNum);
          if (index !== -1) {
            this.accounts[index] = account;
          } else {
            // 如果账户不在列表中，添加它
            this.accounts.push(account);
          }
        }
      } catch (error: any) {
        console.error('刷新账户失败:', error);
        // 不抛出错误，避免影响主流程
      }
    },

    /**
     * 批量刷新账户（用于转账后更新两个账户）
     */
    async refreshAccounts(serialNums: string[]): Promise<void> {
      try {
        await Promise.all(serialNums.map(id => this.refreshAccount(id)));
      } catch (error: any) {
        console.error('批量刷新账户失败:', error);
      }
    },

    /**
     * 初始化事件监听器
     * 监听交易相关事件，自动刷新受影响的账户
     */
    initEventListeners() {
      // 监听交易创建事件
      onStoreEvent('transaction:created', async ({ accountSerialNum }) => {
        await this.refreshAccount(accountSerialNum);
      });

      // 监听交易更新事件
      onStoreEvent('transaction:updated', async ({ accountSerialNum }) => {
        await this.refreshAccount(accountSerialNum);
      });

      // 监听交易删除事件
      onStoreEvent('transaction:deleted', async ({ accountSerialNum }) => {
        await this.refreshAccount(accountSerialNum);
      });

      // 监听转账创建事件
      onStoreEvent('transfer:created', async ({ fromAccountSerialNum, toAccountSerialNum }) => {
        await this.refreshAccounts([fromAccountSerialNum, toAccountSerialNum]);
      });

      // 监听转账更新事件
      onStoreEvent('transfer:updated', async ({ fromAccountSerialNum, toAccountSerialNum }) => {
        await this.refreshAccounts([fromAccountSerialNum, toAccountSerialNum]);
      });

      // 监听转账删除事件
      onStoreEvent('transfer:deleted', async ({ fromAccountSerialNum, toAccountSerialNum }) => {
        await this.refreshAccounts([fromAccountSerialNum, toAccountSerialNum]);
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
