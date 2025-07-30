import { db } from '@/utils/dbUtils';
import { AccountMapper } from './accounts';
import { MoneyDbError } from './baseManager';
import { BilReminderMapper } from './billReminder';
import { BudgetMapper } from './budgets';
import { CurrencyMapper } from './currencys';
import {
  FamilyLedgerAccountMapper,
  FamilyLedgerMapper,
  FamilyLedgerMemberMapper,
  FamilyLedgerTransactionMapper,
  FamilyMemberMapper,
} from './family';
import { TransactionMapper } from './transactions';
import type { AccountFilters } from './accounts';
import type { PagedResult } from './baseManager';
import type { BilReminderFilters } from './billReminder';
import type { BudgetFilters } from './budgets';
import type { TransactionFilters } from './transactions';
import type { Currency, SortOptions } from '@/schema/common';
import type {
  Account,
  BilReminder,
  Budget,
  FamilyLedger,
  FamilyLedgerMember,
  FamilyLedgerTransaction,
  FamilyMember,
  Transaction,
  TransactionWithAccount,
} from '@/schema/money';

/**
 * 主要的 MoneyDb 类 - 使用映射器模式
 */
export class MoneyDb {
  private static accountMapper = new AccountMapper();
  private static transactionMapper = new TransactionMapper();
  private static budgetMapper = new BudgetMapper();
  private static bilReminderMapper = new BilReminderMapper();
  private static currencyMapper = new CurrencyMapper();
  private static familyMemberMapper = new FamilyMemberMapper();
  private static familyLedgerMapper = new FamilyLedgerMapper();
  private static familyLedgerAccountMapper = new FamilyLedgerAccountMapper();
  private static familyLedgerTransactionMapper =
    new FamilyLedgerTransactionMapper();

  private static familyLedgerMemberMapper = new FamilyLedgerMemberMapper();

  // Account 操作
  static async createAccount(account: Account): Promise<void> {
    return this.accountMapper.create(account);
  }

  static async getAccount(serialNum: string): Promise<Account | null> {
    return this.accountMapper.getById(serialNum);
  }

  static async listAccounts(): Promise<Account[]> {
    return this.accountMapper.list();
  }

  static async updateAccount(account: Account): Promise<void> {
    return this.accountMapper.update(account);
  }

  static async updateAccountActive(
    serialNum: string,
    isActive: boolean,
  ): Promise<void> {
    return this.accountMapper.updateAccountActive(serialNum, isActive);
  }

  static async deleteAccount(serialNum: string): Promise<void> {
    return this.accountMapper.deleteById(serialNum);
  }

  static async updateAccountSmart(newAccount: Account): Promise<void> {
    return this.accountMapper.updateSmart(newAccount);
  }

  static async updateAccountPartial(
    serialNum: string,
    updates: Partial<Account>,
  ): Promise<void> {
    return this.accountMapper.updateAccountPartial(serialNum, updates);
  }

  static async listAccountsPaged(
    filters: AccountFilters = {},
    page = 1,
    pageSize = 10,
    sortOptions: SortOptions = {},
  ): Promise<PagedResult<Account>> {
    return this.accountMapper.listPaged(filters, page, pageSize, sortOptions);
  }

  // Transaction 操作
  static async createTransaction(transaction: Transaction): Promise<void> {
    return this.transactionMapper.create(transaction);
  }

  static async getTransaction(serialNum: string): Promise<Transaction | null> {
    return this.transactionMapper.getById(serialNum);
  }

  static async getTransferRelatedTransaction(
    serialNum: string,
  ): Promise<Transaction | null> {
    try {
      const transaction =
        await this.transactionMapper.getTransferRelatedTransaction(serialNum);
      if (!transaction) return null;
      return transaction;
    }
    catch (error) {
      throw new MoneyDbError(
        'Failed to get related transfer transaction',
        'getTransferRelatedTransaction',
        'Transaction',
        error as Error,
      );
    }
  }

  static async getTransferRelatedTransactionWithAccount(
    serialNum: string,
  ): Promise<TransactionWithAccount | null> {
    try {
      return await this.transactionMapper.getTransferRelatedTransactionWithAccount(
        serialNum,
      );
    }
    catch (error) {
      throw new MoneyDbError(
        'Failed to get related transfer transaction',
        'getTransferRelatedTransaction',
        'Transaction',
        error as Error,
      );
    }
  }

  static async listTransactions(): Promise<Transaction[]> {
    return this.transactionMapper.list();
  }

  static async updateTransaction(transaction: Transaction): Promise<void> {
    return this.transactionMapper.update(transaction);
  }

  static async deleteTransaction(serialNum: string): Promise<void> {
    return this.transactionMapper.deleteById(serialNum);
  }

  static async updateTransactionSmart(
    newTransaction: Transaction,
  ): Promise<void> {
    return this.transactionMapper.updateSmart(newTransaction);
  }

  static async updateTransactionPartial(
    serialNum: string,
    updates: Partial<Transaction>,
  ): Promise<void> {
    return this.transactionMapper.updateTransactionPartial(serialNum, updates);
  }

  static async listTransactionsPaged(
    filters: TransactionFilters = {},
    page = 1,
    pageSize = 10,
    sortOptions: SortOptions = {},
  ): Promise<PagedResult<Transaction>> {
    return this.transactionMapper.listPaged(
      filters,
      page,
      pageSize,
      sortOptions,
    );
  }

  static async listTransactionsWithAccountPaged(
    filters: TransactionFilters = {},
    page = 1,
    pageSize = 10,
    sortOptions: SortOptions = {},
  ): Promise<PagedResult<TransactionWithAccount>> {
    return await this.transactionMapper.listWithAccountPaged(
      filters,
      page,
      pageSize,
      sortOptions,
    );
  }

  static async getTransactionWithAccount(
    serialNum: string,
  ): Promise<TransactionWithAccount | null> {
    return await this.transactionMapper.getTransactionWithAccount(serialNum);
  }

  // Budget 操作
  static async createBudget(budget: Budget): Promise<void> {
    return this.budgetMapper.create(budget);
  }

  static async getBudget(serialNum: string): Promise<Budget | null> {
    return this.budgetMapper.getById(serialNum);
  }

  static async listBudgets(): Promise<Budget[]> {
    return this.budgetMapper.list();
  }

  static async updateBudget(budget: Budget): Promise<void> {
    return this.budgetMapper.update(budget);
  }

  static async deleteBudget(serialNum: string): Promise<void> {
    return this.budgetMapper.deleteById(serialNum);
  }

  static async updateBudgetSmart(newBudget: Budget): Promise<void> {
    return this.budgetMapper.updateSmart(newBudget);
  }

  static async updateBudgetPartial(
    serialNum: string,
    updates: Partial<Budget>,
  ): Promise<void> {
    return this.budgetMapper.updateBudgetPartial(serialNum, updates);
  }

  static async listBudgetsPaged(
    filters: BudgetFilters = {},
    page = 1,
    pageSize = 10,
    sortOptions: SortOptions = {},
  ): Promise<PagedResult<Budget>> {
    return this.budgetMapper.listPaged(filters, page, pageSize, sortOptions);
  }

  // BilReminder 操作
  static async createBilReminder(reminder: BilReminder): Promise<void> {
    return this.bilReminderMapper.create(reminder);
  }

  static async getBilReminder(serialNum: string): Promise<BilReminder | null> {
    return this.bilReminderMapper.getById(serialNum);
  }

  static async listBilReminders(): Promise<BilReminder[]> {
    return this.bilReminderMapper.list();
  }

  static async updateBilReminder(reminder: BilReminder): Promise<void> {
    return this.bilReminderMapper.update(reminder);
  }

  static async deleteBilReminder(serialNum: string): Promise<void> {
    return this.bilReminderMapper.deleteById(serialNum);
  }

  static async listBilRemindersPaged(
    filters: BilReminderFilters = {},
    page = 1,
    pageSize = 10,
    sortOptions: SortOptions = {},
  ): Promise<PagedResult<BilReminder>> {
    return this.bilReminderMapper.listPaged(
      filters,
      page,
      pageSize,
      sortOptions,
    );
  }

  // Currency 操作
  static async createCurrency(currency: Currency): Promise<void> {
    return this.currencyMapper.create(currency);
  }

  static async getCurrency(code: string): Promise<Currency | null> {
    return this.currencyMapper.getById(code);
  }

  static async listCurrencies(): Promise<Currency[]> {
    return this.currencyMapper.list();
  }

  static async updateCurrency(currency: Currency): Promise<void> {
    return this.currencyMapper.update(currency);
  }

  static async deleteCurrency(code: string): Promise<void> {
    return this.currencyMapper.deleteById(code);
  }

  static async getCurrencyByCode(code: string): Promise<Currency | null> {
    return this.currencyMapper.getById(code);
  }

  // FamilyMember 操作
  static async createFamilyMember(member: FamilyMember): Promise<void> {
    return this.familyMemberMapper.create(member);
  }

  static async getFamilyMember(
    serialNum: string,
  ): Promise<FamilyMember | null> {
    return this.familyMemberMapper.getById(serialNum);
  }

  static async listFamilyMembers(): Promise<FamilyMember[]> {
    return this.familyMemberMapper.list();
  }

  static async updateFamilyMember(member: FamilyMember): Promise<void> {
    return this.familyMemberMapper.update(member);
  }

  static async deleteFamilyMember(serialNum: string): Promise<void> {
    return this.familyMemberMapper.deleteById(serialNum);
  }

  static async listFamilyMembersPaged(
    filters: Record<string, any> = {},
    page = 1,
    pageSize = 10,
    sortOptions: SortOptions = {},
  ): Promise<PagedResult<FamilyMember>> {
    return this.familyMemberMapper.listPaged(
      filters,
      page,
      pageSize,
      sortOptions,
    );
  }

  // FamilyLedger 操作
  static async createFamilyLedger(ledger: FamilyLedger): Promise<void> {
    return this.familyLedgerMapper.create(ledger);
  }

  static async getFamilyLedger(
    serialNum: string,
  ): Promise<FamilyLedger | null> {
    return this.familyLedgerMapper.getById(serialNum);
  }

  static async listFamilyLedgers(): Promise<FamilyLedger[]> {
    return this.familyLedgerMapper.list();
  }

  static async updateFamilyLedger(ledger: FamilyLedger): Promise<void> {
    return this.familyLedgerMapper.update(ledger);
  }

  static async deleteFamilyLedger(serialNum: string): Promise<void> {
    return this.familyLedgerMapper.deleteById(serialNum);
  }

  static async listFamilyLedgersPaged(
    filters: Record<string, any> = {},
    page = 1,
    pageSize = 10,
    sortOptions: SortOptions = {},
  ): Promise<PagedResult<FamilyLedger>> {
    return this.familyLedgerMapper.listPaged(
      filters,
      page,
      pageSize,
      sortOptions,
    );
  }

  // FamilyLedgerAccount 操作
  static async createFamilyLedgerAccount(assoc: {
    serialNum: string;
    familyLedgerSerialNum: string;
    accountSerialNum: string;
  }): Promise<void> {
    return this.familyLedgerAccountMapper.create(assoc);
  }

  static async getFamilyLedgerAccount(serialNum: string): Promise<{
    serialNum: string;
    familyLedgerSerialNum: string;
    accountSerialNum: string;
  } | null> {
    return this.familyLedgerAccountMapper.getById(serialNum);
  }

  static async listFamilyLedgerAccounts(): Promise<
    {
      serialNum: string;
      familyLedgerSerialNum: string;
      accountSerialNum: string;
    }[]
  > {
    return this.familyLedgerAccountMapper.list();
  }

  static async updateFamilyLedgerAccount(assoc: {
    serialNum: string;
    familyLedgerSerialNum: string;
    accountSerialNum: string;
  }): Promise<void> {
    return this.familyLedgerAccountMapper.update(assoc);
  }

  static async deleteFamilyLedgerAccount(serialNum: string): Promise<void> {
    return this.familyLedgerAccountMapper.deleteById(serialNum);
  }

  // FamilyLedgerTransaction 操作
  static async createFamilyLedgerTransaction(
    assoc: FamilyLedgerTransaction,
  ): Promise<void> {
    return this.familyLedgerTransactionMapper.create(assoc);
  }

  static async getFamilyLedgerTransaction(serialNum: string): Promise<{
    familyLedgerSerialNum: string;
    transactionSerialNum: string;
  } | null> {
    return this.familyLedgerTransactionMapper.getById(serialNum);
  }

  static async listFamilyLedgerTransactions(): Promise<
    { familyLedgerSerialNum: string; transactionSerialNum: string }[]
  > {
    return this.familyLedgerTransactionMapper.list();
  }

  static async deleteFamilyLedgerTransaction(serialNum: string): Promise<void> {
    return this.familyLedgerTransactionMapper.deleteById(serialNum);
  }

  // FamilyLedgerMember 操作
  static async createFamilyLedgerMember(
    assoc: FamilyLedgerMember,
  ): Promise<void> {
    return this.familyLedgerMemberMapper.create(assoc);
  }

  static async getFamilyLedgerMember(serialNum: string): Promise<{
    familyLedgerSerialNum: string;
    familyMemberSerialNum: string;
  } | null> {
    return this.familyLedgerMemberMapper.getById(serialNum);
  }

  static async listFamilyLedgerMembers(): Promise<
    { familyLedgerSerialNum: string; familyMemberSerialNum: string }[]
  > {
    return this.familyLedgerMemberMapper.list();
  }

  static async deleteFamilyLedgerMember(serialNum: string): Promise<void> {
    return this.familyLedgerMemberMapper.deleteById(serialNum);
  }

  // 批量操作
  static async executeBatch(
    operations: Array<{ sql: string; params: any[] }>,
  ): Promise<void> {
    return db.executeBatch(operations);
  }

  // 事务操作
  static async executeInTransaction<T>(callback: () => Promise<T>): Promise<T> {
    return db.transaction(async () => {
      return await callback();
    });
  }

  // 统计信息
  static async getStats(): Promise<{
    cacheSize: number;
    dbPath: string;
    isConnected: boolean;
  }> {
    return db.getStats();
  }

  // 清理缓存
  static cleanCache(): void {
    db.cleanCache();
  }

  // 关闭连接
  static async close(): Promise<void> {
    return db.close();
  }
}
