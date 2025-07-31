// stores/moneyStore.ts

import { defineStore } from 'pinia';
import { TransactionTypeSchema } from '@/schema/common';
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

  // 辅助方法
  const updateLocalAccounts = async () => {
    try {
      const accountList = await MoneyDb.listAccounts();
      accounts.value = accountList;
    }
    catch (err) {
      error.value = '获取账户列表失败';
      throw err;
    }
  };

  const updateLocalTransactions = async (params: any = {}) => {
    try {
      const { rows } = await MoneyDb.listTransactionsWithAccountPaged(params);
      transactions.value = rows;
    }
    catch (err) {
      error.value = '获取交易列表失败';
      throw err;
    }
  };

  const updateLocalBudgets = async () => {
    try {
      const budgetList = await MoneyDb.listBudgets();
      budgets.value = budgetList;
    }
    catch (err) {
      error.value = '获取预算列表失败';
      throw err;
    }
  };

  const updateLocalReminders = async () => {
    try {
      const reminderList = await MoneyDb.listBilReminders();
      reminders.value = reminderList;
    }
    catch (err) {
      error.value = '获取提醒列表失败';
      throw err;
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
    }
    catch (err) {
      error.value = '获取账户列表失败';
      throw err;
    }
    finally {
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
    }
    catch (err) {
      error.value = '创建账户失败';
      throw err;
    }
    finally {
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
    }
    catch (err) {
      error.value = '更新账户失败';
      throw err;
    }
    finally {
      loading.value = false;
    }
  };

  const deleteAccount = async (serialNum: string): Promise<void> => {
    loading.value = true;
    error.value = null;

    try {
      await MoneyDb.deleteAccount(serialNum);
      await updateLocalAccounts();
    }
    catch (err) {
      error.value = '删除账户失败';
      throw err;
    }
    finally {
      loading.value = false;
    }
  };

  const toggleAccountActive = async (serialNum: string): Promise<void> => {
    loading.value = true;
    error.value = null;

    try {
      const account = accounts.value.find(a => a.serialNum === serialNum);
      if (!account) {
        throw new Error('账户不存在');
      }

      const newIsActive = !account.isActive;

      // 1. 更新数据库中的 isActive 字段
      await MoneyDb.updateAccountActive(serialNum, newIsActive);

      // 2. 更新本地数据状态（可选地更新本地对象）
      account.isActive = newIsActive;
      account.updatedAt = DateUtils.getLocalISODateTimeWithOffset();

      // 3. 如果你还需要从数据库重新拉取所有账户：
      // await updateLocalAccounts();
    }
    catch (err) {
      error.value = '切换账户状态失败';
      throw err;
    }
    finally {
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
    }
    catch (err) {
      error.value = '获取交易列表失败';
      throw err;
    }
    finally {
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
    }
    catch (err) {
      error.value = '创建交易失败';
      throw err;
    }
    finally {
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
        throw new Error('交易不存在');
      }

      // 恢复旧交易对账户余额的影响
      await updateAccountBalance(
        oldTransaction.accountSerialNum,
        oldTransaction.transactionType,
        -oldTransaction.amount,
      );

      await MoneyDb.updateTransaction(transaction);

      // 应用新交易对账户余额的影响
      await updateAccountBalance(
        transaction.accountSerialNum,
        transaction.transactionType,
        transaction.amount,
      );

      await updateLocalTransactions();
      return transaction;
    }
    catch (err) {
      error.value = '更新交易失败';
      throw err;
    }
    finally {
      loading.value = false;
    }
  };

  const updateTransferToTransaction = async (
    transaction: TransactionWithAccount,
  ) => {
    loading.value = true;
    error.value = null;

    try {
      // 获取与转账相关的另一笔交易

      if (!transaction.relatedTransactionSerialNum) {
        throw new Error('未找到关联的转账交易');
      }
      const relatedTransaction =
        await MoneyDb.getTransferRelatedTransactionWithAccount(
          transaction.relatedTransactionSerialNum,
        );
      if (!relatedTransaction) {
        throw new Error('未找到关联的转账交易');
      }

      // 获取旧交易以恢复余额
      const oldTransaction = await MoneyDb.getTransactionWithAccount(
        transaction.serialNum,
      );
      const oldRelatedTransaction = await MoneyDb.getTransactionWithAccount(
        relatedTransaction.serialNum,
      );
      if (!oldTransaction || !oldRelatedTransaction) {
        throw new Error('交易记录不存在');
      }

      // 恢复旧交易对账户余额的影响
      await updateAccountBalance(
        oldTransaction.accountSerialNum,
        oldTransaction.transactionType,
        -oldTransaction.amount,
      );
      await updateAccountBalance(
        oldRelatedTransaction.accountSerialNum,
        oldRelatedTransaction.transactionType,
        -oldRelatedTransaction.amount,
      );

      // 在事务中更新两笔交易
      await MoneyDb.executeInTransaction(async () => {
        // 3.1 恢复旧余额
        await updateAccountBalance(
          oldTransaction.accountSerialNum,
          oldTransaction.transactionType,
          -oldTransaction.amount,
        );
        await updateAccountBalance(
          oldRelatedTransaction.accountSerialNum,
          oldRelatedTransaction.transactionType,
          -oldRelatedTransaction.amount,
        );

        // 3.2 构造并更新关联交易
        const updatedRelatedTransaction: TransactionWithAccount = {
          ...relatedTransaction,
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

        // 3.3 更新新余额
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
    }
    catch (err) {
      error.value = '更新转账交易失败';
      throw err;
    }
    finally {
      loading.value = false;
    }
  };
  const deleteTransferTransaction = async (
    fromSerialNum: string,
    toSerialNum?: string,
  ) => {
    loading.value = true;
    error.value = null;

    try {
      await MoneyDb.executeInTransaction(async () => {
        // 如果未提供 toSerialNum，尝试查找相关交易
        let toTransactionSerialNum = toSerialNum;
        if (!toTransactionSerialNum) {
          const relatedTransaction =
            await MoneyDb.getTransferRelatedTransaction(fromSerialNum);
          toTransactionSerialNum = relatedTransaction?.serialNum;
        }

        // 获取转出和转入交易
        const fromTransaction =
          await MoneyDb.getTransactionWithAccount(fromSerialNum);
        if (!fromTransaction) {
          throw new Error('转出交易不存在');
        }

        // 恢复转出交易对账户余额的影响
        await updateAccountBalance(
          fromTransaction.accountSerialNum,
          fromTransaction.transactionType,
          -fromTransaction.amount,
        );

        // 删除转出交易
        await MoneyDb.deleteTransaction(fromSerialNum);

        // 如果存在转入交易，处理其余额并删除
        if (toTransactionSerialNum) {
          const toTransaction = await MoneyDb.getTransactionWithAccount(
            toTransactionSerialNum,
          );
          if (toTransaction) {
            await updateAccountBalance(
              toTransaction.accountSerialNum,
              toTransaction.transactionType,
              -toTransaction.amount,
            );
            await MoneyDb.deleteTransaction(toTransactionSerialNum);
          }
        }
      });

      await updateLocalTransactions();
    }
    catch (err) {
      error.value = '删除转账交易失败';
      throw err;
    }
    finally {
      loading.value = false;
    }
  };
  // 3. 获取转账关联的交易记录
  const getTransferRelatedTransaction = async (
    serialNum: string,
  ): Promise<TransactionWithAccount | null> => {
    // 根据转账关联ID查找对应的转入/转出交易记录
    // 实现逻辑依赖于数据库设计
    loading.value = true;
    error.value = null;

    try {
      const relatedTransaction =
        await MoneyDb.getTransferRelatedTransactionWithAccount(serialNum);
      return relatedTransaction;
    }
    catch (err) {
      error.value = '获取关联转账交易失败';
      throw err;
    }
    finally {
      loading.value = false;
    }
  };
  const deleteTransaction = async (serialNum: string): Promise<void> => {
    loading.value = true;
    error.value = null;

    try {
      const transaction = await MoneyDb.getTransactionWithAccount(serialNum);
      if (!transaction) {
        throw new Error('交易不存在');
      }

      // 恢复交易对账户余额的影响
      await updateAccountBalance(
        transaction.accountSerialNum,
        transaction.transactionType,
        -transaction.amount,
      );

      await MoneyDb.deleteTransaction(serialNum);
      await updateLocalTransactions();
    }
    catch (err) {
      error.value = '删除交易失败';
      throw err;
    }
    finally {
      loading.value = false;
    }
  };

  // 本月支出收入
  const monthlyIncomeAndExpense = async (): Promise<IncomeExpense> => {
    return await MoneyDb.monthlyIncomeAndExpense();
  };

  // 预算相关方法
  const getBudgets = async (): Promise<Budget[]> => {
    loading.value = true;
    error.value = null;

    try {
      const budgetList = await MoneyDb.listBudgets();
      budgets.value = budgetList;
      return budgetList;
    }
    catch (err) {
      error.value = '获取预算列表失败';
      throw err;
    }
    finally {
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
    }
    catch (err) {
      error.value = '创建预算失败';
      throw err;
    }
    finally {
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
    }
    catch (err) {
      error.value = '更新预算失败';
      throw err;
    }
    finally {
      loading.value = false;
    }
  };

  const deleteBudget = async (serialNum: string): Promise<void> => {
    loading.value = true;
    error.value = null;

    try {
      await MoneyDb.deleteBudget(serialNum);
      await updateLocalBudgets();
    }
    catch (err) {
      error.value = '删除预算失败';
      throw err;
    }
    finally {
      loading.value = false;
    }
  };

  const toggleBudgetActive = async (serialNum: string): Promise<void> => {
    loading.value = true;
    error.value = null;

    try {
      const budget = budgets.value.find(b => b.serialNum === serialNum);
      if (!budget) {
        throw new Error('预算不存在');
      }
      budget.isActive = !budget.isActive;
      budget.updatedAt = new Date().toISOString();
      await MoneyDb.updateBudget(budget);
      await updateLocalBudgets();
    }
    catch (err) {
      error.value = '切换预算状态失败';
      throw err;
    }
    finally {
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
    }
    catch (err) {
      error.value = '获取提醒列表失败';
      throw err;
    }
    finally {
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
    }
    catch (err) {
      error.value = '创建提醒失败';
      throw err;
    }
    finally {
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
    }
    catch (err) {
      error.value = '更新提醒失败';
      throw err;
    }
    finally {
      loading.value = false;
    }
  };

  const deleteReminder = async (serialNum: string): Promise<void> => {
    loading.value = true;
    error.value = null;

    try {
      await MoneyDb.deleteBilReminder(serialNum);
      await updateLocalReminders();
    }
    catch (err) {
      error.value = '删除提醒失败';
      throw err;
    }
    finally {
      loading.value = false;
    }
  };

  const markReminderPaid = async (serialNum: string): Promise<void> => {
    loading.value = true;
    error.value = null;

    try {
      const reminder = reminders.value.find(r => r.serialNum === serialNum);
      if (!reminder) {
        throw new Error('提醒不存在');
      }
      reminder.isPaid = true;
      reminder.updatedAt = new Date().toISOString();
      await MoneyDb.updateBilReminder(reminder);
      await updateLocalReminders();
    }
    catch (err) {
      error.value = '标记支付状态失败';
      throw err;
    }
    finally {
      loading.value = false;
    }
  };

  // 辅助方法
  async function updateAccountBalance(
    accountSerialNum: string,
    transactionType: TransactionType,
    amount: number,
  ): Promise<void> {
    const account = accounts.value.find(a => a.serialNum === accountSerialNum);
    if (!account) {
      throw new Error('账户不存在');
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
      default:
        throw new Error('无效的交易类型');
    }

    // Apply restrictions based on account type
    if (account.type === 'CreditCard') {
      // Credit card balance must be between 0 and initialBalance
      if (newBalance < 0) {
        throw new Error('信用卡余额不能低于0');
      }
      if (newBalance > initialBalance) {
        throw new Error(`信用卡余额不能超过初始余额 ${initialBalance}`);
      }
    }

    // Update account balance
    account.balance = newBalance.toFixed(2);
    account.updatedAt = new Date().toISOString();
    await MoneyDb.updateAccount(account);
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
