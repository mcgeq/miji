import { AccountMapper } from './accounts';
import { BilReminderMapper } from './billReminder';
import { BudgetMapper } from './budgets';
import { CategoryMapper } from './categories';
import { CurrencyMapper } from './currencys';
import {
  FamilyLedgerAccountMapper,
  FamilyLedgerMapper,
  FamilyLedgerMemberMapper,
  FamilyLedgerTransactionMapper,
  FamilyMemberMapper,
} from './family';
import { SubCategoryMapper } from './sub_categories';
import { TransactionMapper } from './transactions';
import type { AccountFilters } from './accounts';
import type { PagedResult } from './baseManager';
import type { BilReminderFilters } from './billReminder';
import type { BudgetFilters } from './budgets';
import type { FamilyLedgerFilters } from './family';
import type {
  InstallmentPlanResponse,
  TransactionFilters,
  TransactionStatsRequest,
  TransactionStatsResponse,
} from './transactions';
import type {
  AccountBalanceSummary,
  Currency,
  CurrencyUpdate,
  IncomeExpense,
  PageQuery,
} from '@/schema/common';
import type {
  Account,
  BilReminder,
  BilReminderCreate,
  BilReminderUpdate,
  Budget,
  BudgetCreate,
  BudgetUpdate,
  CreateAccountRequest,
  FamilyLedger,
  FamilyLedgerAccount,
  FamilyLedgerAccountCreate,
  FamilyLedgerAccountUpdate,
  FamilyLedgerCreate,
  FamilyLedgerMember,
  FamilyLedgerMemberCreate,
  FamilyLedgerTransaction,
  FamilyLedgerTransactionCreate,
  FamilyLedgerUpdate,
  FamilyMember,
  FamilyMemberCreate,
  FamilyMemberUpdate,
  Transaction,
  TransactionCreate,
  TransactionUpdate,
  TransferCreate,
  UpdateAccountRequest,
} from '@/schema/money';
import type { Category, SubCategory } from '@/schema/money/category';

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
  private static familyLedgerTransactionMapper = new FamilyLedgerTransactionMapper();
  private static subCategoryMapper = new SubCategoryMapper();
  private static categoryMapper = new CategoryMapper();
  private static familyLedgerMemberMapper = new FamilyLedgerMemberMapper();

  // ========================= Account Start=========================
  // Account 操作
  static async createAccount(account: CreateAccountRequest): Promise<Account> {
    return this.accountMapper.create(account);
  }

  static async getAccount(serialNum: string): Promise<Account | null> {
    return this.accountMapper.getById(serialNum);
  }

  static async listAccounts(): Promise<Account[]> {
    return this.accountMapper.list();
  }

  static async updateAccount(serialNum: string, account: UpdateAccountRequest): Promise<Account> {
    return this.accountMapper.update(serialNum, account);
  }

  static async updateAccountActive(serialNum: string, isActive: boolean): Promise<Account> {
    return this.accountMapper.updateAccountActive(serialNum, isActive);
  }

  static async deleteAccount(serialNum: string): Promise<void> {
    return this.accountMapper.deleteById(serialNum);
  }

  static async listAccountsPaged(
    query: PageQuery<AccountFilters> = {
      currentPage: 1,
      pageSize: 10,
      sortOptions: {},
      filter: {},
    },
  ): Promise<PagedResult<Account>> {
    return this.accountMapper.listPaged(query);
  }

  static async totalAssets(): Promise<AccountBalanceSummary> {
    return await this.accountMapper.totalAssets();
  }
  // ========================= Account End =========================

  // ========================= Transaction Start=========================
  // Transaction 操作
  static async createTransaction(transaction: TransactionCreate): Promise<Transaction> {
    return this.transactionMapper.create(transaction);
  }

  static async getTransaction(serialNum: string): Promise<Transaction | null> {
    return this.transactionMapper.getById(serialNum);
  }

  static async updateTransaction(
    serialNum: string,
    transaction: TransactionUpdate,
  ): Promise<Transaction> {
    return this.transactionMapper.update(serialNum, transaction);
  }

  static async deleteTransaction(serialNum: string): Promise<void> {
    return this.transactionMapper.deleteById(serialNum);
  }

  static async transferCreate(transfer: TransferCreate): Promise<[Transaction, Transaction]> {
    return this.transactionMapper.transfer(transfer);
  }

  static async transferUpdate(
    serialNum: string,
    transfer: TransferCreate,
  ): Promise<[Transaction, Transaction]> {
    return this.transactionMapper.transferUpdate(serialNum, transfer);
  }

  static async transferDelete(serialNum: string): Promise<[Transaction, Transaction]> {
    return this.transactionMapper.transferDelete(serialNum);
  }

  static async listTransactions(): Promise<Transaction[]> {
    return this.transactionMapper.list();
  }

  static async listTransactionsPaged(
    query: PageQuery<TransactionFilters>,
  ): Promise<PagedResult<Transaction>> {
    return this.transactionMapper.listPaged(query);
  }

  static async monthlyIncomeAndExpense(): Promise<IncomeExpense> {
    return await this.transactionMapper.monthlyIncomeAndExpense();
  }

  static async lastMonthIncomeAndExpense(): Promise<IncomeExpense> {
    return await this.transactionMapper.lastMonthIncomeAndExpense();
  }

  static async yearlyIncomeAndExpense(): Promise<IncomeExpense> {
    return await this.transactionMapper.yearlyIncomeAndExpense();
  }

  static async lastYearIncomeAndExpense(): Promise<IncomeExpense> {
    return this.transactionMapper.lastYearIncomeAndExpense();
  }

  static async getTransactionStats(
    request: TransactionStatsRequest,
  ): Promise<TransactionStatsResponse> {
    return this.transactionMapper.getStats(request);
  }

  // 分期付款相关方法

  static async getInstallmentPlan(planId: string): Promise<InstallmentPlanResponse> {
    return this.transactionMapper.getInstallmentPlan(planId);
  }

  static async getPendingInstallments(): Promise<InstallmentPlanResponse[]> {
    return this.transactionMapper.getPendingInstallments();
  }
  // ========================= Transaction End =========================

  // ========================= Budget Start=========================
  // Budget 操作
  static async createBudget(budget: BudgetCreate): Promise<Budget> {
    return this.budgetMapper.create(budget);
  }

  static async getBudget(serialNum: string): Promise<Budget | null> {
    return this.budgetMapper.getById(serialNum);
  }

  static async updateBudget(serialNum: string, budget: BudgetUpdate): Promise<Budget> {
    return this.budgetMapper.update(serialNum, budget);
  }

  static async updateBudgetActive(serialNum: string, isActive: boolean): Promise<Budget> {
    return this.budgetMapper.updateActive(serialNum, isActive);
  }

  static async deleteBudget(serialNum: string): Promise<void> {
    return this.budgetMapper.deleteById(serialNum);
  }

  static async listBudgets(): Promise<Budget[]> {
    return this.budgetMapper.list();
  }

  static async listBudgetsPaged(query: PageQuery<BudgetFilters>): Promise<PagedResult<Budget>> {
    return this.budgetMapper.listPaged(query);
  }
  // ========================= Budget End=========================

  // ========================= BilReminder Start =========================
  // BilReminder 操作
  static async createBilReminder(reminder: BilReminderCreate): Promise<BilReminder> {
    return this.bilReminderMapper.create(reminder);
  }

  static async getBilReminder(serialNum: string): Promise<BilReminder | null> {
    return this.bilReminderMapper.getById(serialNum);
  }

  static async updateBilReminder(
    serialNum: string,
    reminder: BilReminderUpdate,
  ): Promise<BilReminder> {
    return this.bilReminderMapper.update(serialNum, reminder);
  }

  static async updateBilReminderActive(serialNum: string, isActive: boolean): Promise<BilReminder> {
    return this.bilReminderMapper.updateActive(serialNum, isActive);
  }

  static async deleteBilReminder(serialNum: string): Promise<void> {
    return this.bilReminderMapper.deleteById(serialNum);
  }

  static async listBilReminders(): Promise<BilReminder[]> {
    return this.bilReminderMapper.list();
  }

  static async listBilRemindersPaged(
    query: PageQuery<BilReminderFilters> = {
      currentPage: 1,
      pageSize: 10,
      sortOptions: {},
      filter: {},
    },
  ): Promise<PagedResult<BilReminder>> {
    return this.bilReminderMapper.listPaged(query);
  }
  // ========================= BilReminder End =========================

  // ========================= Currency Start =========================
  // Currency 操作
  static async createCurrency(currency: Currency): Promise<Currency> {
    return this.currencyMapper.create(currency);
  }

  static async getCurrency(code: string): Promise<Currency | null> {
    return this.currencyMapper.getById(code);
  }

  static async updateCurrency(code: string, currency: CurrencyUpdate): Promise<Currency> {
    return this.currencyMapper.update(code, currency);
  }

  static async deleteCurrency(code: string): Promise<void> {
    return this.currencyMapper.deleteById(code);
  }

  static async getCurrencyByCode(code: string): Promise<Currency | null> {
    return this.currencyMapper.getById(code);
  }

  static async listCurrencies(): Promise<Currency[]> {
    return this.currencyMapper.list();
  }
  // ========================= Currency End =========================

  // FamilyMember 操作
  static async createFamilyMember(member: FamilyMemberCreate): Promise<FamilyMember> {
    return this.familyMemberMapper.create(member);
  }

  static async getFamilyMember(serialNum: string): Promise<FamilyMember | null> {
    return this.familyMemberMapper.getById(serialNum);
  }

  static async listFamilyMembers(): Promise<FamilyMember[]> {
    return this.familyMemberMapper.list();
  }

  static async updateFamilyMember(
    serialNum: string,
    member: FamilyMemberUpdate,
  ): Promise<FamilyMember> {
    return this.familyMemberMapper.update(serialNum, member);
  }

  static async deleteFamilyMember(serialNum: string): Promise<void> {
    return this.familyMemberMapper.deleteById(serialNum);
  }

  static async listFamilyMembersPaged(
    query: PageQuery<BilReminderFilters> = {
      currentPage: 1,
      pageSize: 10,
      sortOptions: {},
      filter: {},
    },
  ): Promise<PagedResult<FamilyMember>> {
    return this.familyMemberMapper.listPaged(query);
  }

  // FamilyLedger 操作
  static async createFamilyLedger(ledger: FamilyLedgerCreate): Promise<FamilyLedger> {
    return this.familyLedgerMapper.create(ledger);
  }

  static async getFamilyLedger(serialNum: string): Promise<FamilyLedger | null> {
    return this.familyLedgerMapper.getById(serialNum);
  }

  static async listFamilyLedgers(): Promise<FamilyLedger[]> {
    return this.familyLedgerMapper.list();
  }

  static async updateFamilyLedger(
    serialNum: string,
    ledger: FamilyLedgerUpdate,
  ): Promise<FamilyLedger> {
    return this.familyLedgerMapper.update(serialNum, ledger);
  }

  static async deleteFamilyLedger(serialNum: string): Promise<void> {
    return this.familyLedgerMapper.deleteById(serialNum);
  }

  static async listFamilyLedgersPaged(
    query: PageQuery<FamilyLedgerFilters> = {
      currentPage: 1,
      pageSize: 10,
      sortOptions: {},
      filter: {},
    },
  ): Promise<PagedResult<FamilyLedger>> {
    return this.familyLedgerMapper.listPaged(query);
  }

  // FamilyLedgerAccount 操作
  static async createFamilyLedgerAccount(
    assoc: FamilyLedgerAccountCreate,
  ): Promise<FamilyLedgerAccount> {
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

  static async updateFamilyLedgerAccount(
    serialNum: string,
    assoc: FamilyLedgerAccountUpdate,
  ): Promise<FamilyLedgerAccount> {
    return this.familyLedgerAccountMapper.update(serialNum, assoc);
  }

  static async deleteFamilyLedgerAccount(serialNum: string): Promise<void> {
    return this.familyLedgerAccountMapper.deleteById(serialNum);
  }

  // FamilyLedgerTransaction 操作
  static async createFamilyLedgerTransaction(
    assoc: FamilyLedgerTransactionCreate,
  ): Promise<FamilyLedgerTransaction> {
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
    assoc: FamilyLedgerMemberCreate,
  ): Promise<FamilyLedgerMember> {
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

  // Category
  static async listCategory(): Promise<Category[]> {
    return this.categoryMapper.list();
  }

  static async listSubCategory(): Promise<SubCategory[]> {
    return this.subCategoryMapper.list();
  }
}
