// stores/moneyStore.ts

import {
  CategorySchema,
  SubCategorySchema,
  TransactionStatusSchema,
  TransactionType,
  TransactionTypeSchema,
} from '@/schema/common';
import {
  Account,
  AccountTypeSchema,
  BilReminder,
  Budget,
  TransactionWithAccount,
} from '@/schema/money';
import { uuid } from '@/utils/uuid';
import { defineStore } from 'pinia';

// 模拟数据生成器
const generateSerialNum = () => uuid(38);

const mockAccounts: Account[] = [
  {
    serialNum: generateSerialNum(),
    name: '招商银行',
    type: AccountTypeSchema.enum.Bank,
    description: '日常消费账户',
    balance: '15680.50',
    currency: { code: 'CNY', symbol: 'CNY' },
    isShared: false,
    ownerId: 'USER001',
    isActive: true,
    createdAt: '2024-01-15T10:30:00.000Z',
    updatedAt: '2024-12-01T15:20:00.000Z',
  },
  {
    serialNum: generateSerialNum(),
    name: '支付宝',
    type: AccountTypeSchema.enum.Alipay,
    description: '移动支付账户',
    balance: '2340.80',
    currency: { code: 'CNY', symbol: 'CNY' },
    isShared: false,
    ownerId: 'USER001',
    isActive: true,
    createdAt: '2024-01-20T09:15:00.000Z',
    updatedAt: '2024-12-01T12:10:00.000Z',
  },
  {
    serialNum: generateSerialNum(),
    name: '建设银行',
    type: AccountTypeSchema.enum.CreditCard,
    description: '信用卡账户',
    balance: '-1200.00',
    currency: { code: 'CNY', symbol: 'CNY' },
    isShared: false,
    ownerId: 'USER001',
    isActive: true,
    createdAt: '2024-02-01T14:45:00.000Z',
    updatedAt: '2024-12-01T16:30:00.000Z',
  },
  {
    serialNum: generateSerialNum(),
    name: '现金',
    type: AccountTypeSchema.enum.Cash,
    description: '现金账户',
    balance: '500.00',
    currency: { code: 'CNY', symbol: 'CNY' },
    isShared: false,
    ownerId: 'USER001',
    isActive: true,
    createdAt: '2024-01-10T08:00:00.000Z',
    updatedAt: '2024-12-01T18:00:00.000Z',
  },
];

const mockTransactions: TransactionWithAccount[] = [
  {
    serialNum: generateSerialNum(),
    transactionType: TransactionTypeSchema.enum.Expense,
    transactionStatus: TransactionStatusSchema.enum.Completed,
    date: '2024-12-01',
    amount: '45.60',
    currency: 'CNY',
    description: '午餐',
    notes: '公司附近餐厅',
    accountSerialNum: mockAccounts[0].serialNum,
    account: mockAccounts[0],
    category: 'Food',
    subCategory: SubCategorySchema.enum.Bonus,
    tags: [],
    splitMembers: [],
    paymentMethod: 'WeChat',
    actualPayerAccount: 'Bank',
    createdAt: '2024-12-01T12:30:00.000Z',
    updatedAt: null,
  },
  {
    serialNum: generateSerialNum(),
    transactionType: TransactionTypeSchema.enum.Expense,
    transactionStatus: TransactionStatusSchema.enum.Completed,
    date: '2024-12-01',
    amount: '8500.00',
    currency: 'CNY',
    description: '工资',
    notes: '12月份工资',
    accountSerialNum: mockAccounts[1].serialNum,
    account: mockAccounts[1],
    category: 'Salary',
    subCategory: null,
    tags: [],
    splitMembers: [],
    paymentMethod: 'BankTransfer',
    actualPayerAccount: 'Bank',
    createdAt: '2024-12-01T09:00:00.000Z',
    updatedAt: null,
  },
  {
    serialNum: generateSerialNum(),
    transactionType: TransactionTypeSchema.enum.Expense,
    transactionStatus: TransactionStatusSchema.enum.Completed,
    date: '2024-12-01',
    amount: '128.00',
    currency: 'CNY',
    description: '加油',
    notes: '中石化加油站',
    accountSerialNum: mockAccounts[2].serialNum,
    account: mockAccounts[2],
    category: CategorySchema.enum.Others,
    subCategory: 'Fuel',
    tags: [],
    splitMembers: [],
    paymentMethod: 'CreditCard',
    actualPayerAccount: 'CreditCard',
    createdAt: '2024-12-01T08:15:00.000Z',
    updatedAt: null,
  },
  {
    serialNum: 'TXN004',
    transactionType: TransactionTypeSchema.enum.Expense,
    transactionStatus: TransactionStatusSchema.enum.Completed,
    date: '2024-11-30',
    amount: '1000.00',
    currency: 'CNY',
    description: '转账到支付宝',
    notes: '补充支付宝余额',
    accountSerialNum: mockAccounts[0].serialNum,
    account: mockAccounts[0],
    category: CategorySchema.enum.Entertainment,
    subCategory: null,
    tags: [],
    splitMembers: [],
    paymentMethod: 'BankTransfer',
    actualPayerAccount: 'Bank',
    createdAt: '2024-11-30T20:00:00.000Z',
    updatedAt: null,
  },
];

const mockBudgets: Budget[] = [
  {
    serialNum: 'BUD001',
    accountSerialNum: 'ACC001',
    name: '餐饮预算',
    description: '餐饮',
    Category: 'Food',
    amount: '1500.00',
    repeatPeriod: { type: 'Monthly', interval: 1, day: 28 },
    startDate: '2024-12-01',
    endDate: '2024-12-31',
    usedAmount: '456.80',
    isActive: true,
    createdAt: '2024-12-01T00:00:00.000Z',
    updatedAt: null,
  },
  {
    serialNum: 'BUD002',
    accountSerialNum: 'ACC001',
    name: '交通预算',
    description: '交通',
    Category: CategorySchema.enum.Transport,
    amount: '800.00',
    repeatPeriod: { type: 'None' },
    startDate: '2024-12-01',
    endDate: '2024-12-31',
    usedAmount: '128.00',
    isActive: true,
    createdAt: '2024-12-01T00:00:00.000Z',
    updatedAt: null,
  },
  {
    serialNum: 'BUD003',
    accountSerialNum: 'ACC001',
    name: '娱乐预算',
    description: '娱乐',
    Category: 'Entertainment',
    amount: '600.00',
    repeatPeriod: { type: 'None' },
    startDate: '2024-12-01',
    endDate: '2024-12-31',
    usedAmount: '0.00',
    isActive: true,
    createdAt: '2024-12-01T00:00:00.000Z',
    updatedAt: null,
  },
];

const mockReminders: BilReminder[] = [
  {
    serialNum: uuid(38),
    name: '信用卡还款',
    description: '还款',
    category: CategorySchema.enum.Salary,
    amount: '2500.00',
    currency: { code: 'CNY', symbol: 'CNY' },
    dueDate: '2024-12-15T00:00:00.000Z',
    billDate: '2024-12-15T00:00:00.000Z',
    remindDate: '2024-12-15T00:00:00.000Z',
    repeatPeriod: { type: 'None' },
    isPaid: false,
    relatedTransactionSerialNum: '',
    createdAt: '2024-12-01T00:00:00.000Z',
    updatedAt: null,
  },
  {
    serialNum: 'REM002',
    name: '房租',
    description: '房租',
    category: CategorySchema.enum.Salary,
    amount: '3200.00',
    currency: { code: 'CNY', symbol: 'CNY' },
    dueDate: '2024-12-05T00:00:00.000Z',
    remindDate: '2024-12-15T00:00:00.000Z',
    billDate: '2024-12-15T00:00:00.000Z',
    repeatPeriod: { type: 'None' },
    isPaid: true,
    relatedTransactionSerialNum: 'TXN005',
    createdAt: '2024-12-01T00:00:00.000Z',
    updatedAt: '2024-12-05T10:30:00.000Z',
  },
  {
    serialNum: 'REM003',
    name: '水电费',
    description: '水电费',
    category: CategorySchema.enum.Salary,
    amount: '180.00',
    currency: { code: 'CNY', symbol: 'CNY' },
    dueDate: '2024-12-20T00:00:00.000Z',
    remindDate: '2024-12-15T00:00:00.000Z',
    billDate: '2024-12-15T00:00:00.000Z',
    repeatPeriod: { type: 'None' },
    isPaid: false,
    relatedTransactionSerialNum: '',
    createdAt: '2024-12-01T00:00:00.000Z',
    updatedAt: null,
  },
];

export const useMoneyStore = defineStore('money', () => {
  // 状态
  const accounts = ref<Account[]>([...mockAccounts]);
  const transactions = ref<TransactionWithAccount[]>([...mockTransactions]);
  const budgets = ref<Budget[]>([...mockBudgets]);
  const reminders = ref<BilReminder[]>([...mockReminders]);

  const loading = ref(false);
  const error = ref<string | null>(null);

  // 计算属性
  const totalBalance = computed(() => {
    return accounts.value
      .filter((account) => account.isActive)
      .reduce((sum, account) => sum + parseFloat(account.balance), 0);
  });

  const activeAccounts = computed(() => {
    return accounts.value.filter((account) => account.isActive);
  });

  const activeBudgets = computed(() => {
    return budgets.value.filter((budget) => budget.isActive);
  });

  const unpaidReminders = computed(() => {
    return reminders.value.filter((reminder) => !reminder.isPaid);
  });

  // 模拟 API 延迟
  const mockDelay = (ms: number = 500) =>
    new Promise((resolve) => setTimeout(resolve, ms));

  // 账户相关方法
  const getAccounts = async (): Promise<Account[]> => {
    loading.value = true;
    error.value = null;

    try {
      await mockDelay();
      return accounts.value;
    } catch (err) {
      error.value = '获取账户列表失败';
      throw err;
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
      await mockDelay();

      const newAccount: Account = {
        ...account,
        serialNum: generateSerialNum(),
        createdAt: new Date().toISOString(),
        updatedAt: null,
      };

      accounts.value.push(newAccount);
      return newAccount;
    } catch (err) {
      error.value = '创建账户失败';
      throw err;
    } finally {
      loading.value = false;
    }
  };

  const updateAccount = async (account: Account): Promise<Account> => {
    loading.value = true;
    error.value = null;

    try {
      await mockDelay();

      const index = accounts.value.findIndex(
        (a) => a.serialNum === account.serialNum,
      );
      if (index === -1) {
        throw new Error('账户不存在');
      }

      const updatedAccount = {
        ...account,
        updatedAt: new Date().toISOString(),
      };

      accounts.value[index] = updatedAccount;
      return updatedAccount;
    } catch (err) {
      error.value = '更新账户失败';
      throw err;
    } finally {
      loading.value = false;
    }
  };

  const deleteAccount = async (serialNum: string): Promise<void> => {
    loading.value = true;
    error.value = null;

    try {
      await mockDelay();

      const index = accounts.value.findIndex((a) => a.serialNum === serialNum);
      if (index === -1) {
        throw new Error('账户不存在');
      }

      accounts.value.splice(index, 1);
    } catch (err) {
      error.value = '删除账户失败';
      throw err;
    } finally {
      loading.value = false;
    }
  };

  const toggleAccountActive = async (serialNum: string): Promise<void> => {
    loading.value = true;
    error.value = null;

    try {
      await mockDelay();

      const account = accounts.value.find((a) => a.serialNum === serialNum);
      if (!account) {
        throw new Error('账户不存在');
      }

      account.isActive = !account.isActive;
      account.updatedAt = new Date().toISOString();
    } catch (err) {
      error.value = '切换账户状态失败';
      throw err;
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
      await mockDelay();

      let filtered = [...transactions.value];

      // 筛选逻辑
      if (params.type) {
        filtered = filtered.filter((t) => t.transactionType === params.type);
      }

      if (params.accountSerialNum) {
        filtered = filtered.filter(
          (t) => t.accountSerialNum === params.accountSerialNum,
        );
      }

      if (params.dateFrom) {
        filtered = filtered.filter((t) => t.date >= params.dateFrom!);
      }

      if (params.dateTo) {
        filtered = filtered.filter((t) => t.date <= params.dateTo!);
      }

      // 排序（按日期倒序）
      filtered.sort(
        (a, b) => new Date(b.date).getTime() - new Date(a.date).getTime(),
      );

      // 分页
      const page = params.page || 1;
      const pageSize = params.pageSize || 20;
      const start = (page - 1) * pageSize;
      const end = start + pageSize;
      const items = filtered.slice(start, end);

      return {
        items,
        total: filtered.length,
        page,
        pageSize,
      };
    } catch (err) {
      error.value = '获取交易列表失败';
      throw err;
    } finally {
      loading.value = false;
    }
  };

  const createTransaction = async (
    transaction: Omit<
      TransactionWithAccount,
      'serialNum' | 'createdAt' | 'updatedAt'
    >,
  ): Promise<TransactionWithAccount> => {
    loading.value = true;
    error.value = null;

    try {
      await mockDelay();

      const newTransaction: TransactionWithAccount = {
        ...transaction,
        serialNum: generateSerialNum(),
        createdAt: new Date().toISOString(),
        updatedAt: null,
      };

      transactions.value.push(newTransaction);

      // 更新账户余额
      await updateAccountBalance(
        transaction.accountSerialNum,
        transaction.transactionType,
        parseFloat(transaction.amount),
      );

      return newTransaction;
    } catch (err) {
      error.value = '创建交易失败';
      throw err;
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
      await mockDelay();

      const index = transactions.value.findIndex(
        (t) => t.serialNum === transaction.serialNum,
      );
      if (index === -1) {
        throw new Error('交易不存在');
      }

      const oldTransaction = transactions.value[index];

      // 恢复旧交易对账户余额的影响
      await updateAccountBalance(
        oldTransaction.accountSerialNum,
        oldTransaction.transactionType,
        -parseFloat(oldTransaction.amount),
      );

      const updatedTransaction = {
        ...transaction,
        updatedAt: new Date().toISOString(),
      };

      transactions.value[index] = updatedTransaction;

      // 应用新交易对账户余额的影响
      await updateAccountBalance(
        transaction.accountSerialNum,
        transaction.transactionType,
        parseFloat(transaction.amount),
      );

      return updatedTransaction;
    } catch (err) {
      error.value = '更新交易失败';
      throw err;
    } finally {
      loading.value = false;
    }
  };

  const deleteTransaction = async (serialNum: string): Promise<void> => {
    loading.value = true;
    error.value = null;

    try {
      await mockDelay();

      const index = transactions.value.findIndex(
        (t) => t.serialNum === serialNum,
      );
      if (index === -1) {
        throw new Error('交易不存在');
      }

      const transaction = transactions.value[index];

      // 恢复交易对账户余额的影响
      await updateAccountBalance(
        transaction.accountSerialNum,
        transaction.transactionType,
        -parseFloat(transaction.amount),
      );

      transactions.value.splice(index, 1);
    } catch (err) {
      error.value = '删除交易失败';
      throw err;
    } finally {
      loading.value = false;
    }
  };

  // 预算相关方法
  const getBudgets = async (): Promise<Budget[]> => {
    loading.value = true;
    error.value = null;

    try {
      await mockDelay();
      return budgets.value;
    } catch (err) {
      error.value = '获取预算列表失败';
      throw err;
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
      await mockDelay();

      const newBudget: Budget = {
        ...budget,
        serialNum: generateSerialNum(),
        createdAt: new Date().toISOString(),
        updatedAt: null,
      };

      budgets.value.push(newBudget);
      return newBudget;
    } catch (err) {
      error.value = '创建预算失败';
      throw err;
    } finally {
      loading.value = false;
    }
  };

  const updateBudget = async (budget: Budget): Promise<Budget> => {
    loading.value = true;
    error.value = null;

    try {
      await mockDelay();

      const index = budgets.value.findIndex(
        (b) => b.serialNum === budget.serialNum,
      );
      if (index === -1) {
        throw new Error('预算不存在');
      }

      const updatedBudget = {
        ...budget,
        updatedAt: new Date().toISOString(),
      };

      budgets.value[index] = updatedBudget;
      return updatedBudget;
    } catch (err) {
      error.value = '更新预算失败';
      throw err;
    } finally {
      loading.value = false;
    }
  };

  const deleteBudget = async (serialNum: string): Promise<void> => {
    loading.value = true;
    error.value = null;

    try {
      await mockDelay();

      const index = budgets.value.findIndex((b) => b.serialNum === serialNum);
      if (index === -1) {
        throw new Error('预算不存在');
      }

      budgets.value.splice(index, 1);
    } catch (err) {
      error.value = '删除预算失败';
      throw err;
    } finally {
      loading.value = false;
    }
  };

  const toggleBudgetActive = async (serialNum: string): Promise<void> => {
    loading.value = true;
    error.value = null;

    try {
      await mockDelay();

      const budget = budgets.value.find((b) => b.serialNum === serialNum);
      if (!budget) {
        throw new Error('预算不存在');
      }

      budget.isActive = !budget.isActive;
      budget.updatedAt = new Date().toISOString();
    } catch (err) {
      error.value = '切换预算状态失败';
      throw err;
    } finally {
      loading.value = false;
    }
  };

  // 提醒相关方法
  const getReminders = async (): Promise<BilReminder[]> => {
    loading.value = true;
    error.value = null;

    try {
      await mockDelay();
      return reminders.value;
    } catch (err) {
      error.value = '获取提醒列表失败';
      throw err;
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
      await mockDelay();

      const newReminder: BilReminder = {
        ...reminder,
        serialNum: generateSerialNum(),
        createdAt: new Date().toISOString(),
        updatedAt: null,
      };

      reminders.value.push(newReminder);
      return newReminder;
    } catch (err) {
      error.value = '创建提醒失败';
      throw err;
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
      await mockDelay();

      const index = reminders.value.findIndex(
        (r) => r.serialNum === reminder.serialNum,
      );
      if (index === -1) {
        throw new Error('提醒不存在');
      }

      const updatedReminder = {
        ...reminder,
        updatedAt: new Date().toISOString(),
      };

      reminders.value[index] = updatedReminder;
      return updatedReminder;
    } catch (err) {
      error.value = '更新提醒失败';
      throw err;
    } finally {
      loading.value = false;
    }
  };

  const deleteReminder = async (serialNum: string): Promise<void> => {
    loading.value = true;
    error.value = null;

    try {
      await mockDelay();

      const index = reminders.value.findIndex((r) => r.serialNum === serialNum);
      if (index === -1) {
        throw new Error('提醒不存在');
      }

      reminders.value.splice(index, 1);
    } catch (err) {
      error.value = '删除提醒失败';
      throw err;
    } finally {
      loading.value = false;
    }
  };

  const markReminderPaid = async (serialNum: string): Promise<void> => {
    loading.value = true;
    error.value = null;

    try {
      await mockDelay();

      const reminder = reminders.value.find((r) => r.serialNum === serialNum);
      if (!reminder) {
        throw new Error('提醒不存在');
      }

      reminder.isPaid = true;
      reminder.updatedAt = new Date().toISOString();
    } catch (err) {
      error.value = '标记支付状态失败';
      throw err;
    } finally {
      loading.value = false;
    }
  };

  // 辅助方法
  const updateAccountBalance = async (
    accountSerialNum: string,
    transactionType: TransactionType,
    amount: number,
  ): Promise<void> => {
    const account = accounts.value.find(
      (a) => a.serialNum === accountSerialNum,
    );
    if (!account) {
      throw new Error('账户不存在');
    }

    let currentBalance = parseFloat(account.balance);

    switch (transactionType) {
      case TransactionTypeSchema.enum.Income:
        currentBalance += amount;
        break;
      case TransactionTypeSchema.enum.Expense:
        currentBalance -= amount;
        break;
      case TransactionTypeSchema.enum.Transfer:
        // 转账需要特殊处理，这里简化为支出
        currentBalance -= amount;
        break;
    }

    account.balance = currentBalance.toFixed(2);
    account.updatedAt = new Date().toISOString();
  };

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
