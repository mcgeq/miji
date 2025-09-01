// stores/moneyStore.ts
import { defineStore } from 'pinia';
import { AppError, AppErrorCode, AppErrorSeverity } from '@/errors/appError';
import { MoneyDbError, type PagedResult } from '@/services/money/baseManager';
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

export const useMoneyStore = defineStore('money', () => {
  // 状态
  const accounts = ref<Account[]>([]);
  const transactions = ref<Transaction[]>([]);
  const budgets = ref<Budget[]>([]);
  const reminders = ref<BilReminder[]>([]);

  const loading = ref(false);
  const error = ref<string | null>(null);

  // 计算属性
  const totalBalance = computed(() => {
    return accounts.value
      .filter(account => account.isActive)
      .reduce((sum, account) => sum + Number.parseFloat(account.balance), 0);
  });

  const activeAccounts = computed(() => {
    return accounts.value.filter(account => account.isActive);
  });

  const activeBudgets = computed(() => {
    return budgets.value.filter(budget => budget.isActive);
  });

  const unpaidReminders = computed(() => {
    return reminders.value.filter(reminder => !reminder.isPaid);
  });

  // 错误处理辅助函数
  // Returns never because it always throws an error
  const handleMoneyStoreError = (
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
    error.value = appError.getUserMessage();
    appError.log();
    return appError;
  };

  // 辅助方法
  const updateLocalAccounts = async () => {
    try {
      const accountList = await MoneyDb.listAccounts();
      accounts.value = accountList;
    } catch (err) {
      throw handleMoneyStoreError(
        err,
        '获取账户列表失败',
        'listAccounts',
        'Account',
      );
    }
  };

  const updateLocalTransactions = async () => {
    try {
      const rows = await MoneyDb.listTransactions();
      transactions.value = rows;
    } catch (err) {
      handleMoneyStoreError(
        err,
        '获取交易列表失败',
        'listTransactions',
        'Transaction',
      );
    }
  };

  const updateLocalBudgets = async () => {
    try {
      const budgetList = await MoneyDb.listBudgets();
      budgets.value = budgetList;
    } catch (err) {
      handleMoneyStoreError(err, '获取预算列表失败', 'listBudgets', 'Budget');
    }
  };

  const updateLocalReminders = async () => {
    try {
      const reminderList = await MoneyDb.listBilReminders();
      reminders.value = reminderList;
    } catch (err) {
      handleMoneyStoreError(
        err,
        '获取提醒列表失败',
        'listBilReminders',
        'BilReminder',
      );
    }
  };

  // 账户相关方法
  const getAccounts = async (): Promise<Account[]> => {
    loading.value = true;
    error.value = null;

    try {
      const accountList = await MoneyDb.listAccounts();
      accounts.value = accountList;
      return accountList;
    } catch (err) {
      throw handleMoneyStoreError(
        err,
        '获取账户列表失败',
        'listAccounts',
        'Account',
      );
    } finally {
      loading.value = false;
    }
  };

  const createAccount = async (
    account: CreateAccountRequest,
  ): Promise<Account> => {
    loading.value = true;
    error.value = null;
    try {
      const result = await MoneyDb.createAccount(account);
      await updateLocalAccounts();
      return result;
    } catch (err) {
      throw handleMoneyStoreError(
        err,
        '创建账户失败',
        'createAccount',
        'Account',
      );
    } finally {
      loading.value = false;
    }
  };

  const updateAccount = async (
    serialNum: string,
    account: UpdateAccountRequest,
  ): Promise<Account> => {
    loading.value = true;
    error.value = null;

    try {
      const act = await MoneyDb.updateAccount(serialNum, account);
      await updateLocalAccounts();
      return act;
    } catch (err) {
      throw handleMoneyStoreError(
        err,
        '更新账户失败',
        'updateAccount',
        'Account',
      );
    } finally {
      loading.value = false;
    }
  };

  const deleteAccount = async (serialNum: string): Promise<void> => {
    loading.value = true;
    error.value = null;

    try {
      await MoneyDb.deleteAccount(serialNum);
      await updateLocalAccounts();
    } catch (err) {
      throw handleMoneyStoreError(
        err,
        '删除账户失败',
        'deleteAccount',
        'Account',
      );
    } finally {
      loading.value = false;
    }
  };

  const toggleAccountActive = async (
    serialNum: string,
    isActive: boolean,
  ): Promise<void> => {
    loading.value = true;
    error.value = null;

    try {
      await MoneyDb.updateAccountActive(serialNum, isActive);
    } catch (err) {
      throw handleMoneyStoreError(
        err,
        '切换账户状态失败',
        'updateAccountActive',
        'Account',
      );
    } finally {
      loading.value = false;
    }
  };

  // ------------------------------ 交易 ------------------------------
  // 交易相关方法
  const getTransactions = async (
    query: PageQuery<TransactionFilters>,
  ): Promise<PagedResult<Transaction>> => {
    loading.value = true;
    error.value = null;
    console.log('getTransactions ', query);
    try {
      const result = await MoneyDb.listTransactionsPaged(query);
      transactions.value = result.rows;
      return result;
    } catch (err) {
      throw handleMoneyStoreError(
        err,
        '获取交易列表失败',
        'listTransactions',
        'Transaction',
      );
    } finally {
      loading.value = false;
    }
  };

  const getAllTransactions = async () => {
    loading.value = true;
    error.value = null;

    try {
      const result = await MoneyDb.listTransactions();
      transactions.value = result;
      return result;
    } catch (err) {
      throw handleMoneyStoreError(
        err,
        '获取交易列表失败',
        'listTransactions',
        'Transaction',
      );
    } finally {
      loading.value = false;
    }
  };

  const createTransaction = async (
    transaction: TransactionCreate,
  ): Promise<Transaction> => {
    loading.value = true;
    error.value = null;
    try {
      const result = await MoneyDb.createTransaction(transaction);
      await updateLocalTransactions();
      return result;
    } catch (err) {
      throw handleMoneyStoreError(
        err,
        '创建交易失败',
        'createTransaction',
        'Transaction',
      );
    } finally {
      loading.value = false;
    }
  };

  const updateTransaction = async (
    serialNum: string,
    transaction: TransactionUpdate,
  ): Promise<Transaction> => {
    loading.value = true;
    error.value = null;

    try {
      const result = await MoneyDb.updateTransaction(serialNum, transaction);
      await updateLocalTransactions();
      return result;
    } catch (err) {
      throw handleMoneyStoreError(
        err,
        '更新交易失败',
        'updateTransaction',
        'Transaction',
      );
    } finally {
      loading.value = false;
    }
  };

  const deleteTransaction = async (serialNum: string): Promise<void> => {
    loading.value = true;
    error.value = null;

    try {
      const result = await MoneyDb.deleteTransaction(serialNum);
      await updateLocalTransactions();
      return result;
    } catch (err) {
      throw handleMoneyStoreError(
        err,
        '删除交易失败',
        'deleteTransaction',
        'Transaction',
      );
    } finally {
      loading.value = false;
    }
  };

  const createTransfer = async (transfer: TransferCreate) => {
    loading.value = true;
    error.value = null;

    try {
      const result = await MoneyDb.transferCreate(transfer);
      await updateLocalTransactions();
      return result;
    } catch (err) {
      throw handleMoneyStoreError(
        err,
        '更新转账交易失败',
        'updateTransferTransaction',
        'Transaction',
      );
    } finally {
      loading.value = false;
    }
  };

  const updateTransfer = async (
    serialNum: string,
    transfer: TransferCreate,
  ) => {
    loading.value = true;
    error.value = null;

    try {
      const result = await MoneyDb.transferUpdate(serialNum, transfer);
      await updateLocalTransactions();
      return result;
    } catch (err) {
      throw handleMoneyStoreError(
        err,
        '更新转账交易失败',
        'updateTransferTransaction',
        'Transaction',
      );
    } finally {
      loading.value = false;
    }
  };

  const deleteTransfer = async (relatedTransactionSerialNum: string) => {
    loading.value = true;
    error.value = null;

    try {
      const result = await MoneyDb.transferDelete(relatedTransactionSerialNum);
      await updateLocalTransactions();
      return result;
    } catch (err) {
      throw handleMoneyStoreError(
        err,
        '删除转账交易失败',
        'deleteTransferTransaction',
        'Transaction',
      );
    } finally {
      loading.value = false;
    }
  };

  const monthlyIncomeAndExpense = async (): Promise<IncomeExpense> => {
    try {
      return await MoneyDb.monthlyIncomeAndExpense();
    } catch (err) {
      throw handleMoneyStoreError(
        err,
        '获取月度收支失败',
        'monthlyIncomeAndExpense',
        'IncomeExpense',
      );
    }
  };

  // 预算相关方法
  const getBudgets = async (): Promise<Budget[]> => {
    loading.value = true;
    error.value = null;

    try {
      const budgetList = await MoneyDb.listBudgets();
      budgets.value = budgetList;
      return budgetList;
    } catch (err) {
      throw handleMoneyStoreError(
        err,
        '获取预算列表失败',
        'listBudgets',
        'Budget',
      );
    } finally {
      loading.value = false;
    }
  };

  const createBudget = async (budget: BudgetCreate): Promise<Budget> => {
    loading.value = true;
    error.value = null;

    try {
      const result = await MoneyDb.createBudget(budget);
      await updateLocalBudgets();
      return result;
    } catch (err) {
      throw handleMoneyStoreError(
        err,
        '创建预算失败',
        'createBudget',
        'Budget',
      );
    } finally {
      loading.value = false;
    }
  };

  const updateBudget = async (
    serialNum: string,
    budget: BudgetUpdate,
  ): Promise<Budget> => {
    loading.value = true;
    error.value = null;

    try {
      const result = await MoneyDb.updateBudget(serialNum, budget);
      await updateLocalBudgets();
      return result;
    } catch (err) {
      throw handleMoneyStoreError(
        err,
        '更新预算失败',
        'updateBudget',
        'Budget',
      );
    } finally {
      loading.value = false;
    }
  };

  const deleteBudget = async (serialNum: string): Promise<void> => {
    loading.value = true;
    error.value = null;

    try {
      await MoneyDb.deleteBudget(serialNum);
      await updateLocalBudgets();
    } catch (err) {
      throw handleMoneyStoreError(
        err,
        '删除预算失败',
        'deleteBudget',
        'Budget',
      );
    } finally {
      loading.value = false;
    }
  };

  const toggleBudgetActive = async (
    serialNum: string,
    isActive: boolean,
  ): Promise<void> => {
    loading.value = true;
    error.value = null;

    try {
      await MoneyDb.updateBudgetActive(serialNum, isActive);
      await updateLocalBudgets();
    } catch (err) {
      throw handleMoneyStoreError(
        err,
        '切换预算状态失败',
        'updateBudget',
        'Budget',
      );
    } finally {
      loading.value = false;
    }
  };

  // 提醒相关方法
  const getReminders = async (): Promise<BilReminder[]> => {
    loading.value = true;
    error.value = null;

    try {
      const reminderList = await MoneyDb.listBilReminders();
      reminders.value = reminderList;
      return reminderList;
    } catch (err) {
      throw handleMoneyStoreError(
        err,
        '获取提醒列表失败',
        'listBilReminders',
        'BilReminder',
      );
    } finally {
      loading.value = false;
    }
  };

  const createReminder = async (
    reminder: BilReminderCreate,
  ): Promise<BilReminder> => {
    loading.value = true;
    error.value = null;

    try {
      const result = await MoneyDb.createBilReminder(reminder);
      await updateLocalReminders();
      return result;
    } catch (err) {
      throw handleMoneyStoreError(
        err,
        '创建提醒失败',
        'createBilReminder',
        'BilReminder',
      );
    } finally {
      loading.value = false;
    }
  };

  const updateReminder = async (
    serialNum: string,
    reminder: BilReminderUpdate,
  ): Promise<BilReminder> => {
    loading.value = true;
    error.value = null;

    try {
      const result = await MoneyDb.updateBilReminder(serialNum, reminder);
      await updateLocalReminders();
      return result;
    } catch (err) {
      throw handleMoneyStoreError(
        err,
        '更新提醒失败',
        'updateBilReminder',
        'BilReminder',
      );
    } finally {
      loading.value = false;
    }
  };

  const deleteReminder = async (serialNum: string): Promise<void> => {
    loading.value = true;
    error.value = null;

    try {
      await MoneyDb.deleteBilReminder(serialNum);
      await updateLocalReminders();
    } catch (err) {
      throw handleMoneyStoreError(
        err,
        '删除提醒失败',
        'deleteBilReminder',
        'BilReminder',
      );
    } finally {
      loading.value = false;
    }
  };

  const markReminderPaid = async (
    serialNum: string,
    isPaid: boolean,
  ): Promise<void> => {
    loading.value = true;
    error.value = null;

    try {
      const reminder = reminders.value.find(r => r.serialNum === serialNum);
      if (!reminder) {
        const err = new MoneyStoreError(
          MoneyStoreErrorCode.NOT_FOUND,
          `提醒不存在: ${serialNum}`,
          { serialNum },
        );
        err.log();
        throw err;
      }
      reminder.isPaid = true;
      reminder.updatedAt = new Date().toISOString();
      await MoneyDb.updateBilReminderActive(serialNum, isPaid);
      await updateLocalReminders();
    } catch (err) {
      throw handleMoneyStoreError(
        err,
        '标记支付状态失败',
        'updateBilReminder',
        'BilReminder',
      );
    } finally {
      loading.value = false;
    }
  };

  // 辅助方法
  const clearError = () => {
    error.value = null;
  };

  return {
    // 状态
    accounts,
    transactions,
    budgets,
    reminders,
    loading,
    error,

    // 计算属性
    totalBalance,
    activeAccounts,
    activeBudgets,
    unpaidReminders,

    // 方法
    getAccounts,
    createAccount,
    updateAccount,
    deleteAccount,
    toggleAccountActive,

    getTransactions,
    getAllTransactions,
    createTransaction,
    updateTransaction,
    deleteTransaction,
    createTransfer,
    updateTransfer,
    deleteTransfer,
    monthlyIncomeAndExpense,

    getBudgets,
    createBudget,
    updateBudget,
    deleteBudget,
    toggleBudgetActive,

    getReminders,
    createReminder,
    updateReminder,
    deleteReminder,
    markReminderPaid,

    clearError,
  };
});
