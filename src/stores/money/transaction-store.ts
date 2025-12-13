// src/stores/money/transaction-store.ts
import { defineStore } from 'pinia';
import { AppError } from '@/errors/appError';
import type { PageQuery } from '@/schema/common';
import type {
  Transaction,
  TransactionCreate,
  TransactionUpdate,
  TransferCreate,
} from '@/schema/money';
import type { PagedResult } from '@/services/base/types';
import { transactionService } from '@/services/money/transactionService';
import type {
  InstallmentPlanResponse,
  TransactionFilters,
  TransactionStatsRequest,
  TransactionStatsResponse,
} from '@/services/money/transactions';
import { Lg } from '@/utils/debugLog';
import { toast } from '@/utils/toast';
import { emitStoreEvent } from './store-events';

// ==================== Store Constants ====================
const STORE_MODULE = 'TransactionStore';

/** TransactionStore 错误代码 */
export enum TransactionStoreErrorCode {
  FETCH_FAILED = 'FETCH_FAILED',
  CREATE_FAILED = 'CREATE_FAILED',
  UPDATE_FAILED = 'UPDATE_FAILED',
  DELETE_FAILED = 'DELETE_FAILED',
  TRANSFER_CREATE_FAILED = 'TRANSFER_CREATE_FAILED',
  TRANSFER_UPDATE_FAILED = 'TRANSFER_UPDATE_FAILED',
  TRANSFER_DELETE_FAILED = 'TRANSFER_DELETE_FAILED',
  STATS_FAILED = 'STATS_FAILED',
  INSTALLMENT_FAILED = 'INSTALLMENT_FAILED',
  NOT_FOUND = 'NOT_FOUND',
}

interface TransactionStoreState {
  /** 所有交易列表 */
  transactions: Transaction[];
  /** 分页交易数据 */
  transactionsPaged: PagedResult<Transaction>;
  /** 加载状态 */
  loading: boolean;
  /** 错误信息 */
  error: AppError | null;
  /** 上次查询的筛选条件（用于优化刷新） */
  lastQuery: PageQuery<TransactionFilters> | null;
  /** 当前请求控制器（用于取消请求） */
  currentAbortController: AbortController | null;
}

/**
 * 创建初始状态（用于不可变更新）
 */
function createInitialState(): TransactionStoreState {
  return {
    transactions: [],
    transactionsPaged: {
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
  };
}

/**
 * 交易管理 Store
 * 负责收入、支出、转账的CRUD操作和统计
 */
export const useTransactionStore = defineStore('money-transactions', {
  state: (): TransactionStoreState => createInitialState(),

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
    incomeTransactions: state => state.transactions.filter(t => t.transactionType === 'Income'),

    /**
     * 获取支出交易
     */
    expenseTransactions: state => state.transactions.filter(t => t.transactionType === 'Expense'),

    /**
     * 获取转账交易
     */
    transferTransactions: state => state.transactions.filter(t => t.transactionType === 'Transfer'),

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
     * @param err - 原始错误
     * @param code - 错误代码
     * @param message - 用户友好消息
     * @param showToast - 是否显示 toast 通知
     */
    handleError(
      err: unknown,
      code: TransactionStoreErrorCode,
      message: string,
      showToast = true,
    ): AppError {
      const appError = AppError.wrap(STORE_MODULE, err, code, message);

      // 不可变更新错误状态
      this.error = appError;

      // 结构化日志
      appError.log();

      // Toast 反馈
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
     * 取消当前请求（防止竞态条件）
     */
    cancelCurrentRequest() {
      if (this.currentAbortController) {
        Lg.i(STORE_MODULE, '取消当前请求');
        this.currentAbortController.abort();
        this.currentAbortController = null;
      }
    },

    /**
     * 带加载状态和错误处理的操作包装器
     */
    async withLoadingSafe<T>(
      operation: () => Promise<T>,
      errorCode: TransactionStoreErrorCode,
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

    // ==================== 查询操作 ====================

    /**
     * 获取交易列表（分页）
     * 支持请求取消，防止竞态条件
     */
    async fetchTransactionsPaged(query: PageQuery<TransactionFilters>) {
      Lg.i(STORE_MODULE, '获取分页交易列表', { page: query.currentPage, pageSize: query.pageSize });

      // 取消上一个未完成的请求
      this.cancelCurrentRequest();

      // 创建新的 AbortController
      const abortController = new AbortController();
      this.currentAbortController = abortController;

      return this.withLoadingSafe(
        async () => {
          const result = await transactionService.listPagedWithFilters(query);

          // 检查请求是否已被取消
          if (abortController.signal.aborted) {
            Lg.w(STORE_MODULE, '请求已被取消');
            return;
          }

          // 不可变更新：创建新对象
          this.transactionsPaged = { ...result };
          // 保存查询条件用于优化刷新
          this.lastQuery = query;
          // 清理当前控制器
          if (this.currentAbortController === abortController) {
            this.currentAbortController = null;
          }
          Lg.i(STORE_MODULE, '分页交易列表获取成功', { total: result.total });
        },
        TransactionStoreErrorCode.FETCH_FAILED,
        '获取交易列表失败',
      );
    },

    /**
     * 刷新当前分页数据（使用上次的查询条件）
     */
    async refreshCurrentPage() {
      if (this.lastQuery) {
        Lg.d(STORE_MODULE, '刷新当前分页数据');
        await this.fetchTransactionsPaged(this.lastQuery);
      } else {
        Lg.w(STORE_MODULE, '无法刷新：没有上次查询记录');
      }
    },

    /**
     * 获取交易列表（全部）
     */
    async fetchTransactions() {
      Lg.i(STORE_MODULE, '获取全部交易列表');
      return this.withLoadingSafe(
        async () => {
          const result = await transactionService.list();
          // 不可变更新：创建新数组
          this.transactions = [...result];
          Lg.i(STORE_MODULE, '全部交易列表获取成功', { count: result.length });
        },
        TransactionStoreErrorCode.FETCH_FAILED,
        '获取交易列表失败',
      );
    },

    // ==================== CRUD 操作 ====================

    /**
     * 创建交易
     */
    async createTransaction(data: TransactionCreate): Promise<Transaction> {
      Lg.i(STORE_MODULE, '创建交易', { type: data.transactionType, amount: data.amount });
      return this.withLoadingSafe(
        async () => {
          const transaction = await transactionService.create(data);

          // 不可变更新：创建新数组
          this.transactions = [transaction, ...this.transactions];

          Lg.i(STORE_MODULE, '交易创建成功', { serialNum: transaction.serialNum });

          // 发送交易创建事件，触发账户更新
          emitStoreEvent('transaction:created', {
            transactionSerialNum: transaction.serialNum,
            accountSerialNum: transaction.accountSerialNum,
          });

          // 如果有分页数据，刷新当前页（异步，不阻塞）
          if (this.lastQuery) {
            this.refreshCurrentPage().catch(err => {
              Lg.w(STORE_MODULE, '刷新分页数据失败', { error: err });
            });
          }

          return transaction;
        },
        TransactionStoreErrorCode.CREATE_FAILED,
        '创建交易失败',
      );
    },

    /**
     * 更新交易
     */
    async updateTransaction(serialNum: string, data: TransactionUpdate): Promise<Transaction> {
      Lg.i(STORE_MODULE, '更新交易', { serialNum, updates: Object.keys(data) });
      return this.withLoadingSafe(
        async () => {
          const transaction = await transactionService.update(serialNum, data);

          // 不可变更新：创建新数组，替换更新的项
          this.transactions = this.transactions.map(t =>
            t.serialNum === serialNum ? transaction : t,
          );

          Lg.i(STORE_MODULE, '交易更新成功', { serialNum });

          // 发送交易更新事件，触发账户更新
          emitStoreEvent('transaction:updated', {
            transactionSerialNum: transaction.serialNum,
            accountSerialNum: transaction.accountSerialNum,
          });

          return transaction;
        },
        TransactionStoreErrorCode.UPDATE_FAILED,
        '更新交易失败',
      );
    },

    /**
     * 批量创建交易（避免事件风暴）
     */
    async createTransactionsBatch(dataList: TransactionCreate[]): Promise<Transaction[]> {
      if (dataList.length === 0) {
        Lg.w(STORE_MODULE, '批量创建：数据为空');
        return [];
      }

      Lg.i(STORE_MODULE, '批量创建交易', { count: dataList.length });
      return this.withLoadingSafe(
        async () => {
          // TODO: 在后端实现批量创建 API
          // 目前使用并发创建，在后端实现后替换
          const transactions = await Promise.all(
            dataList.map(data => transactionService.create(data)),
          );

          // 批量更新列表
          this.transactions = [...transactions, ...this.transactions];

          // 收集所有受影响的账户（去重）
          const accountSerialNums = [...new Set(transactions.map(t => t.accountSerialNum))];

          Lg.i(STORE_MODULE, '批量创建成功', {
            count: transactions.length,
            affectedAccounts: accountSerialNums.length,
          });

          // 发送批量事件，避免事件风暴
          emitStoreEvent('transactions:batch-created', {
            transactionSerialNums: transactions.map(t => t.serialNum),
            accountSerialNums,
          });

          // 刷新分页数据
          if (this.lastQuery) {
            this.refreshCurrentPage().catch(err => {
              Lg.w(STORE_MODULE, '刷新分页数据失败', { error: err });
            });
          }

          return transactions;
        },
        TransactionStoreErrorCode.CREATE_FAILED,
        '批量创建交易失败',
      );
    },

    /**
     * 删除交易
     */
    async deleteTransaction(serialNum: string): Promise<void> {
      Lg.i(STORE_MODULE, '删除交易', { serialNum });
      return this.withLoadingSafe(
        async () => {
          // 先获取交易信息，用于事件发送
          const transaction = this.getTransactionById(serialNum);
          const accountSerialNum = transaction?.accountSerialNum;

          await transactionService.delete(serialNum);

          // 不可变更新：创建新数组，过滤掉删除的项
          this.transactions = this.transactions.filter(t => t.serialNum !== serialNum);

          Lg.i(STORE_MODULE, '交易删除成功', { serialNum });

          // 发送交易删除事件，触发账户更新
          if (accountSerialNum) {
            emitStoreEvent('transaction:deleted', {
              transactionSerialNum: serialNum,
              accountSerialNum,
            });
          }
        },
        TransactionStoreErrorCode.DELETE_FAILED,
        '删除交易失败',
      );
    },

    // ==================== 转账操作 ====================

    /**
     * 创建转账
     */
    async createTransfer(data: TransferCreate): Promise<[Transaction, Transaction]> {
      Lg.i(STORE_MODULE, '创建转账', {
        fromAccount: data.accountSerialNum,
        toAccount: data.toAccountSerialNum,
        amount: data.amount,
      });
      return this.withLoadingSafe(
        async () => {
          const [fromTx, toTx] = await transactionService.createTransfer(data);

          // 不可变更新：创建新数组
          this.transactions = [fromTx, toTx, ...this.transactions];

          Lg.i(STORE_MODULE, '转账创建成功', {
            fromSerialNum: fromTx.serialNum,
            toSerialNum: toTx.serialNum,
          });

          // 发送转账创建事件，触发两个账户更新
          emitStoreEvent('transfer:created', {
            fromAccountSerialNum: fromTx.accountSerialNum,
            toAccountSerialNum: toTx.accountSerialNum,
            fromTransactionSerialNum: fromTx.serialNum,
            toTransactionSerialNum: toTx.serialNum,
          });

          return [fromTx, toTx];
        },
        TransactionStoreErrorCode.TRANSFER_CREATE_FAILED,
        '创建转账失败',
      );
    },

    /**
     * 更新转账
     */
    async updateTransfer(
      serialNum: string,
      data: TransferCreate,
    ): Promise<[Transaction, Transaction]> {
      Lg.i(STORE_MODULE, '更新转账', { serialNum });
      return this.withLoadingSafe(
        async () => {
          const [fromTx, toTx] = await transactionService.updateTransfer(serialNum, data);

          // 不可变更新：创建新数组，替换更新的项
          this.transactions = this.transactions.map(t => {
            if (t.serialNum === fromTx.serialNum) return fromTx;
            if (t.serialNum === toTx.serialNum) return toTx;
            return t;
          });

          Lg.i(STORE_MODULE, '转账更新成功', {
            fromSerialNum: fromTx.serialNum,
            toSerialNum: toTx.serialNum,
          });

          // 发送转账更新事件，触发两个账户更新
          emitStoreEvent('transfer:updated', {
            fromAccountSerialNum: fromTx.accountSerialNum,
            toAccountSerialNum: toTx.accountSerialNum,
            fromTransactionSerialNum: fromTx.serialNum,
            toTransactionSerialNum: toTx.serialNum,
          });

          return [fromTx, toTx];
        },
        TransactionStoreErrorCode.TRANSFER_UPDATE_FAILED,
        '更新转账失败',
      );
    },

    /**
     * 删除转账
     */
    async deleteTransfer(serialNum: string): Promise<[Transaction, Transaction]> {
      Lg.i(STORE_MODULE, '删除转账', { serialNum });
      return this.withLoadingSafe(
        async () => {
          const [fromTx, toTx] = await transactionService.deleteTransfer(serialNum);

          // 不可变更新：创建新数组，过滤掉删除的项
          this.transactions = this.transactions.filter(
            t => t.serialNum !== fromTx.serialNum && t.serialNum !== toTx.serialNum,
          );

          Lg.i(STORE_MODULE, '转账删除成功', {
            fromSerialNum: fromTx.serialNum,
            toSerialNum: toTx.serialNum,
          });

          // 发送转账删除事件，触发两个账户更新
          emitStoreEvent('transfer:deleted', {
            fromAccountSerialNum: fromTx.accountSerialNum,
            toAccountSerialNum: toTx.accountSerialNum,
            fromTransactionSerialNum: fromTx.serialNum,
            toTransactionSerialNum: toTx.serialNum,
          });

          return [fromTx, toTx];
        },
        TransactionStoreErrorCode.TRANSFER_DELETE_FAILED,
        '删除转账失败',
      );
    },

    // ==================== 统计和分期 ====================

    /**
     * 获取交易统计
     */
    async getTransactionStats(request: TransactionStatsRequest): Promise<TransactionStatsResponse> {
      Lg.i(STORE_MODULE, '获取交易统计', { request });
      return this.withLoadingSafe(
        async () => {
          const result = await transactionService.getStats(request);
          Lg.i(STORE_MODULE, '交易统计获取成功');
          return result;
        },
        TransactionStoreErrorCode.STATS_FAILED,
        '获取交易统计失败',
      );
    },

    /**
     * 获取分期计划
     */
    async getInstallmentPlan(serialNum: string): Promise<InstallmentPlanResponse> {
      Lg.i(STORE_MODULE, '获取分期计划', { serialNum });
      return this.withLoadingSafe(
        async () => {
          const result = await transactionService.getInstallmentPlan(serialNum);
          Lg.i(STORE_MODULE, '分期计划获取成功', { serialNum });
          return result;
        },
        TransactionStoreErrorCode.INSTALLMENT_FAILED,
        '获取分期计划失败',
      );
    },

    // ==================== 状态重置 ====================

    /**
     * 重置整个 store 状态
     */
    $reset() {
      Lg.i(STORE_MODULE, '重置 store 状态');

      // 取消未完成的请求
      this.cancelCurrentRequest();

      const initialState = createInitialState();
      this.transactions = initialState.transactions;
      this.transactionsPaged = initialState.transactionsPaged;
      this.loading = initialState.loading;
      this.error = initialState.error;
      this.lastQuery = initialState.lastQuery;
      this.currentAbortController = initialState.currentAbortController;
    },
  },
});
