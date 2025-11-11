// src/stores/money/account-store.ts
import { defineStore } from 'pinia';
import { MoneyDb } from '@/services/money/money';
import type { Account, CreateAccountRequest, UpdateAccountRequest } from '@/schema/money';
import type { AccountFilters } from '@/services/money/accounts';

interface AccountStoreState {
  accounts: Account[];
  loading: boolean;
  error: string | null;
  // 金额隐藏状态
  globalAmountHidden: boolean;
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
    globalAmountHidden: false,
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
     * 检查账户金额是否隐藏
     */
    isAccountAmountHidden: state => (serialNum: string) => {
      return state.globalAmountHidden || state.accountAmountHidden[serialNum] || false;
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

      await this.updateAccount(serialNum, { isActive: !account.isActive });
    },

    /**
     * 切换全局金额隐藏
     */
    toggleGlobalAmountHidden() {
      this.globalAmountHidden = !this.globalAmountHidden;
    },

    /**
     * 切换单个账户金额隐藏
     */
    toggleAccountAmountHidden(serialNum: string) {
      this.accountAmountHidden[serialNum] = !this.accountAmountHidden[serialNum];
    },

    /**
     * 清除错误
     */
    clearError() {
      this.error = null;
    },
  },
});
