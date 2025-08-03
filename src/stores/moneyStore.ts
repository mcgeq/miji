// stores/moneyStore.ts

import { defineStore } from 'pinia';
import { AppError, AppErrorCode, AppErrorSeverity } from '@/errors/appError';
import { TransactionTypeSchema } from '@/schema/common';
import { MoneyDbError } from '@/services/money/baseManager';
import { MoneyDb } from '@/services/money/money';
import { DateUtils } from '@/utils/date';
import { uuid } from '@/utils/uuid';
import type { Category, IncomeExpense, TransactionType } from '@/schema/common';
import type {
  Account,
  BilReminder,
  Budget,
  TransactionWithAccount,
} from '@/schema/money';

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
  const transactions = ref<TransactionWithAccount[]>([]);
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

  const updateLocalTransactions = async (params: any = {}) => {
    try {
      const { rows } = await MoneyDb.listTransactionsWithAccountPaged(params);
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
    account: Omit<Account, 'serialNum' | 'createdAt' | 'updatedAt'>,
  ): Promise<Account> => {
    loading.value = true;
    error.value = null;

    try {
      const newAccount: Account = {
        ...account,
        serialNum: uuid(38),
        createdAt: DateUtils.getLocalISODateTimeWithOffset(),
        updatedAt: null,
      };
      await MoneyDb.createAccount(newAccount);
      await updateLocalAccounts();
      return newAccount;
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

  const updateAccount = async (account: Account): Promise<Account> => {
    loading.value = true;
    error.value = null;

    try {
      await MoneyDb.updateAccount(account);
      await updateLocalAccounts();
      return account;
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

  const toggleAccountActive = async (serialNum: string): Promise<void> => {
    loading.value = true;
    error.value = null;

    try {
      const account = accounts.value.find(a => a.serialNum === serialNum);
      if (!account) {
        const err = new MoneyStoreError(
          MoneyStoreErrorCode.ACCOUNT_NOT_FOUND,
          `账户不存在: ${serialNum}`,
          { serialNum },
        );
        err.log();
        throw err;
      }

      const newIsActive = !account.isActive;

      await MoneyDb.updateAccountActive(serialNum, newIsActive);

      account.isActive = newIsActive;
      account.updatedAt = DateUtils.getLocalISODateTimeWithOffset();
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

  // 交易相关方法
  const getTransactions = async (
    params: {
      page?: number;
      pageSize?: number;
      type?: TransactionType;
      category?: Category;
      accountSerialNum?: string;
      dateFrom?: string;
      dateTo?: string;
    } = {},
  ): Promise<{
    items: TransactionWithAccount[];
    total: number;
    page: number;
    pageSize: number;
  }> => {
    loading.value = true;
    error.value = null;

    try {
      const filters: any = {};
      if (params.type) filters.transactionType = params.type;
      if (params.category) {
        filters.category = params.category;
      }
      if (params.accountSerialNum)
        filters.accountSerialNum = params.accountSerialNum;
      if (params.dateFrom || params.dateTo) {
        filters.dateRange = { start: params.dateFrom, end: params.dateTo };
      }

      const page = params.page || 1;
      const pageSize = params.pageSize || 20;

      const result = await MoneyDb.listTransactionsWithAccountPaged(
        filters,
        page,
        pageSize,
        { sortBy: 'date', sortDir: 'DESC' },
      );
      transactions.value = result.rows;

      return {
        items: result.rows,
        total: result.totalCount,
        page: result.currentPage,
        pageSize: result.pageSize,
      };
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
    transaction: Omit<TransactionWithAccount, 'createdAt' | 'updatedAt'>,
  ): Promise<TransactionWithAccount> => {
    loading.value = true;
    error.value = null;
    const serialNum = transaction.serialNum || uuid(38);
    try {
      const newTransaction: TransactionWithAccount = {
        ...transaction,
        serialNum,
        createdAt: DateUtils.getLocalISODateTimeWithOffset(),
        updatedAt: null,
      };
      await MoneyDb.createTransaction(newTransaction);
      await updateAccountBalance(
        newTransaction.accountSerialNum,
        newTransaction.transactionType,
        newTransaction.amount,
      );
      await updateLocalTransactions();
      return newTransaction;
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
    transaction: TransactionWithAccount,
  ): Promise<TransactionWithAccount> => {
    loading.value = true;
    error.value = null;

    try {
      const oldTransaction = await MoneyDb.getTransactionWithAccount(
        transaction.serialNum,
      );
      if (!oldTransaction) {
        const err = new MoneyStoreError(
          MoneyStoreErrorCode.TRANSACTION_NOT_FOUND,
          `交易不存在: ${transaction.serialNum}`,
          { serialNum: transaction.serialNum },
        );
        err.log();
        throw err;
      }

      await updateAccountBalance(
        oldTransaction.accountSerialNum,
        oldTransaction.transactionType,
        -oldTransaction.amount,
      );

      await MoneyDb.updateTransaction(transaction);

      await updateAccountBalance(
        transaction.accountSerialNum,
        transaction.transactionType,
        transaction.amount,
      );

      await updateLocalTransactions();
      return transaction;
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

  const updateTransferToTransaction = async (
    transaction: TransactionWithAccount,
  ) => {
    loading.value = true;
    error.value = null;

    try {
      if (!transaction.relatedTransactionSerialNum) {
        const err = new MoneyStoreError(
          MoneyStoreErrorCode.RELATED_TRANSACTION_NOT_FOUND,
          '未找到关联的转账交易',
          { serialNum: transaction.serialNum },
        );
        err.log();
        throw err;
      }
      const relatedTransactions =
        await MoneyDb.getTransferRelatedTransactionWithAccount(
          transaction.relatedTransactionSerialNum,
        );
      if (!relatedTransactions) {
        const err = new MoneyStoreError(
          MoneyStoreErrorCode.RELATED_TRANSACTION_NOT_FOUND,
          '未找到关联的转账交易',
          { serialNum: transaction.relatedTransactionSerialNum },
        );
        err.log();
        throw err;
      }

      const fromTrans =
        relatedTransactions[0].transactionType ===
          TransactionTypeSchema.enum.Expense
          ? relatedTransactions[0]
          : relatedTransactions[1];
      const toTrans =
        relatedTransactions[0].transactionType ===
          TransactionTypeSchema.enum.Income
          ? relatedTransactions[0]
          : relatedTransactions[1];

      await updateAccountBalance(
        fromTrans.accountSerialNum,
        fromTrans.transactionType,
        -fromTrans.amount,
      );
      await updateAccountBalance(
        toTrans.accountSerialNum,
        toTrans.transactionType,
        -toTrans.amount,
      );

      await MoneyDb.executeInTransaction(async () => {
        await updateAccountBalance(
          fromTrans.account.serialNum,
          fromTrans.transactionType,
          -fromTrans.amount,
        );
        await updateAccountBalance(
          toTrans.account.serialNum,
          toTrans.transactionType,
          -toTrans.amount,
        );

        const updatedRelatedTransaction: TransactionWithAccount = {
          ...toTrans,
          amount: transaction.amount,
          currency: transaction.currency,
          description: transaction.description,
          notes: transaction.notes,
          category: transaction.category,
          subCategory: transaction.subCategory,
          paymentMethod: transaction.paymentMethod,
          transactionType:
            transaction.transactionType === 'Expense' ? 'Income' : 'Expense',
          updatedAt: DateUtils.getLocalISODateTimeWithOffset(),
        };
        await MoneyDb.updateTransaction(transaction);
        await MoneyDb.updateTransaction(updatedRelatedTransaction);

        await updateAccountBalance(
          transaction.accountSerialNum,
          transaction.transactionType,
          transaction.amount,
        );
        await updateAccountBalance(
          updatedRelatedTransaction.accountSerialNum,
          updatedRelatedTransaction.transactionType,
          updatedRelatedTransaction.amount,
        );
      });

      await updateLocalTransactions();
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

  const getTransferRelatedTransactionWithAccountOrThrow = async (
    releatedSerialNum: string,
    errorMsg: string,
  ): Promise<TransactionWithAccount[]> => {
    try {
      const trans =
        await MoneyDb.getTransferRelatedTransactionWithAccount(
          releatedSerialNum,
        );
      if (!trans) {
        const err = new MoneyStoreError(
          MoneyStoreErrorCode.RELATED_TRANSACTION_NOT_FOUND,
          errorMsg,
          { releatedSerialNum },
        );
        err.log();
        throw err;
      }
      return trans;
    } catch (err) {
      throw handleMoneyStoreError(
        err,
        errorMsg,
        'getTransferRelatedTransaction',
        'Transaction',
      );
    }
  };

  const deleteTransferTransaction = async (
    relatedTransactionSerialNum: string,
  ) => {
    loading.value = true;
    error.value = null;

    try {
      const relatedTransactions =
        await getTransferRelatedTransactionWithAccountOrThrow(
          relatedTransactionSerialNum,
          '交易不存在',
        );
      if (relatedTransactions.length !== 2) {
        throw handleMoneyStoreError(
          '',
          '无法删除转账交易',
          'deleteTransferTransaction',
          'Transaction',
        );
      }

      const fromTrans =
        relatedTransactions[0].transactionType ===
          TransactionTypeSchema.enum.Expense
          ? relatedTransactions[0]
          : relatedTransactions[1];
      const toTrans =
        relatedTransactions[0].transactionType ===
          TransactionTypeSchema.enum.Income
          ? relatedTransactions[0]
          : relatedTransactions[1];

      const operations = MoneyDb.buildDeleteTransferOperations(
        fromTrans,
        toTrans,
      );
      await MoneyDb.executeBatch(operations);
      await updateLocalTransactions();
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

  const getTransferRelatedTransaction = async (
    serialNum: string,
  ): Promise<TransactionWithAccount[] | null> => {
    loading.value = true;
    error.value = null;

    try {
      const relatedTransaction =
        await MoneyDb.getTransferRelatedTransactionWithAccount(serialNum);
      return relatedTransaction;
    } catch (err) {
      throw handleMoneyStoreError(
        err,
        '获取关联转账交易失败',
        'getTransferRelatedTransaction',
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
      const transaction = await MoneyDb.getTransactionWithAccount(serialNum);
      if (!transaction) {
        const err = new MoneyStoreError(
          MoneyStoreErrorCode.TRANSACTION_NOT_FOUND,
          `交易不存在: ${serialNum}`,
          { serialNum },
        );
        err.log();
        throw err;
      }

      await updateAccountBalance(
        transaction.accountSerialNum,
        transaction.transactionType,
        -transaction.amount,
      );

      await MoneyDb.deleteTransaction(serialNum);
      await updateLocalTransactions();
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

  const createBudget = async (
    budget: Omit<Budget, 'serialNum' | 'createdAt' | 'updatedAt'>,
  ): Promise<Budget> => {
    loading.value = true;
    error.value = null;

    try {
      const newBudget: Budget = {
        ...budget,
        serialNum: uuid(38),
        createdAt: new Date().toISOString(),
        updatedAt: null,
      };
      await MoneyDb.createBudget(newBudget);
      await updateLocalBudgets();
      return newBudget;
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

  const updateBudget = async (budget: Budget): Promise<Budget> => {
    loading.value = true;
    error.value = null;

    try {
      await MoneyDb.updateBudget(budget);
      await updateLocalBudgets();
      return budget;
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

  const toggleBudgetActive = async (serialNum: string): Promise<void> => {
    loading.value = true;
    error.value = null;

    try {
      const budget = budgets.value.find(b => b.serialNum === serialNum);
      if (!budget) {
        const err = new MoneyStoreError(
          MoneyStoreErrorCode.NOT_FOUND,
          `预算不存在: ${serialNum}`,
          { serialNum },
        );
        err.log();
        throw err;
      }
      budget.isActive = !budget.isActive;
      budget.updatedAt = new Date().toISOString();
      await MoneyDb.updateBudget(budget);
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
    reminder: Omit<BilReminder, 'serialNum' | 'createdAt' | 'updatedAt'>,
  ): Promise<BilReminder> => {
    loading.value = true;
    error.value = null;

    try {
      const newReminder: BilReminder = {
        ...reminder,
        serialNum: uuid(38),
        createdAt: new Date().toISOString(),
        updatedAt: null,
      };
      await MoneyDb.createBilReminder(newReminder);
      await updateLocalReminders();
      return newReminder;
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
    reminder: BilReminder,
  ): Promise<BilReminder> => {
    loading.value = true;
    error.value = null;

    try {
      await MoneyDb.updateBilReminder(reminder);
      await updateLocalReminders();
      return reminder;
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

  const markReminderPaid = async (serialNum: string): Promise<void> => {
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
      await MoneyDb.updateBilReminder(reminder);
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
  async function updateAccountBalance(
    accountSerialNum: string,
    transactionType: TransactionType,
    amount: number,
  ): Promise<void> {
    const account = await MoneyDb.getAccount(accountSerialNum);
    if (!account) {
      const err = new MoneyStoreError(
        MoneyStoreErrorCode.ACCOUNT_NOT_FOUND,
        `账户不存在: ${accountSerialNum}`,
        { accountSerialNum },
      );
      err.log();
      throw err;
    }

    const currentBalance = Number.parseFloat(account.balance);
    const initialBalance = Number.parseFloat(account.initialBalance);

    let newBalance: number;

    switch (transactionType) {
      case TransactionTypeSchema.enum.Income:
        newBalance = currentBalance + amount;
        break;
      case TransactionTypeSchema.enum.Expense:
        newBalance = currentBalance - amount;
        break;
      case TransactionTypeSchema.enum.Transfer:
        newBalance = currentBalance - amount;
        break;
      default: {
        const err = new MoneyStoreError(
          MoneyStoreErrorCode.INVALID_TRANSACTION_TYPE,
          `无效的交易类型: ${transactionType}`,
          { transactionType },
        );
        err.log();
        throw err;
      }
    }

    if (account.type === 'CreditCard') {
      if (newBalance < 0) {
        const err = new MoneyStoreError(
          MoneyStoreErrorCode.CREDIT_CARD_BALANCE_INVALID,
          '信用卡余额不能低于0',
          { newBalance },
        );
        err.log();
        throw err;
      }
      if (newBalance > initialBalance) {
        const err = new MoneyStoreError(
          MoneyStoreErrorCode.CREDIT_CARD_BALANCE_INVALID,
          `信用卡余额不能超过初始余额 ${initialBalance}`,
          { newBalance, initialBalance },
        );
        err.log();
        throw err;
      }
    }

    account.balance = newBalance.toFixed(2);
    account.updatedAt = new Date().toISOString();
    try {
      await MoneyDb.updateAccount(account);
    } catch (err) {
      handleMoneyStoreError(
        err,
        '更新账户余额失败',
        'updateAccount',
        'Account',
      );
    }
  }

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
    createTransaction,
    updateTransaction,
    deleteTransaction,
    updateTransferToTransaction,
    deleteTransferTransaction,
    getTransferRelatedTransaction,
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
