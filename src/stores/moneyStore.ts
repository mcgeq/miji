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
  BilReminderFilters,
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
import type { Category, SubCategory } from '@/schema/money/category';
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
  constructor(code: MoneyStoreErrorCode | AppErrorCode, message: string, details?: any) {
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
      [MoneyStoreErrorCode.RELATED_TRANSACTION_NOT_FOUND]: 'Related transaction not found.',
      [MoneyStoreErrorCode.INVALID_TRANSACTION_TYPE]: 'Invalid transaction type.',
      [MoneyStoreErrorCode.CREDIT_CARD_BALANCE_INVALID]: 'Credit card balance is invalid.',
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
  budgetsPaged: PagedResult<Budget>;
  remindersPaged: PagedResult<BilReminder>;
  reminders: BilReminder[];
  subCategorys: SubCategory[];
  categories: Category[];
  lastFetchedSubCategories: Date | null;
  lastFetchedCategories: Date | null;
  subCategoriesCacheExpiry: number;
  categoriesCacheExpiry: number;
  loading: boolean;
  error: string | null;
}

export const useMoneyStore = defineStore('money', {
  state: (): MoneyStoreState => ({
    accounts: [],
    transactions: [],
    budgets: [],
    budgetsPaged: { rows: [], totalPages: 0, currentPage: 1, totalCount: 0, pageSize: 10 },
    subCategorys: [],
    categories: [],
    remindersPaged: { rows: [], totalPages: 0, currentPage: 1, totalCount: 0, pageSize: 10 },
    reminders: [],
    lastFetchedSubCategories: null,
    lastFetchedCategories: null,
    categoriesCacheExpiry: 8 * 60 * 60 * 1000,
    subCategoriesCacheExpiry: 8 * 60 * 60 * 1000,
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
    activeBudgets: state => state.budgetsPaged.rows.filter(budget => budget.isActive),
    unpaidReminders: state => state.remindersPaged?.rows.filter(reminder => !reminder.isPaid),
    findAccount: state => (serialNum: string) => {
      return state.accounts.find(account => account.serialNum === serialNum);
    },
    findTransaction: state => (serialNum: string) => {
      return state.transactions.find(transaction => transaction.serialNum === serialNum);
    },
    findBudget: state => (serialNum: string) => {
      return state.budgetsPaged.rows.find(budget => budget.serialNum === serialNum);
    },
    findReminder: state => (serialNum: string) => {
      return state.remindersPaged?.rows.find(reminder => reminder.serialNum === serialNum);
    },
    subCategories: state => {
      return state.subCategorys.map(sub => ({
        name: sub.name,
        categoryName: sub.categoryName,
      }));
    },
    uiCategories: state => {
      return state.categories.map(category => ({
        code: category.name,
        icon: category.icon,
      }));
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
    async withLoadingSafe<T>(
      operation: () => Promise<T>,
      errorMsg: string,
      operationKey?: string,
      entityKey?: string,
    ): Promise<T> {
      this.loading = true;
      this.error = null;
      try {
        return await operation();
      } catch (err) {
        const appError = this.handleError(err, errorMsg, operationKey, entityKey);
        throw appError;
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
      return this.withLoadingSafe(
        async () => {
          const result = await MoneyDb.listAccountsPaged(query);
          this.accounts = result.rows;
        },
        '获取账户列表失败',
        'listAccounts',
        'Account',
      );
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
      return this.withLoadingSafe(
        async () => {
          const result = await MoneyDb.listTransactionsPaged(query);
          this.transactions = result.rows;
          await this.updateBudgets(true);
        },
        '获取交易列表失败',
        'listTransactions',
        'Transaction',
      );
    },

    async updateBudgets(paged: boolean) {
      const query: PageQuery<BudgetFilters> = {
        currentPage: 1,
        pageSize: 10,
        sortOptions: {
          desc: true,
          sortDir: SortDirection.Desc,
        },
        filter: {},
      };
      return this.withLoadingSafe(
        async () => {
          if (paged) {
            const result = await MoneyDb.listBudgetsPaged(query);
            this.budgetsPaged = result;
          } else {
            const result = await MoneyDb.listBudgets();
            this.budgets = result;
          }
        },
        '获取预算列表失败',
        'listBudgets',
        'Budget',
      );
    },

    async updateReminders(paged: boolean) {
      const query: PageQuery<BilReminderFilters> = {
        currentPage: 1,
        pageSize: 10,
        sortOptions: {
          desc: true,
          sortDir: SortDirection.Desc,
        },
        filter: {},
      };

      return this.withLoadingSafe(
        async () => {
          if (paged) {
            this.remindersPaged = await MoneyDb.listBilRemindersPaged(query);
          } else {
            this.reminders = await MoneyDb.listBilReminders();
          }
        },
        '获取提醒列表失败',
        'listBilReminders',
        'BilReminder',
      );
    },

    async updateSubCategories(forceRefresh: boolean = false) {
      return this.withLoadingSafe(
        async () => {
          const isCacheValid =
            !this.lastFetchedSubCategories ||
            Date.now() - this.lastFetchedSubCategories.getTime() > this.subCategoriesCacheExpiry ||
            forceRefresh;
          if (isCacheValid) {
            this.subCategorys = await MoneyDb.listSubCategory();
            this.lastFetchedSubCategories = new Date();
          }
        },
        '获取子分类信息失败',
        'updateSubCategories',
        'SubCategory',
      );
    },

    async updateCategories(forceRefresh: boolean = false) {
      return this.withLoadingSafe(
        async () => {
          const isCacheValid =
            !this.lastFetchedCategories ||
            Date.now() - this.lastFetchedCategories.getTime() > this.categoriesCacheExpiry ||
            forceRefresh;
          if (isCacheValid) {
            this.categories = await MoneyDb.listCategory();
            this.lastFetchedCategories = new Date();
          }
        },
        '获取分类信息失败',
        'updateCategories',
        'Category',
      );
    },

    // ==================== Account Operations ====================
    async getAllAccounts(): Promise<Account[]> {
      return this.withLoading(async () => {
        await this.updateAccounts();
        return this.accounts;
      });
    },

    async createAccount(account: CreateAccountRequest): Promise<Account> {
      return this.withLoadingSafe(
        async () => {
          const result = await MoneyDb.createAccount(account);
          await this.updateAccounts();
          return result;
        },
        '创建账户失败',
        'createAccount',
        'Account',
      );
    },

    async updateAccount(serialNum: string, account: UpdateAccountRequest): Promise<Account> {
      return this.withLoadingSafe(
        async () => {
          const result = await MoneyDb.updateAccount(serialNum, account);
          await this.updateAccounts();
          return result;
        },
        '更新账户失败',
        'updateAccount',
        'Account',
      );
    },

    async deleteAccount(serialNum: string): Promise<void> {
      return this.withLoadingSafe(
        async () => {
          await MoneyDb.deleteAccount(serialNum);
          await this.updateAccounts();
        },
        '删除账户失败',
        'deleteAccount',
        'Account',
      );
    },

    async toggleAccountActive(serialNum: string, isActive: boolean): Promise<void> {
      return this.withLoadingSafe(
        async () => {
          await MoneyDb.updateAccountActive(serialNum, isActive);
          await this.updateAccounts();
        },
        '切换账户状态失败',
        'updateAccountActive',
        'Account',
      );
    },
    // ==================== Transaction Operations ====================
    async getPagedTransactions(
      query: PageQuery<TransactionFilters>,
    ): Promise<PagedResult<Transaction>> {
      return this.withLoadingSafe(
        async () => {
          const result = await MoneyDb.listTransactionsPaged(query);
          this.transactions = result.rows;
          return result;
        },
        '获取交易列表失败',
        'listTransactions',
        'Transaction',
      );
    },

    async getAllTransactions(): Promise<Transaction[]> {
      return this.withLoading(async () => {
        await this.updateTransactions();
        return this.transactions;
      });
    },

    async createTransaction(transaction: TransactionCreate): Promise<Transaction> {
      return this.withLoadingSafe(
        async () => {
          const result = await MoneyDb.createTransaction(transaction);
          await this.updateTransactions();
          return result;
        },
        '创建交易失败',
        'createTransaction',
        'Transaction',
      );
    },

    async updateTransaction(
      serialNum: string,
      transaction: TransactionUpdate,
    ): Promise<Transaction> {
      return this.withLoadingSafe(
        async () => {
          const result = await MoneyDb.updateTransaction(serialNum, transaction);
          await this.updateTransactions();
          return result;
        },
        '更新交易失败',
        'updateTransaction',
        'Transaction',
      );
    },

    async deleteTransaction(serialNum: string): Promise<void> {
      return this.withLoadingSafe(
        async () => {
          await MoneyDb.deleteTransaction(serialNum);
          await this.updateTransactions();
        },
        '删除交易失败',
        'deleteTransaction',
        'Transaction',
      );
    },

    async getMonthlyIncomeExpense(): Promise<IncomeExpense> {
      return this.withLoadingSafe(
        async () => {
          return await MoneyDb.monthlyIncomeAndExpense();
        },
        '获取月度收支失败',
        'monthlyIncomeAndExpense',
        'IncomeExpense',
      );
    },

    // ==================== Transfer Operations ====================
    async createTransfer(transfer: TransferCreate) {
      return this.withLoadingSafe(
        async () => {
          const result = await MoneyDb.transferCreate(transfer);
          await this.updateTransactions();
          return result;
        },
        '创建转账失败',
        'transferCreate',
        'Transaction',
      );
    },

    async updateTransfer(serialNum: string, transfer: TransferCreate) {
      return this.withLoadingSafe(
        async () => {
          const result = await MoneyDb.transferUpdate(serialNum, transfer);
          await this.updateTransactions();
          return result;
        },
        '更新转账失败',
        'transferUpdate',
        'Transaction',
      );
    },

    async deleteTransfer(relatedTransactionSerialNum: string) {
      return this.withLoadingSafe(
        async () => {
          const result = await MoneyDb.transferDelete(relatedTransactionSerialNum);
          await this.updateTransactions();
          return result;
        },
        '删除转账失败',
        'transferDelete',
        'Transaction',
      );
    },

    // ==================== Budget Operations ====================
    async getPagedBudgets(query: PageQuery<BudgetFilters>): Promise<PagedResult<Budget>> {
      return this.withLoadingSafe(
        async () => {
          const result = await MoneyDb.listBudgetsPaged(query);
          this.budgetsPaged = result;
          return result;
        },
        '获取预算列表失败',
        'listBudgets',
        'Budget',
      );
    },

    async createBudget(budget: BudgetCreate): Promise<Budget> {
      return this.withLoadingSafe(
        async () => {
          const result = await MoneyDb.createBudget(budget);
          await this.updateBudgets(true);
          return result;
        },
        '创建预算失败',
        'createBudget',
        'Budget',
      );
    },

    async updateBudget(serialNum: string, budget: BudgetUpdate): Promise<Budget> {
      return this.withLoadingSafe(
        async () => {
          const result = await MoneyDb.updateBudget(serialNum, budget);
          await this.updateBudgets(true);
          return result;
        },
        '更新预算失败',
        'updateBudget',
        'Budget',
      );
    },

    async deleteBudget(serialNum: string): Promise<void> {
      return this.withLoadingSafe(
        async () => {
          await MoneyDb.deleteBudget(serialNum);
          await this.updateBudgets(true);
        },
        '删除预算失败',
        'deleteBudget',
        'Budget',
      );
    },

    async toggleBudgetActive(serialNum: string, isActive: boolean): Promise<void> {
      return this.withLoadingSafe(
        async () => {
          await MoneyDb.updateBudgetActive(serialNum, isActive);
          await this.updateBudgets(true);
        },
        '切换预算状态失败',
        'updateBudget',
        'Budget',
      );
    },

    // ==================== Reminder Operations ====================
    async getPagedBilReminders(
      query: PageQuery<BilReminderFilters>,
    ): Promise<PagedResult<BilReminder>> {
      return this.withLoadingSafe(
        async () => {
          const result = await MoneyDb.listBilRemindersPaged(query);
          this.remindersPaged = result;
          return result;
        },
        '获取预算列表失败',
        'listBudgets',
        'Budget',
      );
    },

    async getAllReminders(): Promise<BilReminder[]> {
      return this.withLoading(async () => {
        await this.updateReminders(false);
        return this.reminders;
      });
    },
    async getPagedReminders(): Promise<PagedResult<BilReminder>> {
      return this.withLoading(async () => {
        await this.updateReminders(true);
        return this.remindersPaged;
      });
    },

    async createReminder(reminder: BilReminderCreate): Promise<BilReminder> {
      return this.withLoadingSafe(
        async () => {
          const result = await MoneyDb.createBilReminder(reminder);
          await this.updateReminders(true);
          return result;
        },
        '创建提醒失败',
        'createBilReminder',
        'BilReminder',
      );
    },

    async updateReminder(serialNum: string, reminder: BilReminderUpdate): Promise<BilReminder> {
      return this.withLoadingSafe(
        async () => {
          const result = await MoneyDb.updateBilReminder(serialNum, reminder);
          await this.updateReminders(true);
          return result;
        },
        '更新提醒失败',
        'updateBilReminder',
        'BilReminder',
      );
    },

    async deleteReminder(serialNum: string): Promise<void> {
      return this.withLoadingSafe(
        async () => {
          await MoneyDb.deleteBilReminder(serialNum);
          await this.updateReminders(true);
        },
        '删除提醒失败',
        'deleteBilReminder',
        'BilReminder',
      );
    },

    async markReminderPaid(serialNum: string, isPaid: boolean): Promise<void> {
      return this.withLoading(async () => {
        try {
          const reminder = this.remindersPaged?.rows.find(r => r.serialNum === serialNum);
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
          await this.updateReminders(true);
        } catch (err) {
          // 回滚乐观更新
          await this.updateReminders(true);
          throw this.handleError(err, '标记支付状态失败', 'updateBilReminder', 'BilReminder');
        }
      });
    },

    // Category
    async getAllCategories(forcwRefresh: boolean = false): Promise<Category[]> {
      return this.withLoading(async () => {
        await this.updateCategories(forcwRefresh);
        return this.categories;
      });
    },

    async getAllSubCategories(forcwRefresh: boolean = false): Promise<SubCategory[]> {
      return this.withLoading(async () => {
        await this.updateSubCategories(forcwRefresh);
        return this.subCategorys;
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
          this.updateBudgets(true),
          this.updateReminders(false),
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
