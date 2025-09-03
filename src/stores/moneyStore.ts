// stores/moneyStore.ts
import { defineStore } from 'pinia';
import { AppError, AppErrorCode, AppErrorSeverity } from '@/errors/appError';
import { MoneyDbError } from '@/services/money/baseManager';
import { MoneyDb } from '@/services/money/money';
import type { IncomeExpense, PageQuery } from '@/schema/common';
import type {
  Account,
  BilReminder,
  BilReminderCreate,
  BilReminderUpdate,
  Budget,
  BudgetCreate,
  BudgetUpdate,
  CreateAccountRequest,
  Transaction,
  TransactionCreate,
  TransactionUpdate,
  TransferCreate,
  UpdateAccountRequest,
} from '@/schema/money';
import type { PagedResult } from '@/services/money/baseManager';
import type { TransactionFilters } from '@/services/money/transactions';
import { BudgetFilters } from '@/services/money/budgets';

export enum MoneyStoreErrorCode {
  ACCOUNT_NOT_FOUND = 'ACCOUNT_NOT_FOUND',
  TRANSACTION_NOT_FOUND = 'TRANSACTION_NOT_FOUND',
  RELATED_TRANSACTION_NOT_FOUND = 'RELATED_TRANSACTION_NOT_FOUND',
  INVALID_TRANSACTION_TYPE = 'INVALID_TRANSACTION_TYPE',
  CREDIT_CARD_BALANCE_INVALID = 'CREDIT_CARD_BALANCE_INVALID',
  DATABASE_OPERATION_FAILED = 'DATABASE_OPERATION_FAILED',
  NOT_FOUND = 'NOT_FOUND',
}

export class MoneyStoreError extends AppError {
  constructor(
    code: MoneyStoreErrorCode | AppErrorCode,
    message: string,
    details?: any,
  ) {
    let severity: AppErrorSeverity;
    switch (code) {
      case MoneyStoreErrorCode.DATABASE_OPERATION_FAILED:
      case AppErrorCode.DATABASE_FAILURE:
        severity = AppErrorSeverity.HIGH;
        break;
      case MoneyStoreErrorCode.ACCOUNT_NOT_FOUND:
      case MoneyStoreErrorCode.TRANSACTION_NOT_FOUND:
      case MoneyStoreErrorCode.RELATED_TRANSACTION_NOT_FOUND:
        severity = AppErrorSeverity.MEDIUM;
        break;
      case MoneyStoreErrorCode.INVALID_TRANSACTION_TYPE:
      case MoneyStoreErrorCode.CREDIT_CARD_BALANCE_INVALID:
        severity = AppErrorSeverity.LOW;
        break;
      default:
        severity = AppErrorSeverity.MEDIUM;
    }

    super('money', code, message, severity, details);
    this.name = 'MoneyStoreError';
    this.message = message;
  }

  public getUserMessage(): string {
    const messages: Record<string, string> = {
      [MoneyStoreErrorCode.ACCOUNT_NOT_FOUND]: 'Account does not exist.',
      [MoneyStoreErrorCode.TRANSACTION_NOT_FOUND]: 'Transaction not found.',
      [MoneyStoreErrorCode.RELATED_TRANSACTION_NOT_FOUND]:
        'Related transaction not found.',
      [MoneyStoreErrorCode.INVALID_TRANSACTION_TYPE]:
        'Invalid transaction type.',
      [MoneyStoreErrorCode.CREDIT_CARD_BALANCE_INVALID]:
        'Credit card balance is invalid.',
      [MoneyStoreErrorCode.DATABASE_OPERATION_FAILED]:
        'Database operation failed. Please try again.',
    };
    return messages[this.code] || this.message;
  }
}

// ==================== Store State Interface ====================
interface MoneyStoreState {
  accounts: Account[];
  transactions: Transaction[];
  budgets: Budget[];
  reminders: BilReminder[];
  loading: boolean;
  error: string | null;
}

export const useMoneyStore = defineStore('money', () => {
  // ==================== State ====================
  const state = reactive<MoneyStoreState>({
    accounts: [],
    transactions: [],
    budgets: [],
    reminders: [],
    loading: false,
    error: null,
  });

  // ==================== Computed Properties ====================
  const totalBalance = computed(() => {
    return state.accounts
      .filter(account => account.isActive)
      .reduce((sum, account) => sum + Number.parseFloat(account.balance), 0);
  });

  const activeAccounts = computed(() =>
    state.accounts.filter(account => account.isActive),
  );
  const activeBudgets = computed(() =>
    state.budgets.filter(budget => budget.isActive),
  );
  const unpaidReminders = computed(() =>
    state.reminders.filter(reminder => !reminder.isPaid),
  );

  // 错误处理辅助函数
  // Returns never because it always throws an error
  const handleError = (
    err: unknown,
    defaultMessage: string,
    operation?: string,
    entity?: string,
  ): AppError => {
    let appError: AppError;
    if (err instanceof MoneyDbError) {
      appError = new MoneyStoreError(
        MoneyStoreErrorCode.DATABASE_OPERATION_FAILED,
        `${defaultMessage}: ${err.message}`,
        {
          operation: operation || err.operation,
          entity: entity || err.entity,
          originalError: err.originalError,
        },
      );
    } else if (err instanceof MoneyStoreError) {
      appError = err;
    } else {
      appError = AppError.wrap(
        'money',
        err,
        MoneyStoreErrorCode.DATABASE_OPERATION_FAILED,
        defaultMessage,
      );
    }
    state.error = appError.getUserMessage();
    appError.log();
    return appError;
  };

  const withLoading = async <T>(operation: () => Promise<T>): Promise<T> => {
    state.loading = true;
    state.error = null;
    try {
      return await operation();
    } finally {
      state.loading = false;
    }
  };

  // ==================== Local State Update Utilities ====================
  const updateLocalState = {
    async accounts() {
      try {
        state.accounts = await MoneyDb.listAccounts();
      } catch (err) {
        throw handleError(err, '获取账户列表失败', 'listAccounts', 'Account');
      }
    },

    async transactions() {
      try {
        state.transactions = await MoneyDb.listTransactions();
      } catch (err) {
        handleError(err, '获取交易列表失败', 'listTransactions', 'Transaction');
      }
    },

    async budgets() {
      try {
        state.budgets = await MoneyDb.listBudgets();
      } catch (err) {
        handleError(err, '获取预算列表失败', 'listBudgets', 'Budget');
      }
    },

    async reminders() {
      try {
        state.reminders = await MoneyDb.listBilReminders();
      } catch (err) {
        handleError(err, '获取提醒列表失败', 'listBilReminders', 'BilReminder');
      }
    },
  };

  // ==================== Account Operations ====================
  const accountOperations = {
    async getAll(): Promise<Account[]> {
      return withLoading(async () => {
        await updateLocalState.accounts();
        return state.accounts;
      });
    },

    async create(account: CreateAccountRequest): Promise<Account> {
      return withLoading(async () => {
        try {
          const result = await MoneyDb.createAccount(account);
          await updateLocalState.accounts();
          return result;
        } catch (err) {
          throw handleError(err, '创建账户失败', 'createAccount', 'Account');
        }
      });
    },

    async update(
      serialNum: string,
      account: UpdateAccountRequest,
    ): Promise<Account> {
      return withLoading(async () => {
        try {
          const result = await MoneyDb.updateAccount(serialNum, account);
          await updateLocalState.accounts();
          return result;
        } catch (err) {
          throw handleError(err, '更新账户失败', 'updateAccount', 'Account');
        }
      });
    },

    async delete(serialNum: string): Promise<void> {
      return withLoading(async () => {
        try {
          await MoneyDb.deleteAccount(serialNum);
          await updateLocalState.accounts();
        } catch (err) {
          throw handleError(err, '删除账户失败', 'deleteAccount', 'Account');
        }
      });
    },

    async toggleActive(serialNum: string, isActive: boolean): Promise<void> {
      return withLoading(async () => {
        try {
          await MoneyDb.updateAccountActive(serialNum, isActive);
          await updateLocalState.accounts();
        } catch (err) {
          throw handleError(
            err,
            '切换账户状态失败',
            'updateAccountActive',
            'Account',
          );
        }
      });
    },
  };

  // ==================== Transaction Operations ====================
  const transactionOperations = {
    async getPagedList(
      query: PageQuery<TransactionFilters>,
    ): Promise<PagedResult<Transaction>> {
      return withLoading(async () => {
        try {
          const result = await MoneyDb.listTransactionsPaged(query);
          state.transactions = result.rows;
          return result;
        } catch (err) {
          throw handleError(
            err,
            '获取交易列表失败',
            'listTransactions',
            'Transaction',
          );
        }
      });
    },

    async getAll(): Promise<Transaction[]> {
      return withLoading(async () => {
        await updateLocalState.transactions();
        return state.transactions;
      });
    },

    async create(transaction: TransactionCreate): Promise<Transaction> {
      return withLoading(async () => {
        try {
          const result = await MoneyDb.createTransaction(transaction);
          await updateLocalState.transactions();
          return result;
        } catch (err) {
          throw handleError(
            err,
            '创建交易失败',
            'createTransaction',
            'Transaction',
          );
        }
      });
    },

    async update(
      serialNum: string,
      transaction: TransactionUpdate,
    ): Promise<Transaction> {
      return withLoading(async () => {
        try {
          const result = await MoneyDb.updateTransaction(
            serialNum,
            transaction,
          );
          await updateLocalState.transactions();
          return result;
        } catch (err) {
          throw handleError(
            err,
            '更新交易失败',
            'updateTransaction',
            'Transaction',
          );
        }
      });
    },

    async delete(serialNum: string): Promise<void> {
      return withLoading(async () => {
        try {
          await MoneyDb.deleteTransaction(serialNum);
          await updateLocalState.transactions();
        } catch (err) {
          throw handleError(
            err,
            '删除交易失败',
            'deleteTransaction',
            'Transaction',
          );
        }
      });
    },

    async getMonthlyIncomeExpense(): Promise<IncomeExpense> {
      try {
        return await MoneyDb.monthlyIncomeAndExpense();
      } catch (err) {
        throw handleError(
          err,
          '获取月度收支失败',
          'monthlyIncomeAndExpense',
          'IncomeExpense',
        );
      }
    },
  };

  // ==================== Transfer Operations ====================
  const transferOperations = {
    async create(transfer: TransferCreate) {
      return withLoading(async () => {
        try {
          const result = await MoneyDb.transferCreate(transfer);
          await updateLocalState.transactions();
          return result;
        } catch (err) {
          throw handleError(
            err,
            '创建转账失败',
            'transferCreate',
            'Transaction',
          );
        }
      });
    },

    async update(serialNum: string, transfer: TransferCreate) {
      return withLoading(async () => {
        try {
          const result = await MoneyDb.transferUpdate(serialNum, transfer);
          await updateLocalState.transactions();
          return result;
        } catch (err) {
          throw handleError(
            err,
            '更新转账失败',
            'transferUpdate',
            'Transaction',
          );
        }
      });
    },

    async delete(relatedTransactionSerialNum: string) {
      return withLoading(async () => {
        try {
          const result = await MoneyDb.transferDelete(
            relatedTransactionSerialNum,
          );
          await updateLocalState.transactions();
          return result;
        } catch (err) {
          throw handleError(
            err,
            '删除转账失败',
            'transferDelete',
            'Transaction',
          );
        }
      });
    },
  };

  // ==================== Budget Operations ====================
  const budgetOperations = {
    async getListPaged(
      query: PageQuery<BudgetFilters>,
    ): Promise<PagedResult<Budget>> {
      return withLoading(async () => {
        try {
          const result = await MoneyDb.listBudgetsPaged(query);
          state.budgets = result.rows;
          return result;
        } catch (err) {
          throw handleError(
            err,
            '获取交易列表失败',
            'listTransactions',
            'Transaction',
          );
        }
      });
    },

    async create(budget: BudgetCreate): Promise<Budget> {
      return withLoading(async () => {
        try {
          const result = await MoneyDb.createBudget(budget);
          await updateLocalState.budgets();
          return result;
        } catch (err) {
          throw handleError(err, '创建预算失败', 'createBudget', 'Budget');
        }
      });
    },

    async update(serialNum: string, budget: BudgetUpdate): Promise<Budget> {
      return withLoading(async () => {
        try {
          const result = await MoneyDb.updateBudget(serialNum, budget);
          await updateLocalState.budgets();
          return result;
        } catch (err) {
          throw handleError(err, '更新预算失败', 'updateBudget', 'Budget');
        }
      });
    },

    async delete(serialNum: string): Promise<void> {
      return withLoading(async () => {
        try {
          await MoneyDb.deleteBudget(serialNum);
          await updateLocalState.budgets();
        } catch (err) {
          throw handleError(err, '删除预算失败', 'deleteBudget', 'Budget');
        }
      });
    },

    async toggleActive(serialNum: string, isActive: boolean): Promise<void> {
      return withLoading(async () => {
        try {
          await MoneyDb.updateBudgetActive(serialNum, isActive);
          await updateLocalState.budgets();
        } catch (err) {
          throw handleError(err, '切换预算状态失败', 'updateBudget', 'Budget');
        }
      });
    },
  };

  // ==================== Reminder Operations ====================
  const reminderOperations = {
    async getAll(): Promise<BilReminder[]> {
      return withLoading(async () => {
        await updateLocalState.reminders();
        return state.reminders;
      });
    },

    async create(reminder: BilReminderCreate): Promise<BilReminder> {
      return withLoading(async () => {
        try {
          const result = await MoneyDb.createBilReminder(reminder);
          await updateLocalState.reminders();
          return result;
        } catch (err) {
          throw handleError(
            err,
            '创建提醒失败',
            'createBilReminder',
            'BilReminder',
          );
        }
      });
    },

    async update(
      serialNum: string,
      reminder: BilReminderUpdate,
    ): Promise<BilReminder> {
      return withLoading(async () => {
        try {
          const result = await MoneyDb.updateBilReminder(serialNum, reminder);
          await updateLocalState.reminders();
          return result;
        } catch (err) {
          throw handleError(
            err,
            '更新提醒失败',
            'updateBilReminder',
            'BilReminder',
          );
        }
      });
    },

    async delete(serialNum: string): Promise<void> {
      return withLoading(async () => {
        try {
          await MoneyDb.deleteBilReminder(serialNum);
          await updateLocalState.reminders();
        } catch (err) {
          throw handleError(
            err,
            '删除提醒失败',
            'deleteBilReminder',
            'BilReminder',
          );
        }
      });
    },

    async markPaid(serialNum: string, isPaid: boolean): Promise<void> {
      return withLoading(async () => {
        try {
          const reminder = state.reminders.find(r => r.serialNum === serialNum);
          if (!reminder) {
            const err = new MoneyStoreError(
              MoneyStoreErrorCode.NOT_FOUND,
              `提醒不存在: ${serialNum}`,
              { serialNum },
            );
            err.log();
            throw err;
          }

          // 乐观更新
          reminder.isPaid = isPaid;
          reminder.updatedAt = new Date().toISOString();

          await MoneyDb.updateBilReminderActive(serialNum, isPaid);
          await updateLocalState.reminders();
        } catch (err) {
          // 回滚乐观更新
          await updateLocalState.reminders();
          throw handleError(
            err,
            '标记支付状态失败',
            'updateBilReminder',
            'BilReminder',
          );
        }
      });
    },
  };

  // ==================== Utility Functions ====================
  const clearError = () => {
    state.error = null;
  };

  const findAccount = (serialNum: string): Account | undefined => {
    return state.accounts.find(account => account.serialNum === serialNum);
  };

  const findTransaction = (serialNum: string): Transaction | undefined => {
    return state.transactions.find(
      transaction => transaction.serialNum === serialNum,
    );
  };

  const findBudget = (serialNum: string): Budget | undefined => {
    return state.budgets.find(budget => budget.serialNum === serialNum);
  };

  const findReminder = (serialNum: string): BilReminder | undefined => {
    return state.reminders.find(reminder => reminder.serialNum === serialNum);
  };

  // ==================== Batch Operations ====================
  const batchOperations = {
    async refreshAll(): Promise<void> {
      return withLoading(async () => {
        await Promise.all([
          updateLocalState.accounts(),
          updateLocalState.transactions(),
          updateLocalState.budgets(),
          updateLocalState.reminders(),
        ]);
      });
    },

    async refreshAccountsAndTransactions(): Promise<void> {
      await Promise.all([
        updateLocalState.accounts(),
        updateLocalState.transactions(),
      ]);
    },
  };

  // ==================== Public API ====================
  return {
    // State (using toRefs for reactivity)
    ...toRefs(state),

    // Computed
    totalBalance,
    activeAccounts,
    activeBudgets,
    unpaidReminders,

    // Account operations
    getAccounts: accountOperations.getAll,
    createAccount: accountOperations.create,
    updateAccount: accountOperations.update,
    deleteAccount: accountOperations.delete,
    toggleAccountActive: accountOperations.toggleActive,

    // Transaction operations
    getTransactions: transactionOperations.getPagedList,
    getAllTransactions: transactionOperations.getAll,
    createTransaction: transactionOperations.create,
    updateTransaction: transactionOperations.update,
    deleteTransaction: transactionOperations.delete,
    monthlyIncomeAndExpense: transactionOperations.getMonthlyIncomeExpense,

    // Transfer operations
    createTransfer: transferOperations.create,
    updateTransfer: transferOperations.update,
    deleteTransfer: transferOperations.delete,

    // Budget operations
    getBudgets: budgetOperations.getListPaged,
    createBudget: budgetOperations.create,
    updateBudget: budgetOperations.update,
    deleteBudget: budgetOperations.delete,
    toggleBudgetActive: budgetOperations.toggleActive,

    // Reminder operations
    getReminders: reminderOperations.getAll,
    createReminder: reminderOperations.create,
    updateReminder: reminderOperations.update,
    deleteReminder: reminderOperations.delete,
    markReminderPaid: reminderOperations.markPaid,

    // Utilities
    clearError,
    findAccount,
    findTransaction,
    findBudget,
    findReminder,

    // Batch operations
    refreshAll: batchOperations.refreshAll,
    refreshAccountsAndTransactions:
      batchOperations.refreshAccountsAndTransactions,
  };
});
