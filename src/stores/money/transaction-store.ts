// src/stores/money/transaction-store.ts
import { defineStore } from 'pinia';
import { MoneyDb } from '@/services/money/money';
import type { PageQuery } from '@/schema/common';
import type {
  Transaction,
  TransactionCreate,
  TransactionUpdate,
  TransferCreate,
} from '@/schema/money';
import type { PagedResult } from '@/services/money/baseManager';
import type {
  InstallmentPlanResponse,
  TransactionFilters,
  TransactionStatsRequest,
  TransactionStatsResponse,
} from '@/services/money/transactions';

interface TransactionStoreState {
  transactions: Transaction[];
  transactionsPaged: PagedResult<Transaction>;
  loading: boolean;
  error: string | null;
}

/**
 * 交易管理 Store
 * 负责收入、支出、转账的CRUD操作和统计
 */
export const useTransactionStore = defineStore('money-transactions', {
  state: (): TransactionStoreState => ({
    transactions: [],
    transactionsPaged: {
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
     * 根据ID获取交易
     */
    getTransactionById: state => (id: string) => {
      return state.transactions.find(t => t.serialNum === id);
    },

    /**
     * 获取收入交易
     */
    incomeTransactions: state =>
      state.transactions.filter(t => t.transactionType === 'Income'),

    /**
     * 获取支出交易
     */
    expenseTransactions: state =>
      state.transactions.filter(t => t.transactionType === 'Expense'),

    /**
     * 获取转账交易
     */
    transferTransactions: state =>
      state.transactions.filter(t => t.transactionType === 'Transfer'),
  },

  actions: {
    /**
     * 获取交易列表（分页）
     */
    async fetchTransactionsPaged(query: PageQuery<TransactionFilters>) {
      this.loading = true;
      this.error = null;

      try {
        this.transactionsPaged = await MoneyDb.listTransactionsPaged(query);
      } catch (error: any) {
        this.error = error.message || '获取交易列表失败';
        throw error;
      } finally {
        this.loading = false;
      }
    },

    /**
     * 获取交易列表（全部）
     */
    async fetchTransactions() {
      this.loading = true;
      this.error = null;

      try {
        this.transactions = await MoneyDb.listTransactions();
      } catch (error: any) {
        this.error = error.message || '获取交易列表失败';
        throw error;
      } finally {
        this.loading = false;
      }
    },

    /**
     * 创建交易
     */
    async createTransaction(data: TransactionCreate): Promise<Transaction> {
      this.loading = true;
      this.error = null;

      try {
        const transaction = await MoneyDb.createTransaction(data);
        this.transactions.unshift(transaction);
        return transaction;
      } catch (error: any) {
        this.error = error.message || '创建交易失败';
        throw error;
      } finally {
        this.loading = false;
      }
    },

    /**
     * 更新交易
     */
    async updateTransaction(serialNum: string, data: TransactionUpdate): Promise<Transaction> {
      this.loading = true;
      this.error = null;

      try {
        const transaction = await MoneyDb.updateTransaction(serialNum, data);
        const index = this.transactions.findIndex(t => t.serialNum === serialNum);
        if (index !== -1) {
          this.transactions[index] = transaction;
        }
        return transaction;
      } catch (error: any) {
        this.error = error.message || '更新交易失败';
        throw error;
      } finally {
        this.loading = false;
      }
    },

    /**
     * 删除交易
     */
    async deleteTransaction(serialNum: string): Promise<void> {
      this.loading = true;
      this.error = null;

      try {
        await MoneyDb.deleteTransaction(serialNum);
        this.transactions = this.transactions.filter(t => t.serialNum !== serialNum);
      } catch (error: any) {
        this.error = error.message || '删除交易失败';
        throw error;
      } finally {
        this.loading = false;
      }
    },

    /**
     * 创建转账
     */
    async createTransfer(data: TransferCreate): Promise<[Transaction, Transaction]> {
      this.loading = true;
      this.error = null;

      try {
        const [fromTx, toTx] = await MoneyDb.transferCreate(data);
        this.transactions.unshift(fromTx, toTx);
        return [fromTx, toTx];
      } catch (error: any) {
        this.error = error.message || '创建转账失败';
        throw error;
      } finally {
        this.loading = false;
      }
    },

    /**
     * 更新转账
     */
    async updateTransfer(
      serialNum: string,
      data: TransferCreate,
    ): Promise<[Transaction, Transaction]> {
      this.loading = true;
      this.error = null;

      try {
        const [fromTx, toTx] = await MoneyDb.transferUpdate(serialNum, data);

        // 更新两个交易
        const fromIndex = this.transactions.findIndex(t => t.serialNum === fromTx.serialNum);
        const toIndex = this.transactions.findIndex(t => t.serialNum === toTx.serialNum);

        if (fromIndex !== -1) this.transactions[fromIndex] = fromTx;
        if (toIndex !== -1) this.transactions[toIndex] = toTx;

        return [fromTx, toTx];
      } catch (error: any) {
        this.error = error.message || '更新转账失败';
        throw error;
      } finally {
        this.loading = false;
      }
    },

    /**
     * 删除转账
     */
    async deleteTransfer(serialNum: string): Promise<[Transaction, Transaction]> {
      this.loading = true;
      this.error = null;

      try {
        const [fromTx, toTx] = await MoneyDb.transferDelete(serialNum);

        // 从列表中移除两个交易
        this.transactions = this.transactions.filter(
          t => t.serialNum !== fromTx.serialNum && t.serialNum !== toTx.serialNum,
        );

        return [fromTx, toTx];
      } catch (error: any) {
        this.error = error.message || '删除转账失败';
        throw error;
      } finally {
        this.loading = false;
      }
    },

    /**
     * 获取交易统计
     */
    async getTransactionStats(request: TransactionStatsRequest): Promise<TransactionStatsResponse> {
      this.loading = true;
      this.error = null;

      try {
        return await MoneyDb.getTransactionStats(request);
      } catch (error: any) {
        this.error = error.message || '获取交易统计失败';
        throw error;
      } finally {
        this.loading = false;
      }
    },

    /**
     * 获取分期计划
     */
    async getInstallmentPlan(serialNum: string): Promise<InstallmentPlanResponse> {
      this.loading = true;
      this.error = null;

      try {
        return await MoneyDb.getInstallmentPlan(serialNum);
      } catch (error: any) {
        this.error = error.message || '获取分期计划失败';
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
