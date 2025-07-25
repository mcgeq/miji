import { getDb } from '@/db';
import { Lg } from '@/utils/debugLog';
import type {
  Account,
  BilReminder,
  Budget,
  FamilyLedger,
  FamilyMember,
  Transaction,
  TransactionWithAccount,
} from '@/schema/money';
import type Database from '@tauri-apps/plugin-sql';

// 分页查询相关接口
export interface DateRange {
  start?: string;
  end?: string;
}

export interface SortOptions {
  customOrderBy?: string;
  sortBy?: string;
  sortDir?: 'ASC' | 'DESC';
}

export interface PagedResult<T> {
  rows: T[];
  totalCount: number;
  currentPage: number;
  pageSize: number;
  totalPages: number;
}

// 账户查询过滤器
export interface AccountFilters {
  type?: string;
  isActive?: boolean;
  isShared?: boolean;
  ownerId?: string;
  createdAtRange?: DateRange;
  updatedAtRange?: DateRange;
}

// 交易查询过滤器
export interface TransactionFilters {
  transactionType?: string;
  transactionStatus?: string;
  accountSerialNum?: string;
  category?: string;
  subCategory?: string;
  paymentMethod?: string;
  dateRange?: DateRange;
  amountRange?: { min?: number; max?: number };
  createdAtRange?: DateRange;
}

// 预算查询过滤器
export interface BudgetFilters {
  category?: string;
  isActive?: boolean;
  accountSerialNum?: string;
  alertEnabled?: boolean;
  dateRange?: DateRange;
  createdAtRange?: DateRange;
}

// 账单提醒查询过滤器
export interface BilReminderFilters {
  type?: string;
  enabled?: boolean;
  category?: string;
  isPaid?: boolean;
  priority?: string;
  dueDateRange?: DateRange;
  createdAtRange?: DateRange;
}

// Helper function to convert camelCase to snake_case
function toSnakeCase(str: string): string {
  return str.replace(/[A-Z]/g, letter => `_${letter.toLowerCase()}`);
}

// Helper function to compare two values for equality
function isEqual(a: any, b: any): boolean {
  if ((a === null && b === undefined) || (a === undefined && b === null)) {
    return true; // Treat null and undefined as equal for updates
  }
  if (
    typeof a === 'object' &&
    typeof b === 'object' &&
    a !== null &&
    b !== null
  ) {
    return JSON.stringify(a) === JSON.stringify(b);
  }
  return a === b;
}

// Helper function to normalize null/undefined values
function normalizeValue<T>(value: T): T extends null ? undefined : T {
  return (value === null ? undefined : value) as T extends null ? undefined : T;
}

export class MoneyDb {
  private static db: Database;
  private static initializing: boolean = false;
  private static initPromise: Promise<void> | null = null;

  private static async init() {
    if (MoneyDb.db || MoneyDb.initializing) return;
    MoneyDb.initializing = true;
    try {
      MoneyDb.db = await getDb();
    }
    catch (error) {
      Lg.e('MoneyDb', 'Failed to initialize database: ', error);
      throw error;
    }
    finally {
      MoneyDb.initializing = false;
    }
  }

  private static async ensureDb() {
    if (!MoneyDb.db) {
      if (!MoneyDb.initPromise) {
        MoneyDb.initPromise = MoneyDb.init();
      }
      await MoneyDb.initPromise;
    }
  }

  // Account CRUD
  public static async createAccount(account: Account): Promise<void> {
    await MoneyDb.ensureDb();
    const {
      serialNum,
      name,
      description,
      type,
      balance,
      currency,
      isShared,
      ownerId,
      isActive,
      color,
      createdAt,
      updatedAt,
    } = account;
    await MoneyDb.db.execute(
      `INSERT INTO accounts (serial_num, name, description, type, balance, currency, is_shared, owner_id, is_active, color, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        serialNum,
        name,
        description,
        type,
        balance,
        JSON.stringify(currency),
        isShared,
        ownerId,
        isActive,
        color,
        createdAt,
        updatedAt,
      ],
    );
  }

  public static async getAccount(serialNum: string): Promise<Account | null> {
    await MoneyDb.ensureDb();
    const result = await MoneyDb.db.select<any[]>(
      'SELECT * FROM accounts WHERE serial_num = ?',
      [serialNum],
    );
    if (result.length === 0) return null;
    const account = result[0];
    account.currency = JSON.parse(account.currency);
    return account as Account;
  }

  public static async listAccounts(): Promise<Account[]> {
    await MoneyDb.ensureDb();
    const result = await MoneyDb.db.select<any[]>('SELECT * FROM accounts');
    return result.map(a => ({
      ...a,
      currency: JSON.parse(a.currency),
    })) as Account[];
  }

  public static async updateAccount(account: Account): Promise<void> {
    await MoneyDb.ensureDb();
    const {
      serialNum,
      name,
      description,
      type,
      balance,
      currency,
      isShared,
      ownerId,
      isActive,
      color,
      updatedAt,
    } = account;
    await MoneyDb.db.execute(
      `UPDATE accounts SET name = ?, description = ?, type = ?, balance = ?, currency = ?, is_shared = ?, owner_id = ?, is_active = ?, color = ?, updated_at = ?
       WHERE serial_num = ?`,
      [
        name,
        description,
        type,
        balance,
        JSON.stringify(currency),
        isShared,
        ownerId,
        isActive,
        color,
        updatedAt,
        serialNum,
      ],
    );
  }

  public static async deleteAccount(serialNum: string): Promise<void> {
    await MoneyDb.ensureDb();
    await MoneyDb.db.execute('DELETE FROM accounts WHERE serial_num = ?', [
      serialNum,
    ]);
  }

  public static async updateAccountSmart(newAccount: Account): Promise<void> {
    await MoneyDb.ensureDb();
    const oldAccount = await MoneyDb.getAccount(newAccount.serialNum);
    if (!oldAccount) throw new Error('Account not found');

    const updates: Partial<Account> = {};
    for (const key in newAccount) {
      const k = key as keyof Account;
      if (!isEqual(newAccount[k], oldAccount[k])) {
        updates[k] = normalizeValue(newAccount[k]) as any;
      }
    }

    if (Object.keys(updates).length === 0) {
      Lg.i('MoneyDb', 'No changes detected for account');
      return;
    }

    await MoneyDb.updateAccountPartial(newAccount.serialNum, updates);
  }

  public static async updateAccountPartial(
    serialNum: string,
    updates: Partial<Account>,
  ): Promise<void> {
    await MoneyDb.ensureDb();
    const fields: string[] = [];
    const values: any[] = [];

    for (const [key, value] of Object.entries(updates)) {
      const snakeKey = toSnakeCase(key);
      fields.push(`${snakeKey} = ?`);
      if (key === 'currency') {
        values.push(JSON.stringify(value));
      }
      else {
        values.push(value);
      }
    }

    if (fields.length === 0) return;

    values.push(serialNum);
    const sql = `UPDATE accounts SET ${fields.join(', ')} WHERE serial_num = ?`;
    await MoneyDb.db.execute(sql, values);
  }

  // 账户分页查询
  public static async listAccountsPaged(
    filters: AccountFilters = {},
    page = 1,
    pageSize = 10,
    sortOptions: SortOptions = {},
  ): Promise<PagedResult<Account>> {
    await MoneyDb.ensureDb();

    const offset = (page - 1) * pageSize;
    const whereParts: string[] = [];
    const params: any[] = [];

    // 构建过滤条件
    if (filters.type) {
      whereParts.push('type = ?');
      params.push(filters.type);
    }
    if (filters.isActive !== undefined) {
      whereParts.push('is_active = ?');
      params.push(filters.isActive);
    }
    if (filters.isShared !== undefined) {
      whereParts.push('is_shared = ?');
      params.push(filters.isShared);
    }
    if (filters.ownerId) {
      whereParts.push('owner_id = ?');
      params.push(filters.ownerId);
    }

    MoneyDb.appendDateRange(
      'created_at',
      filters.createdAtRange,
      whereParts,
      params,
    );
    MoneyDb.appendDateRange(
      'updated_at',
      filters.updatedAtRange,
      whereParts,
      params,
    );

    const whereClause =
      whereParts.length > 0 ? `WHERE ${whereParts.join(' AND ')}` : '';

    // 构建排序条件
    const orderClause = sortOptions.customOrderBy
      ? `ORDER BY ${sortOptions.customOrderBy}`
      : sortOptions.sortBy
        ? `ORDER BY ${sortOptions.sortBy} ${sortOptions.sortDir ?? 'ASC'}`
        : 'ORDER BY created_at DESC';

    // 查询数据
    const rows = await MoneyDb.db.select<any[]>(
      `SELECT * FROM accounts ${whereClause} ${orderClause} LIMIT ? OFFSET ?`,
      [...params, pageSize, offset],
    );

    // 查询总数
    const totalRes = await MoneyDb.db.select<{ cnt: number }[]>(
      `SELECT COUNT(*) as cnt FROM accounts ${whereClause}`,
      params,
    );

    const totalCount = totalRes[0]?.cnt ?? 0;
    const totalPages = Math.ceil(totalCount / pageSize);

    return {
      rows: rows.map(a => ({
        ...a,
        currency: JSON.parse(a.currency),
      })) as Account[],
      totalCount,
      currentPage: page,
      pageSize,
      totalPages,
    };
  }

  // Transaction CRUD
  public static async createTransaction(
    transaction: Transaction,
  ): Promise<void> {
    await MoneyDb.ensureDb();
    const {
      serialNum,
      transactionType,
      transactionStatus,
      date,
      amount,
      currency,
      description,
      notes,
      accountSerialNum,
      category,
      subCategory,
      tags,
      splitMembers,
      paymentMethod,
      actualPayerAccount,
      createdAt,
      updatedAt,
    } = transaction;
    const tagsJson = JSON.stringify(tags);
    const splitMembersJson = JSON.stringify(splitMembers);
    const currencyJson = JSON.stringify(currency);
    await MoneyDb.db.execute(
      `INSERT INTO transactions (serial_num, transaction_type, transaction_status, date, amount, currency, description, notes, account_serial_num, category, sub_category, tags, split_members, payment_method, actual_payer_account, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        serialNum,
        transactionType,
        transactionStatus,
        date,
        amount,
        currencyJson,
        description,
        notes,
        accountSerialNum,
        category,
        subCategory,
        tagsJson,
        splitMembersJson,
        paymentMethod,
        actualPayerAccount,
        createdAt,
        updatedAt,
      ],
    );
  }

  public static async getTransaction(
    serialNum: string,
  ): Promise<Transaction | null> {
    await MoneyDb.ensureDb();
    const result = await MoneyDb.db.select<any[]>(
      'SELECT * FROM transactions WHERE serial_num = ?',
      [serialNum],
    );
    if (result.length === 0) return null;
    const transaction = result[0];
    transaction.tags = JSON.parse(transaction.tags);
    transaction.split_members = JSON.parse(transaction.split_members);
    transaction.currency = JSON.parse(transaction.currency);
    return transaction as Transaction;
  }

  public static async listTransactions(): Promise<Transaction[]> {
    await MoneyDb.ensureDb();
    const result = await MoneyDb.db.select<any[]>('SELECT * FROM transactions');
    return result.map(t => ({
      ...t,
      tags: JSON.parse(t.tags),
      split_members: JSON.parse(t.split_members),
      currency: JSON.parse(t.currency),
    })) as Transaction[];
  }

  public static async updateTransaction(
    transaction: Transaction,
  ): Promise<void> {
    await MoneyDb.ensureDb();
    const {
      serialNum,
      transactionType,
      transactionStatus,
      date,
      amount,
      currency,
      description,
      notes,
      accountSerialNum,
      category,
      subCategory,
      tags,
      splitMembers,
      paymentMethod,
      actualPayerAccount,
      updatedAt,
    } = transaction;
    const tagsJson = JSON.stringify(tags);
    const splitMembersJson = JSON.stringify(splitMembers);
    const currencyJson = JSON.stringify(currency);
    await MoneyDb.db.execute(
      `UPDATE transactions SET transaction_type = ?, transaction_status = ?, date = ?, amount = ?, currency = ?, description = ?, notes = ?, account_serial_num = ?, category = ?, sub_category = ?, tags = ?, split_members = ?, payment_method = ?, actual_payer_account = ?, updated_at = ?
       WHERE serial_num = ?`,
      [
        transactionType,
        transactionStatus,
        date,
        amount,
        currencyJson,
        description,
        notes,
        accountSerialNum,
        category,
        subCategory,
        tagsJson,
        splitMembersJson,
        paymentMethod,
        actualPayerAccount,
        updatedAt,
        serialNum,
      ],
    );
  }

  public static async deleteTransaction(serialNum: string): Promise<void> {
    await MoneyDb.ensureDb();
    await MoneyDb.db.execute('DELETE FROM transactions WHERE serial_num = ?', [
      serialNum,
    ]);
  }

  public static async updateTransactionSmart(
    newTransaction: Transaction,
  ): Promise<void> {
    await MoneyDb.ensureDb();
    const oldTransaction = await MoneyDb.getTransaction(
      newTransaction.serialNum,
    );
    if (!oldTransaction) throw new Error('Transaction not found');

    const updates: Partial<Transaction> = {};
    for (const key in newTransaction) {
      const k = key as keyof Transaction;
      if (!isEqual(newTransaction[k], oldTransaction[k])) {
        updates[k] = normalizeValue(newTransaction[k]) as any;
      }
    }

    if (Object.keys(updates).length === 0) {
      Lg.i('MoneyDb', 'No changes detected for transaction');
      return;
    }

    await MoneyDb.updateTransactionPartial(newTransaction.serialNum, updates);
  }

  public static async updateTransactionPartial(
    serialNum: string,
    updates: Partial<Transaction>,
  ): Promise<void> {
    await MoneyDb.ensureDb();
    const fields: string[] = [];
    const values: any[] = [];

    for (const [key, value] of Object.entries(updates)) {
      const snakeKey = toSnakeCase(key);
      if (key === 'tags' || key === 'splitMembers' || key === 'currency') {
        fields.push(`${snakeKey} = ?`);
        values.push(JSON.stringify(value));
      }
      else {
        fields.push(`${snakeKey} = ?`);
        values.push(value);
      }
    }

    if (fields.length === 0) return;

    values.push(serialNum);
    const sql = `UPDATE transactions SET ${fields.join(', ')} WHERE serial_num = ?`;
    await MoneyDb.db.execute(sql, values);
  }

  // 交易分页查询
  public static async listTransactionsPaged(
    filters: TransactionFilters = {},
    page = 1,
    pageSize = 10,
    sortOptions: SortOptions = {},
  ): Promise<PagedResult<Transaction>> {
    await MoneyDb.ensureDb();

    const offset = (page - 1) * pageSize;
    const whereParts: string[] = [];
    const params: any[] = [];

    // 构建过滤条件
    if (filters.transactionType) {
      whereParts.push('transaction_type = ?');
      params.push(filters.transactionType);
    }
    if (filters.transactionStatus) {
      whereParts.push('transaction_status = ?');
      params.push(filters.transactionStatus);
    }
    if (filters.accountSerialNum) {
      whereParts.push('account_serial_num = ?');
      params.push(filters.accountSerialNum);
    }
    if (filters.category) {
      whereParts.push('category = ?');
      params.push(filters.category);
    }
    if (filters.subCategory) {
      whereParts.push('sub_category = ?');
      params.push(filters.subCategory);
    }
    if (filters.paymentMethod) {
      whereParts.push('payment_method = ?');
      params.push(filters.paymentMethod);
    }

    MoneyDb.appendDateRange('date', filters.dateRange, whereParts, params);
    MoneyDb.appendDateRange(
      'created_at',
      filters.createdAtRange,
      whereParts,
      params,
    );
    MoneyDb.appendAmountRange(
      'amount',
      filters.amountRange,
      whereParts,
      params,
    );

    const whereClause =
      whereParts.length > 0 ? `WHERE ${whereParts.join(' AND ')}` : '';

    // 构建排序条件
    const orderClause = sortOptions.customOrderBy
      ? `ORDER BY ${sortOptions.customOrderBy}`
      : sortOptions.sortBy
        ? `ORDER BY ${sortOptions.sortBy} ${sortOptions.sortDir ?? 'ASC'}`
        : 'ORDER BY date DESC, created_at DESC';

    // 查询数据
    const rows = await MoneyDb.db.select<any[]>(
      `SELECT * FROM transactions ${whereClause} ${orderClause} LIMIT ? OFFSET ?`,
      [...params, pageSize, offset],
    );

    // 查询总数
    const totalRes = await MoneyDb.db.select<{ cnt: number }[]>(
      `SELECT COUNT(*) as cnt FROM transactions ${whereClause}`,
      params,
    );

    const totalCount = totalRes[0]?.cnt ?? 0;
    const totalPages = Math.ceil(totalCount / pageSize);

    return {
      rows: rows.map(t => ({
        ...t,
        tags: JSON.parse(t.tags),
        split_members: JSON.parse(t.split_members),
        currency: JSON.parse(t.currency),
      })) as Transaction[],
      totalCount,
      currentPage: page,
      pageSize,
      totalPages,
    };
  }

  // Budget CRUD
  public static async createBudget(budget: Budget): Promise<void> {
    await MoneyDb.ensureDb();
    const {
      serialNum,
      description,
      accountSerialNum,
      name,
      category,
      amount,
      currency,
      repeatPeriod,
      startDate,
      endDate,
      usedAmount,
      isActive,
      alertEnabled,
      alertThreshold,
      color,
      createdAt,
      updatedAt,
    } = budget;
    const repeatPeriodJson = JSON.stringify(repeatPeriod);
    const currencyJson = JSON.stringify(currency);
    await MoneyDb.db.execute(
      `INSERT INTO budgets (serial_num, description, account_serial_num, name, category, amount, currency, repeat_period, start_date, end_date, used_amount, is_active, alert_enabled, alert_threshold, color, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        serialNum,
        description,
        accountSerialNum,
        name,
        category,
        amount,
        currencyJson,
        repeatPeriodJson,
        startDate,
        endDate,
        usedAmount,
        isActive,
        alertEnabled,
        alertThreshold,
        color,
        createdAt,
        updatedAt,
      ],
    );
  }

  public static async getBudget(serialNum: string): Promise<Budget | null> {
    await MoneyDb.ensureDb();
    const result = await MoneyDb.db.select<any[]>(
      'SELECT * FROM budgets WHERE serial_num = ?',
      [serialNum],
    );
    if (result.length === 0) return null;
    const budget = result[0];
    budget.repeat_period = JSON.parse(budget.repeat_period);
    budget.currency = JSON.parse(budget.currency);
    return budget as Budget;
  }

  public static async listBudgets(): Promise<Budget[]> {
    await MoneyDb.ensureDb();
    const result = await MoneyDb.db.select<any[]>('SELECT * FROM budgets');
    return result.map(b => ({
      ...b,
      repeat_period: JSON.parse(b.repeat_period),
      currency: JSON.parse(b.currency),
    })) as Budget[];
  }

  public static async updateBudget(budget: Budget): Promise<void> {
    await MoneyDb.ensureDb();
    const {
      serialNum,
      description,
      accountSerialNum,
      name,
      category,
      amount,
      currency,
      repeatPeriod,
      startDate,
      endDate,
      usedAmount,
      isActive,
      alertEnabled,
      alertThreshold,
      color,
      updatedAt,
    } = budget;
    const repeatPeriodJson = JSON.stringify(repeatPeriod);
    const currencyJson = JSON.stringify(currency);
    await MoneyDb.db.execute(
      `UPDATE budgets SET description = ?, account_serial_num = ?, name = ?, category = ?, amount = ?, currency = ?, repeat_period = ?, start_date = ?, end_date = ?, used_amount = ?, is_active = ?, alert_enabled = ?, alert_threshold = ?, color = ?, updated_at = ?
       WHERE serial_num = ?`,
      [
        description,
        accountSerialNum,
        name,
        category,
        amount,
        currencyJson,
        repeatPeriodJson,
        startDate,
        endDate,
        usedAmount,
        isActive,
        alertEnabled,
        alertThreshold,
        color,
        updatedAt,
        serialNum,
      ],
    );
  }

  public static async deleteBudget(serialNum: string): Promise<void> {
    await MoneyDb.ensureDb();
    await MoneyDb.db.execute('DELETE FROM budgets WHERE serial_num = ?', [
      serialNum,
    ]);
  }

  public static async updateBudgetSmart(newBudget: Budget): Promise<void> {
    await MoneyDb.ensureDb();
    const oldBudget = await MoneyDb.getBudget(newBudget.serialNum);
    if (!oldBudget) throw new Error('Budget not found');

    const updates: Partial<Budget> = {};
    for (const key in newBudget) {
      const k = key as keyof Budget;
      if (!isEqual(newBudget[k], oldBudget[k])) {
        updates[k] = normalizeValue(newBudget[k]) as any;
      }
    }

    if (Object.keys(updates).length === 0) {
      Lg.i('MoneyDb', 'No changes detected for budget');
      return;
    }

    await MoneyDb.updateBudgetPartial(newBudget.serialNum, updates);
  }

  public static async updateBudgetPartial(
    serialNum: string,
    updates: Partial<Budget>,
  ): Promise<void> {
    await MoneyDb.ensureDb();
    const fields: string[] = [];
    const values: any[] = [];

    for (const [key, value] of Object.entries(updates)) {
      const snakeKey = toSnakeCase(key);
      if (key === 'repeatPeriod' || key === 'currency') {
        fields.push(`${snakeKey} = ?`);
        values.push(JSON.stringify(value));
      }
      else {
        fields.push(`${snakeKey} = ?`);
        values.push(value);
      }
    }

    if (fields.length === 0) return;

    values.push(serialNum);
    const sql = `UPDATE budgets SET ${fields.join(', ')} WHERE serial_num = ?`;
    await MoneyDb.db.execute(sql, values);
  }

  // 预算分页查询
  public static async listBudgetsPaged(
    filters: BudgetFilters = {},
    page = 1,
    pageSize = 10,
    sortOptions: SortOptions = {},
  ): Promise<PagedResult<Budget>> {
    await MoneyDb.ensureDb();

    const offset = (page - 1) * pageSize;
    const whereParts: string[] = [];
    const params: any[] = [];

    // 构建过滤条件
    if (filters.category) {
      whereParts.push('category = ?');
      params.push(filters.category);
    }
    if (filters.isActive !== undefined) {
      whereParts.push('is_active = ?');
      params.push(filters.isActive);
    }
    if (filters.accountSerialNum) {
      whereParts.push('account_serial_num = ?');
      params.push(filters.accountSerialNum);
    }
    if (filters.alertEnabled !== undefined) {
      whereParts.push('alert_enabled = ?');
      params.push(filters.alertEnabled);
    }

    MoneyDb.appendDateRange(
      'start_date',
      filters.dateRange,
      whereParts,
      params,
    );
    MoneyDb.appendDateRange(
      'created_at',
      filters.createdAtRange,
      whereParts,
      params,
    );

    const whereClause =
      whereParts.length > 0 ? `WHERE ${whereParts.join(' AND ')}` : '';

    // 构建排序条件
    const orderClause = sortOptions.customOrderBy
      ? `ORDER BY ${sortOptions.customOrderBy}`
      : sortOptions.sortBy
        ? `ORDER BY ${sortOptions.sortBy} ${sortOptions.sortDir ?? 'ASC'}`
        : 'ORDER BY created_at DESC';

    // 查询数据
    const rows = await MoneyDb.db.select<any[]>(
      `SELECT * FROM budgets ${whereClause} ${orderClause} LIMIT ? OFFSET ?`,
      [...params, pageSize, offset],
    );

    // 查询总数
    const totalRes = await MoneyDb.db.select<{ cnt: number }[]>(
      `SELECT COUNT(*) as cnt FROM budgets ${whereClause}`,
      params,
    );

    const totalCount = totalRes[0]?.cnt ?? 0;
    const totalPages = Math.ceil(totalCount / pageSize);

    return {
      rows: rows.map(b => ({
        ...b,
        repeat_period: JSON.parse(b.repeat_period),
        currency: JSON.parse(b.currency),
      })) as Budget[],
      totalCount,
      currentPage: page,
      pageSize,
      totalPages,
    };
  }

  // FamilyLedger CRUD
  public static async createFamilyLedger(ledger: FamilyLedger): Promise<void> {
    await MoneyDb.ensureDb();
    const {
      serialNum,
      name,
      description,
      baseCurrency,
      members,
      accounts,
      transactions,
      budgets,
      auditLogs,
      createdAt,
      updatedAt,
    } = ledger;
    const membersJson = JSON.stringify(members);
    const baseCurrencyJson = JSON.stringify(baseCurrency);
    await MoneyDb.db.execute(
      `INSERT INTO family_ledgers (serial_num, name, description, base_currency, members, accounts, transactions, budgets, audit_logs, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        serialNum,
        name,
        description,
        baseCurrencyJson,
        membersJson,
        accounts,
        transactions,
        budgets,
        auditLogs,
        createdAt,
        updatedAt,
      ],
    );
  }

  public static async getFamilyLedger(
    serialNum: string,
  ): Promise<FamilyLedger | null> {
    await MoneyDb.ensureDb();
    const result = await MoneyDb.db.select<any[]>(
      'SELECT * FROM family_ledgers WHERE serial_num = ?',
      [serialNum],
    );
    if (result.length === 0) return null;
    const ledger = result[0];
    ledger.members = JSON.parse(ledger.members);
    ledger.base_currency = JSON.parse(ledger.base_currency);
    return ledger as FamilyLedger;
  }

  public static async listFamilyLedgers(): Promise<FamilyLedger[]> {
    await MoneyDb.ensureDb();
    const result = await MoneyDb.db.select<any[]>(
      'SELECT * FROM family_ledgers',
    );
    return result.map(l => ({
      ...l,
      members: JSON.parse(l.members),
      base_currency: JSON.parse(l.base_currency),
    })) as FamilyLedger[];
  }

  public static async updateFamilyLedger(ledger: FamilyLedger): Promise<void> {
    await MoneyDb.ensureDb();
    const {
      serialNum,
      name,
      description,
      baseCurrency,
      members,
      accounts,
      transactions,
      budgets,
      auditLogs,
      updatedAt,
    } = ledger;
    const membersJson = JSON.stringify(members);
    const baseCurrencyJson = JSON.stringify(baseCurrency);
    await MoneyDb.db.execute(
      `UPDATE family_ledgers SET name = ?, description = ?, base_currency = ?, members = ?, accounts = ?, transactions = ?, budgets = ?, audit_logs = ?, updated_at = ?
       WHERE serial_num = ?`,
      [
        name,
        description,
        baseCurrencyJson,
        membersJson,
        accounts,
        transactions,
        budgets,
        auditLogs,
        updatedAt,
        serialNum,
      ],
    );
  }

  public static async deleteFamilyLedger(serialNum: string): Promise<void> {
    await MoneyDb.ensureDb();
    await MoneyDb.db.execute(
      'DELETE FROM family_ledgers WHERE serial_num = ?',
      [serialNum],
    );
  }

  public static async updateFamilyLedgerSmart(
    newLedger: FamilyLedger,
  ): Promise<void> {
    await MoneyDb.ensureDb();
    const oldLedger = await MoneyDb.getFamilyLedger(newLedger.serialNum);
    if (!oldLedger) throw new Error('FamilyLedger not found');

    const updates: Partial<FamilyLedger> = {};
    for (const key in newLedger) {
      const k = key as keyof FamilyLedger;
      if (!isEqual(newLedger[k], oldLedger[k])) {
        updates[k] = normalizeValue(newLedger[k]) as any;
      }
    }

    if (Object.keys(updates).length === 0) {
      Lg.i('MoneyDb', 'No changes detected for family ledger');
      return;
    }

    await MoneyDb.updateFamilyLedgerPartial(newLedger.serialNum, updates);
  }

  public static async updateFamilyLedgerPartial(
    serialNum: string,
    updates: Partial<FamilyLedger>,
  ): Promise<void> {
    await MoneyDb.ensureDb();
    const fields: string[] = [];
    const values: any[] = [];

    for (const [key, value] of Object.entries(updates)) {
      const snakeKey = toSnakeCase(key);
      if (key === 'members' || key === 'baseCurrency') {
        fields.push(`${snakeKey} = ?`);
        values.push(JSON.stringify(value));
      }
      else {
        fields.push(`${snakeKey} = ?`);
        values.push(value);
      }
    }

    if (fields.length === 0) return;

    values.push(serialNum);
    const sql = `UPDATE family_ledgers SET ${fields.join(', ')} WHERE serial_num = ?`;
    await MoneyDb.db.execute(sql, values);
  }

  // FamilyMember CRUD
  public static async createFamilyMember(member: FamilyMember): Promise<void> {
    await MoneyDb.ensureDb();
    const {
      serialNum,
      name,
      role,
      isPrimary,
      permissions,
      createdAt,
      updatedAt,
    } = member;
    await MoneyDb.db.execute(
      `INSERT INTO family_members (serial_num, name, role, is_primary, permissions, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
      [serialNum, name, role, isPrimary, permissions, createdAt, updatedAt],
    );
  }

  public static async getFamilyMember(
    serialNum: string,
  ): Promise<FamilyMember | null> {
    await MoneyDb.ensureDb();
    const result = await MoneyDb.db.select<FamilyMember[]>(
      'SELECT * FROM family_members WHERE serial_num = ?',
      [serialNum],
    );
    return result.length > 0 ? result[0] : null;
  }

  public static async listFamilyMembers(): Promise<FamilyMember[]> {
    await MoneyDb.ensureDb();
    return await MoneyDb.db.select<FamilyMember[]>(
      'SELECT * FROM family_members',
    );
  }

  public static async updateFamilyMember(member: FamilyMember): Promise<void> {
    await MoneyDb.ensureDb();
    const { serialNum, name, role, isPrimary, permissions, updatedAt } = member;
    await MoneyDb.db.execute(
      `UPDATE family_members SET name = ?, role = ?, is_primary = ?, permissions = ?, updated_at = ?
       WHERE serial_num = ?`,
      [name, role, isPrimary, permissions, updatedAt, serialNum],
    );
  }

  public static async deleteFamilyMember(serialNum: string): Promise<void> {
    await MoneyDb.ensureDb();
    await MoneyDb.db.execute(
      'DELETE FROM family_members WHERE serial_num = ?',
      [serialNum],
    );
  }

  public static async updateFamilyMemberSmart(
    newMember: FamilyMember,
  ): Promise<void> {
    await MoneyDb.ensureDb();
    const oldMember = await MoneyDb.getFamilyMember(newMember.serialNum);
    if (!oldMember) throw new Error('FamilyMember not found');

    const updates: Partial<FamilyMember> = {};
    for (const key in newMember) {
      const k = key as keyof FamilyMember;
      if (!isEqual(newMember[k], oldMember[k])) {
        updates[k] = normalizeValue(newMember[k]) as any;
      }
    }

    if (Object.keys(updates).length === 0) {
      Lg.i('MoneyDb', 'No changes detected for family member');
      return;
    }

    await MoneyDb.updateFamilyMemberPartial(newMember.serialNum, updates);
  }

  public static async updateFamilyMemberPartial(
    serialNum: string,
    updates: Partial<FamilyMember>,
  ): Promise<void> {
    await MoneyDb.ensureDb();
    const fields: string[] = [];
    const values: any[] = [];

    for (const [key, value] of Object.entries(updates)) {
      const snakeKey = toSnakeCase(key);
      fields.push(`${snakeKey} = ?`);
      values.push(value);
    }

    if (fields.length === 0) return;

    values.push(serialNum);
    const sql = `UPDATE family_members SET ${fields.join(', ')} WHERE serial_num = ?`;
    await MoneyDb.db.execute(sql, values);
  }

  // BilReminder CRUD
  public static async createBilReminder(reminder: BilReminder): Promise<void> {
    await MoneyDb.ensureDb();
    const {
      serialNum,
      name,
      enabled,
      type,
      description,
      category,
      amount,
      currency,
      dueDate,
      billDate,
      remindDate,
      repeatPeriod,
      isPaid,
      priority,
      advanceValue,
      advanceUnit,
      color,
      relatedTransactionSerialNum,
      createdAt,
      updatedAt,
    } = reminder;
    const repeatPeriodJson = JSON.stringify(repeatPeriod);
    const currencyJson = JSON.stringify(currency);
    await MoneyDb.db.execute(
      `INSERT INTO bil_reminders (serial_num, name, enabled, type, description, category, amount, currency, due_date, bill_date, remind_date, repeat_period, is_paid, priority, advance_value, advance_unit, color, related_transaction_serial_num, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        serialNum,
        name,
        enabled,
        type,
        description,
        category,
        amount,
        currencyJson,
        dueDate,
        billDate,
        remindDate,
        repeatPeriodJson,
        isPaid,
        priority,
        advanceValue,
        advanceUnit,
        color,
        relatedTransactionSerialNum,
        createdAt,
        updatedAt,
      ],
    );
  }

  public static async getBilReminder(
    serialNum: string,
  ): Promise<BilReminder | null> {
    await MoneyDb.ensureDb();
    const result = await MoneyDb.db.select<any[]>(
      'SELECT * FROM bil_reminders WHERE serial_num = ?',
      [serialNum],
    );
    if (result.length === 0) return null;
    const reminder = result[0];
    reminder.repeat_period = JSON.parse(reminder.repeat_period);
    reminder.currency = JSON.parse(reminder.currency);
    return reminder as BilReminder;
  }

  public static async listBilReminders(): Promise<BilReminder[]> {
    await MoneyDb.ensureDb();
    const result = await MoneyDb.db.select<any[]>(
      'SELECT * FROM bil_reminders',
    );
    return result.map(r => ({
      ...r,
      repeat_period: JSON.parse(r.repeat_period),
      currency: JSON.parse(r.currency),
    })) as BilReminder[];
  }

  public static async updateBilReminder(reminder: BilReminder): Promise<void> {
    await MoneyDb.ensureDb();
    const {
      serialNum,
      name,
      enabled,
      type,
      description,
      category,
      amount,
      currency,
      dueDate,
      billDate,
      remindDate,
      repeatPeriod,
      isPaid,
      priority,
      advanceValue,
      advanceUnit,
      color,
      relatedTransactionSerialNum,
      updatedAt,
    } = reminder;
    const repeatPeriodJson = JSON.stringify(repeatPeriod);
    const currencyJson = JSON.stringify(currency);
    await MoneyDb.db.execute(
      `UPDATE bil_reminders SET name = ?, enabled = ?, type = ?, description = ?, category = ?, amount = ?, currency = ?, due_date = ?, bill_date = ?, remind_date = ?, repeat_period = ?, is_paid = ?, priority = ?, advance_value = ?, advance_unit = ?, color = ?, related_transaction_serial_num = ?, updated_at = ?
       WHERE serial_num = ?`,
      [
        name,
        enabled,
        type,
        description,
        category,
        amount,
        currencyJson,
        dueDate,
        billDate,
        remindDate,
        repeatPeriodJson,
        isPaid,
        priority,
        advanceValue,
        advanceUnit,
        color,
        relatedTransactionSerialNum,
        updatedAt,
        serialNum,
      ],
    );
  }

  public static async deleteBilReminder(serialNum: string): Promise<void> {
    await MoneyDb.ensureDb();
    await MoneyDb.db.execute('DELETE FROM bil_reminders WHERE serial_num = ?', [
      serialNum,
    ]);
  }

  public static async updateBilReminderSmart(
    newReminder: BilReminder,
  ): Promise<void> {
    await MoneyDb.ensureDb();
    const oldReminder = await MoneyDb.getBilReminder(newReminder.serialNum);
    if (!oldReminder) throw new Error('BilReminder not found');

    const updates: Partial<BilReminder> = {};
    for (const key in newReminder) {
      const k = key as keyof BilReminder;
      if (!isEqual(newReminder[k], oldReminder[k])) {
        updates[k] = normalizeValue(newReminder[k]) as any;
      }
    }

    if (Object.keys(updates).length === 0) {
      Lg.i('MoneyDb', 'No changes detected for bil reminder');
      return;
    }

    await MoneyDb.updateBilReminderPartial(newReminder.serialNum, updates);
  }

  public static async updateBilReminderPartial(
    serialNum: string,
    updates: Partial<BilReminder>,
  ): Promise<void> {
    await MoneyDb.ensureDb();
    const fields: string[] = [];
    const values: any[] = [];

    for (const [key, value] of Object.entries(updates)) {
      const snakeKey = toSnakeCase(key);
      if (key === 'repeatPeriod' || key === 'currency') {
        fields.push(`${snakeKey} = ?`);
        values.push(JSON.stringify(value));
      }
      else {
        fields.push(`${snakeKey} = ?`);
        values.push(value);
      }
    }

    if (fields.length === 0) return;

    values.push(serialNum);
    const sql = `UPDATE bil_reminders SET ${fields.join(', ')} WHERE serial_num = ?`;
    await MoneyDb.db.execute(sql, values);
  }

  // 账单提醒分页查询
  public static async listBilRemindersPaged(
    filters: BilReminderFilters = {},
    page = 1,
    pageSize = 10,
    sortOptions: SortOptions = {},
  ): Promise<PagedResult<BilReminder>> {
    await MoneyDb.ensureDb();

    const offset = (page - 1) * pageSize;
    const whereParts: string[] = [];
    const params: any[] = [];

    // 构建过滤条件
    if (filters.type) {
      whereParts.push('type = ?');
      params.push(filters.type);
    }
    if (filters.enabled !== undefined) {
      whereParts.push('enabled = ?');
      params.push(filters.enabled);
    }
    if (filters.category) {
      whereParts.push('category = ?');
      params.push(filters.category);
    }
    if (filters.isPaid !== undefined) {
      whereParts.push('is_paid = ?');
      params.push(filters.isPaid);
    }
    if (filters.priority) {
      whereParts.push('priority = ?');
      params.push(filters.priority);
    }

    MoneyDb.appendDateRange(
      'due_date',
      filters.dueDateRange,
      whereParts,
      params,
    );
    MoneyDb.appendDateRange(
      'created_at',
      filters.createdAtRange,
      whereParts,
      params,
    );

    const whereClause =
      whereParts.length > 0 ? `WHERE ${whereParts.join(' AND ')}` : '';

    // 构建排序条件
    const orderClause = sortOptions.customOrderBy
      ? `ORDER BY ${sortOptions.customOrderBy}`
      : sortOptions.sortBy
        ? `ORDER BY ${sortOptions.sortBy} ${sortOptions.sortDir ?? 'ASC'}`
        : 'ORDER BY due_date ASC, created_at DESC';

    // 查询数据
    const rows = await MoneyDb.db.select<any[]>(
      `SELECT * FROM bil_reminders ${whereClause} ${orderClause} LIMIT ? OFFSET ?`,
      [...params, pageSize, offset],
    );

    // 查询总数
    const totalRes = await MoneyDb.db.select<{ cnt: number }[]>(
      `SELECT COUNT(*) as cnt FROM bil_reminders ${whereClause}`,
      params,
    );

    const totalCount = totalRes[0]?.cnt ?? 0;
    const totalPages = Math.ceil(totalCount / pageSize);

    return {
      rows: rows.map(r => ({
        ...r,
        repeat_period: JSON.parse(r.repeat_period),
        currency: JSON.parse(r.currency),
      })) as BilReminder[],
      totalCount,
      currentPage: page,
      pageSize,
      totalPages,
    };
  }

  // Additional Utility Method
  public static async getTransactionWithAccount(
    serialNum: string,
  ): Promise<TransactionWithAccount | null> {
    await MoneyDb.ensureDb();
    const result = await MoneyDb.db.select<any[]>(
      `SELECT t.*, a.* FROM transactions t
       JOIN accounts a ON t.account_serial_num = a.serial_num
       WHERE t.serial_num = ?`,
      [serialNum],
    );
    if (result.length === 0) return null;
    const transaction = result[0];
    transaction.tags = JSON.parse(transaction.tags);
    transaction.split_members = JSON.parse(transaction.split_members);
    transaction.currency = JSON.parse(transaction.currency);
    transaction.account = {
      serialNum: transaction.serial_num_1,
      name: transaction.name_1,
      description: transaction.description_1,
      type: transaction.type_1,
      balance: transaction.balance,
      currency: JSON.parse(transaction.currency_1),
      isShared: transaction.is_shared,
      ownerId: transaction.owner_id,
      isActive: transaction.is_active,
      color: transaction.color_1,
      createdAt: transaction.created_at_1,
      updatedAt: transaction.updated_at_1,
    };
    return transaction as TransactionWithAccount;
  }

  // 带账户信息的交易分页查询
  public static async listTransactionsWithAccountPaged(
    filters: TransactionFilters = {},
    page = 1,
    pageSize = 10,
    sortOptions: SortOptions = {},
  ): Promise<PagedResult<TransactionWithAccount>> {
    await MoneyDb.ensureDb();

    const offset = (page - 1) * pageSize;
    const whereParts: string[] = [];
    const params: any[] = [];

    // 构建过滤条件（使用表别名）
    if (filters.transactionType) {
      whereParts.push('t.transaction_type = ?');
      params.push(filters.transactionType);
    }
    if (filters.transactionStatus) {
      whereParts.push('t.transaction_status = ?');
      params.push(filters.transactionStatus);
    }
    if (filters.accountSerialNum) {
      whereParts.push('t.account_serial_num = ?');
      params.push(filters.accountSerialNum);
    }
    if (filters.category) {
      whereParts.push('t.category = ?');
      params.push(filters.category);
    }
    if (filters.subCategory) {
      whereParts.push('t.sub_category = ?');
      params.push(filters.subCategory);
    }
    if (filters.paymentMethod) {
      whereParts.push('t.payment_method = ?');
      params.push(filters.paymentMethod);
    }

    if (filters.dateRange) {
      MoneyDb.appendDateRange('t.date', filters.dateRange, whereParts, params);
    }
    if (filters.createdAtRange) {
      MoneyDb.appendDateRange(
        't.created_at',
        filters.createdAtRange,
        whereParts,
        params,
      );
    }
    if (filters.amountRange) {
      MoneyDb.appendAmountRange(
        't.amount',
        filters.amountRange,
        whereParts,
        params,
      );
    }

    const whereClause =
      whereParts.length > 0 ? `WHERE ${whereParts.join(' AND ')}` : '';

    // 构建排序条件
    const orderClause = sortOptions.customOrderBy
      ? `ORDER BY ${sortOptions.customOrderBy}`
      : sortOptions.sortBy
        ? `ORDER BY ${sortOptions.sortBy} ${sortOptions.sortDir ?? 'ASC'}`
        : 'ORDER BY t.date DESC, t.created_at DESC';

    // 查询数据
    const rows = await MoneyDb.db.select<any[]>(
      `SELECT t.*, 
            a.serial_num as account_serial_num_detail,
            a.name as account_name,
            a.description as account_description,
            a.type as account_type,
            a.balance as account_balance,
            a.currency as account_currency,
            a.is_shared as account_is_shared,
            a.owner_id as account_owner_id,
            a.is_active as account_is_active,
            a.color as account_color,
            a.created_at as account_created_at,
            a.updated_at as account_updated_at
     FROM transactions t
     JOIN accounts a ON t.account_serial_num = a.serial_num
     ${whereClause} ${orderClause} LIMIT ? OFFSET ?`,
      [...params, pageSize, offset],
    );

    // 查询总数
    const totalRes = await MoneyDb.db.select<{ cnt: number }[]>(
      `SELECT COUNT(*) as cnt 
     FROM transactions t
     JOIN accounts a ON t.account_serial_num = a.serial_num
     ${whereClause}`,
      params,
    );

    const totalCount = totalRes[0]?.cnt ?? 0;
    const totalPages = Math.ceil(totalCount / pageSize);

    return {
      rows: rows.map(row => ({
        ...row,
        tags: JSON.parse(row.tags),
        split_members: JSON.parse(row.split_members),
        currency: JSON.parse(row.currency),
        account: {
          serialNum: row.account_serial_num_detail,
          name: row.account_name,
          description: row.account_description,
          type: row.account_type,
          balance: row.account_balance,
          currency: JSON.parse(row.account_currency),
          isShared: row.account_is_shared,
          ownerId: row.account_owner_id,
          isActive: row.account_is_active,
          color: row.account_color,
          createdAt: row.account_created_at,
          updatedAt: row.account_updated_at,
        },
      })) as TransactionWithAccount[],
      totalCount,
      currentPage: page,
      pageSize,
      totalPages,
    };
  }

  // 辅助函数：构建日期范围查询
  private static appendDateRange(
    field: string,
    range: DateRange | undefined,
    whereParts: string[],
    params: any[],
  ): void {
    if (!range) return;
    if (range.start) {
      whereParts.push(`${field} >= ?`);
      params.push(range.start);
    }
    if (range.end) {
      whereParts.push(`${field} <= ?`);
      params.push(range.end);
    }
  }

  // 辅助函数：构建数值范围查询
  private static appendAmountRange(
    field: string,
    range: { min?: number; max?: number } | undefined,
    whereParts: string[],
    params: any[],
  ): void {
    if (!range) return;
    if (range.min !== undefined) {
      whereParts.push(`${field} >= ?`);
      params.push(range.min);
    }
    if (range.max !== undefined) {
      whereParts.push(`${field} <= ?`);
      params.push(range.max);
    }
  }
}
