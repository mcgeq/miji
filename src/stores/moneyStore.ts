// stores/moneyStore.ts
import { defineStore } from 'pinia';
import { AppError, AppErrorCode, AppErrorSeverity } from '@/errors/appError';
import { SortDirection } from '@/schema/common';
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
import type { AccountFilters } from '@/services/money/accounts';
import type { PagedResult } from '@/services/money/baseManager';
import type { BudgetFilters } from '@/services/money/budgets';
import type { TransactionFilters } from '@/services/money/transactions';

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

export const useMoneyStore = defineStore('money', {
  state: (): MoneyStoreState => ({
    accounts: [],
    transactions: [],
    budgets: [],
    reminders: [],
    loading: false,
    error: null,
  }),
  // ==================== Getters ====================
  getters: {
    totalBalance: state => {
      return state.accounts
        .filter(account => account.isActive)
        .reduce((sum, account) => sum + Number.parseFloat(account.balance), 0);
    },
    activeAccounts: state => state.accounts.filter(account => account.isActive),
    activeBudgets: state => state.budgets.filter(budget => budget.isActive),
    unpaidReminders: state =>
      state.reminders.filter(reminder => !reminder.isPaid),
    findAccount: state => (serialNum: string) => {
      return state.accounts.find(account => account.serialNum === serialNum);
    },
    findTransaction: state => (serialNum: string) => {
      return state.transactions.find(
        transaction => transaction.serialNum === serialNum,
      );
    },
    findBudget: state => (serialNum: string) => {
      return state.budgets.find(budget => budget.serialNum === serialNum);
    },
    findReminder: state => (serialNum: string) => {
      return state.reminders.find(reminder => reminder.serialNum === serialNum);
    },
  },
  // ==================== Actions ====================
  actions: {
    // 错误处理辅助函数
    handleError(
      err: unknown,
      defaultMessage: string,
      operation?: string,
      entity?: string,
    ): AppError {
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
      this.error = appError.getUserMessage();
      appError.log();
      return appError;
    },
    async withLoading<T>(operation: () => Promise<T>): Promise<T> {
      this.loading = true;
      this.error = null;
      try {
        return await operation();
      } finally {
        this.loading = false;
      }
    },

    // ==================== Local State Update Utilities ====================
    async updateAccounts() {
      const query: PageQuery<AccountFilters> = {
        currentPage: 1,
        pageSize: 20,
        sortOptions: {
          desc: true,
          sortDir: SortDirection.Desc,
        },
        filter: {},
      };
      try {
        this.accounts = (await MoneyDb.listAccountsPaged(query)).rows;
      } catch (err) {
        throw this.handleError(
          err,
          '获取账户列表失败',
          'listAccounts',
          'Account',
        );
      }
    },

    async updateTransactions() {
      const query: PageQuery<TransactionFilters> = {
        currentPage: 1,
        pageSize: 10,
        sortOptions: {
          desc: true,
          sortDir: SortDirection.Desc,
        },
        filter: {},
      };

      try {
        this.transactions = (await MoneyDb.listTransactionsPaged(query)).rows;
      } catch (err) {
        this.handleError(
          err,
          '获取交易列表失败',
          'listTransactions',
          'Transaction',
        );
      }
    },

    async updateBudgets() {
      const query: PageQuery<BudgetFilters> = {
        currentPage: 1,
        pageSize: 10,
        sortOptions: {
          desc: true,
          sortDir: SortDirection.Desc,
        },
        filter: {},
      };

      try {
        this.budgets = (await MoneyDb.listBudgetsPaged(query)).rows;
      } catch (err) {
        this.handleError(err, '获取预算列表失败', 'listBudgets', 'Budget');
      }
    },

    async updateReminders() {
      try {
        this.reminders = await MoneyDb.listBilReminders();
      } catch (err) {
        this.handleError(
          err,
          '获取提醒列表失败',
          'listBilReminders',
          'BilReminder',
        );
      }
    },

    // ==================== Account Operations ====================
    async getAllAccounts(): Promise<Account[]> {
      return this.withLoading(async () => {
        await this.updateAccounts();
        return this.accounts;
      });
    },

    async createAccount(account: CreateAccountRequest): Promise<Account> {
      return this.withLoading(async () => {
        try {
          const result = await MoneyDb.createAccount(account);
          await this.updateAccounts();
          return result;
        } catch (err) {
          throw this.handleError(
            err,
            '创建账户失败',
            'createAccount',
            'Account',
          );
        }
      });
    },

    async updateAccount(
      serialNum: string,
      account: UpdateAccountRequest,
    ): Promise<Account> {
      return this.withLoading(async () => {
        try {
          const result = await MoneyDb.updateAccount(serialNum, account);
          await this.updateAccounts();
          return result;
        } catch (err) {
          throw this.handleError(
            err,
            '更新账户失败',
            'updateAccount',
            'Account',
          );
        }
      });
    },

    async deleteAccount(serialNum: string): Promise<void> {
      return this.withLoading(async () => {
        try {
          await MoneyDb.deleteAccount(serialNum);
          await this.updateAccounts();
        } catch (err) {
          throw this.handleError(
            err,
            '删除账户失败',
            'deleteAccount',
            'Account',
          );
        }
      });
    },

    async toggleAccountActive(
      serialNum: string,
      isActive: boolean,
    ): Promise<void> {
      return this.withLoading(async () => {
        try {
          await MoneyDb.updateAccountActive(serialNum, isActive);
          await this.updateAccounts();
        } catch (err) {
          throw this.handleError(
            err,
            '切换账户状态失败',
            'updateAccountActive',
            'Account',
          );
        }
      });
    },
    // ==================== Transaction Operations ====================
    async getPagedTransactions(
      query: PageQuery<TransactionFilters>,
    ): Promise<PagedResult<Transaction>> {
      return this.withLoading(async () => {
        try {
          const result = await MoneyDb.listTransactionsPaged(query);
          this.transactions = result.rows;
          return result;
        } catch (err) {
          throw this.handleError(
            err,
            '获取交易列表失败',
            'listTransactions',
            'Transaction',
          );
        }
      });
    },

    async getAllTransactions(): Promise<Transaction[]> {
      return this.withLoading(async () => {
        await this.updateTransactions();
        return this.transactions;
      });
    },

    async createTransaction(
      transaction: TransactionCreate,
    ): Promise<Transaction> {
      return this.withLoading(async () => {
        try {
          const result = await MoneyDb.createTransaction(transaction);
          await this.updateTransactions();
          return result;
        } catch (err) {
          throw this.handleError(
            err,
            '创建交易失败',
            'createTransaction',
            'Transaction',
          );
        }
      });
    },

    async updateTransaction(
      serialNum: string,
      transaction: TransactionUpdate,
    ): Promise<Transaction> {
      return this.withLoading(async () => {
        try {
          const result = await MoneyDb.updateTransaction(
            serialNum,
            transaction,
          );
          await this.updateTransactions();
          return result;
        } catch (err) {
          throw this.handleError(
            err,
            '更新交易失败',
            'updateTransaction',
            'Transaction',
          );
        }
      });
    },

    async deleteTransaction(serialNum: string): Promise<void> {
      return this.withLoading(async () => {
        try {
          await MoneyDb.deleteTransaction(serialNum);
          await this.updateTransactions();
        } catch (err) {
          throw this.handleError(
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
        throw this.handleError(
          err,
          '获取月度收支失败',
          'monthlyIncomeAndExpense',
          'IncomeExpense',
        );
      }
    },

    // ==================== Transfer Operations ====================
    async createTransfer(transfer: TransferCreate) {
      return this.withLoading(async () => {
        try {
          const result = await MoneyDb.transferCreate(transfer);
          await this.updateTransactions();
          return result;
        } catch (err) {
          throw this.handleError(
            err,
            '创建转账失败',
            'transferCreate',
            'Transaction',
          );
        }
      });
    },

    async updateTransfer(serialNum: string, transfer: TransferCreate) {
      return this.withLoading(async () => {
        try {
          const result = await MoneyDb.transferUpdate(serialNum, transfer);
          await this.updateTransactions();
          return result;
        } catch (err) {
          throw this.handleError(
            err,
            '更新转账失败',
            'transferUpdate',
            'Transaction',
          );
        }
      });
    },

    async deleteTransfer(relatedTransactionSerialNum: string) {
      return this.withLoading(async () => {
        try {
          const result = await MoneyDb.transferDelete(
            relatedTransactionSerialNum,
          );
          await this.updateTransactions();
          return result;
        } catch (err) {
          throw this.handleError(
            err,
            '删除转账失败',
            'transferDelete',
            'Transaction',
          );
        }
      });
    },

    // ==================== Budget Operations ====================
    async getPagedBudgets(
      query: PageQuery<BudgetFilters>,
    ): Promise<PagedResult<Budget>> {
      return this.withLoading(async () => {
        try {
          const result = await MoneyDb.listBudgetsPaged(query);
          this.budgets = result.rows;
          return result;
        } catch (err) {
          throw this.handleError(
            err,
            '获取预算列表失败',
            'listBudgets',
            'Budget',
          );
        }
      });
    },

    async createBudget(budget: BudgetCreate): Promise<Budget> {
      return this.withLoading(async () => {
        try {
          const result = await MoneyDb.createBudget(budget);
          await this.updateBudgets();
          return result;
        } catch (err) {
          throw this.handleError(err, '创建预算失败', 'createBudget', 'Budget');
        }
      });
    },

    async updateBudget(
      serialNum: string,
      budget: BudgetUpdate,
    ): Promise<Budget> {
      return this.withLoading(async () => {
        try {
          const result = await MoneyDb.updateBudget(serialNum, budget);
          await this.updateBudgets();
          return result;
        } catch (err) {
          throw this.handleError(err, '更新预算失败', 'updateBudget', 'Budget');
        }
      });
    },

    async deleteBudget(serialNum: string): Promise<void> {
      return this.withLoading(async () => {
        try {
          await MoneyDb.deleteBudget(serialNum);
          await this.updateBudgets();
        } catch (err) {
          throw this.handleError(err, '删除预算失败', 'deleteBudget', 'Budget');
        }
      });
    },

    async toggleBudgetActive(
      serialNum: string,
      isActive: boolean,
    ): Promise<void> {
      return this.withLoading(async () => {
        try {
          await MoneyDb.updateBudgetActive(serialNum, isActive);
          await this.updateBudgets();
        } catch (err) {
          throw this.handleError(
            err,
            '切换预算状态失败',
            'updateBudget',
            'Budget',
          );
        }
      });
    },

    // ==================== Reminder Operations ====================
    async getAllReminders(): Promise<BilReminder[]> {
      return this.withLoading(async () => {
        await this.updateReminders();
        return this.reminders;
      });
    },

    async createReminder(reminder: BilReminderCreate): Promise<BilReminder> {
      return this.withLoading(async () => {
        try {
          const result = await MoneyDb.createBilReminder(reminder);
          await this.updateReminders();
          return result;
        } catch (err) {
          throw this.handleError(
            err,
            '创建提醒失败',
            'createBilReminder',
            'BilReminder',
          );
        }
      });
    },

    async updateReminder(
      serialNum: string,
      reminder: BilReminderUpdate,
    ): Promise<BilReminder> {
      return this.withLoading(async () => {
        try {
          const result = await MoneyDb.updateBilReminder(serialNum, reminder);
          await this.updateReminders();
          return result;
        } catch (err) {
          throw this.handleError(
            err,
            '更新提醒失败',
            'updateBilReminder',
            'BilReminder',
          );
        }
      });
    },

    async deleteReminder(serialNum: string): Promise<void> {
      return this.withLoading(async () => {
        try {
          await MoneyDb.deleteBilReminder(serialNum);
          await this.updateReminders();
        } catch (err) {
          throw this.handleError(
            err,
            '删除提醒失败',
            'deleteBilReminder',
            'BilReminder',
          );
        }
      });
    },

    async markReminderPaid(serialNum: string, isPaid: boolean): Promise<void> {
      return this.withLoading(async () => {
        try {
          const reminder = this.reminders.find(r => r.serialNum === serialNum);
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
          await this.updateReminders();
        } catch (err) {
          // 回滚乐观更新
          await this.updateReminders();
          throw this.handleError(
            err,
            '标记支付状态失败',
            'updateBilReminder',
            'BilReminder',
          );
        }
      });
    },

    // ==================== Utility Functions ====================
    clearError() {
      this.error = null;
    },

    // ==================== Batch Operations ====================
    async refreshAll(): Promise<void> {
      return this.withLoading(async () => {
        await Promise.all([
          this.updateAccounts(),
          this.updateTransactions(),
          this.updateBudgets(),
          this.updateReminders(),
        ]);
      });
    },

    async refreshAccountsAndTransactions(): Promise<void> {
      return this.withLoading(async () => {
        await Promise.all([this.updateAccounts(), this.updateTransactions()]);
      });
    },
  },
});
