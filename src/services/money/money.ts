import type {
  AccountBalanceSummary,
  Currency,
  CurrencyCrate,
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
  FamilyLedgerStats,
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
import type { AccountFilters } from './accounts';
import { AccountMapper } from './accounts';
import type { PagedResult } from './baseManager';
import type { BilReminderFilters } from './billReminder';
import { BilReminderMapper } from './billReminder';
import type { BudgetFilters } from './budgets';
import { BudgetMapper } from './budgets';
import { CategoryMapper } from './categories';
import { CurrencyMapper } from './currencys';
import type { FamilyLedgerFilters } from './family';
import {
  FamilyLedgerAccountMapper,
  FamilyLedgerMapper,
  FamilyLedgerMemberMapper,
  FamilyLedgerTransactionMapper,
  FamilyMemberMapper,
} from './family';
import { SubCategoryMapper } from './sub_categories';
import type {
  InstallmentPlanResponse,
  TransactionFilters,
  TransactionStatsRequest,
  TransactionStatsResponse,
} from './transactions';
import { TransactionMapper } from './transactions';

/**
 * 主要的 MoneyDb 类 - 使用映射器模式
 *
 * 这是一个门面（Facade）类，聚合了所有数据访问映射器
 * 提供统一的金融数据访问入口点
 */
class MoneyDbService {
  private accountMapper = new AccountMapper();
  private transactionMapper = new TransactionMapper();
  private budgetMapper = new BudgetMapper();
  private bilReminderMapper = new BilReminderMapper();
  private currencyMapper = new CurrencyMapper();
  private familyMemberMapper = new FamilyMemberMapper();
  private familyLedgerMapper = new FamilyLedgerMapper();
  private familyLedgerAccountMapper = new FamilyLedgerAccountMapper();
  private familyLedgerTransactionMapper = new FamilyLedgerTransactionMapper();
  private subCategoryMapper = new SubCategoryMapper();
  private categoryMapper = new CategoryMapper();
  private familyLedgerMemberMapper = new FamilyLedgerMemberMapper();

  // ========================= Account Start=========================
  // Account 操作
  async createAccount(account: CreateAccountRequest): Promise<Account> {
    return this.accountMapper.create(account);
  }

  async getAccount(serialNum: string): Promise<Account | null> {
    return this.accountMapper.getById(serialNum);
  }

  async listAccounts(): Promise<Account[]> {
    return this.accountMapper.list();
  }

  async updateAccount(serialNum: string, account: UpdateAccountRequest): Promise<Account> {
    return this.accountMapper.update(serialNum, account);
  }

  async updateAccountActive(serialNum: string, isActive: boolean): Promise<Account> {
    return this.accountMapper.updateAccountActive(serialNum, isActive);
  }

  async deleteAccount(serialNum: string): Promise<void> {
    return this.accountMapper.deleteById(serialNum);
  }

  async listAccountsPaged(
    query: PageQuery<AccountFilters> = {
      currentPage: 1,
      pageSize: 10,
      sortOptions: {},
      filter: {},
    },
  ): Promise<PagedResult<Account>> {
    return this.accountMapper.listPaged(query);
  }

  async totalAssets(): Promise<AccountBalanceSummary> {
    return await this.accountMapper.totalAssets();
  }
  // ========================= Account End =========================

  // ========================= Transaction Start=========================
  // Transaction 操作
  async createTransaction(transaction: TransactionCreate): Promise<Transaction> {
    return this.transactionMapper.create(transaction);
  }

  async getTransaction(serialNum: string): Promise<Transaction | null> {
    return this.transactionMapper.getById(serialNum);
  }

  async updateTransaction(serialNum: string, transaction: TransactionUpdate): Promise<Transaction> {
    return this.transactionMapper.update(serialNum, transaction);
  }

  async deleteTransaction(serialNum: string): Promise<void> {
    return this.transactionMapper.deleteById(serialNum);
  }

  async transferCreate(transfer: TransferCreate): Promise<[Transaction, Transaction]> {
    return this.transactionMapper.transfer(transfer);
  }

  async transferUpdate(
    serialNum: string,
    transfer: TransferCreate,
  ): Promise<[Transaction, Transaction]> {
    return this.transactionMapper.transferUpdate(serialNum, transfer);
  }

  async transferDelete(serialNum: string): Promise<[Transaction, Transaction]> {
    return this.transactionMapper.transferDelete(serialNum);
  }

  async listTransactions(): Promise<Transaction[]> {
    return this.transactionMapper.list();
  }

  async listTransactionsPaged(
    query: PageQuery<TransactionFilters>,
  ): Promise<PagedResult<Transaction>> {
    return this.transactionMapper.listPaged(query);
  }

  async monthlyIncomeAndExpense(): Promise<IncomeExpense> {
    return await this.transactionMapper.monthlyIncomeAndExpense();
  }

  async lastMonthIncomeAndExpense(): Promise<IncomeExpense> {
    return await this.transactionMapper.lastMonthIncomeAndExpense();
  }

  async yearlyIncomeAndExpense(): Promise<IncomeExpense> {
    return await this.transactionMapper.yearlyIncomeAndExpense();
  }

  async lastYearIncomeAndExpense(): Promise<IncomeExpense> {
    return this.transactionMapper.lastYearIncomeAndExpense();
  }

  async getTransactionStats(request: TransactionStatsRequest): Promise<TransactionStatsResponse> {
    return this.transactionMapper.getStats(request);
  }

  // 分期付款相关方法

  async getInstallmentPlan(planId: string): Promise<InstallmentPlanResponse> {
    return this.transactionMapper.getInstallmentPlan(planId);
  }

  async getPendingInstallments(): Promise<InstallmentPlanResponse[]> {
    return this.transactionMapper.getPendingInstallments();
  }
  // ========================= Transaction End =========================

  // ========================= Budget Start=========================
  // Budget 操作
  async createBudget(budget: BudgetCreate): Promise<Budget> {
    return this.budgetMapper.create(budget);
  }

  async getBudget(serialNum: string): Promise<Budget | null> {
    return this.budgetMapper.getById(serialNum);
  }

  async updateBudget(serialNum: string, budget: BudgetUpdate): Promise<Budget> {
    return this.budgetMapper.update(serialNum, budget);
  }

  async updateBudgetActive(serialNum: string, isActive: boolean): Promise<Budget> {
    return this.budgetMapper.updateActive(serialNum, isActive);
  }

  async deleteBudget(serialNum: string): Promise<void> {
    return this.budgetMapper.deleteById(serialNum);
  }

  async listBudgets(): Promise<Budget[]> {
    return this.budgetMapper.list();
  }

  async listBudgetsPaged(query: PageQuery<BudgetFilters>): Promise<PagedResult<Budget>> {
    return this.budgetMapper.listPaged(query);
  }
  // ========================= Budget End=========================

  // ========================= BilReminder Start =========================
  // BilReminder 操作
  async createBilReminder(reminder: BilReminderCreate): Promise<BilReminder> {
    return this.bilReminderMapper.create(reminder);
  }

  async getBilReminder(serialNum: string): Promise<BilReminder | null> {
    return this.bilReminderMapper.getById(serialNum);
  }

  async updateBilReminder(serialNum: string, reminder: BilReminderUpdate): Promise<BilReminder> {
    return this.bilReminderMapper.update(serialNum, reminder);
  }

  async updateBilReminderActive(serialNum: string, isActive: boolean): Promise<BilReminder> {
    return this.bilReminderMapper.updateActive(serialNum, isActive);
  }

  async deleteBilReminder(serialNum: string): Promise<void> {
    return this.bilReminderMapper.deleteById(serialNum);
  }

  async listBilReminders(): Promise<BilReminder[]> {
    return this.bilReminderMapper.list();
  }

  async listBilRemindersPaged(
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
  async createCurrency(currency: CurrencyCrate): Promise<Currency> {
    return this.currencyMapper.create(currency);
  }

  async getCurrency(code: string): Promise<Currency | null> {
    return this.currencyMapper.getById(code);
  }

  async updateCurrency(code: string, currency: CurrencyUpdate): Promise<Currency> {
    return this.currencyMapper.update(code, currency);
  }

  async deleteCurrency(code: string): Promise<void> {
    return this.currencyMapper.deleteById(code);
  }

  async getCurrencyByCode(code: string): Promise<Currency | null> {
    return this.currencyMapper.getById(code);
  }

  async listCurrencies(): Promise<Currency[]> {
    return this.currencyMapper.list();
  }
  // ========================= Currency End =========================

  // FamilyMember 操作
  async createFamilyMember(member: FamilyMemberCreate): Promise<FamilyMember> {
    return this.familyMemberMapper.create(member);
  }

  async getFamilyMember(serialNum: string): Promise<FamilyMember | null> {
    return this.familyMemberMapper.getById(serialNum);
  }

  async listFamilyMembers(): Promise<FamilyMember[]> {
    return this.familyMemberMapper.list();
  }

  async updateFamilyMember(serialNum: string, member: FamilyMemberUpdate): Promise<FamilyMember> {
    return this.familyMemberMapper.update(serialNum, member);
  }

  async deleteFamilyMember(serialNum: string): Promise<void> {
    return this.familyMemberMapper.deleteById(serialNum);
  }

  async listFamilyMembersPaged(
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
  async createFamilyLedger(ledger: FamilyLedgerCreate): Promise<FamilyLedger> {
    return this.familyLedgerMapper.create(ledger);
  }

  async getFamilyLedger(serialNum: string): Promise<FamilyLedger | null> {
    return this.familyLedgerMapper.getById(serialNum);
  }

  async getFamilyLedgerDetail(serialNum: string): Promise<FamilyLedger> {
    return this.familyLedgerMapper.getDetail(serialNum);
  }

  async listFamilyLedgers(): Promise<FamilyLedger[]> {
    return this.familyLedgerMapper.list();
  }

  async updateFamilyLedger(serialNum: string, ledger: FamilyLedgerUpdate): Promise<FamilyLedger> {
    return this.familyLedgerMapper.update(serialNum, ledger);
  }

  async getFamilyLedgerStats(serialNum: string): Promise<FamilyLedgerStats | null> {
    return this.familyLedgerMapper.getStats(serialNum);
  }

  async deleteFamilyLedger(serialNum: string): Promise<void> {
    return this.familyLedgerMapper.deleteById(serialNum);
  }

  async listFamilyLedgersPaged(
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
  async createFamilyLedgerAccount(assoc: FamilyLedgerAccountCreate): Promise<FamilyLedgerAccount> {
    return this.familyLedgerAccountMapper.create(assoc);
  }

  async getFamilyLedgerAccount(serialNum: string): Promise<FamilyLedgerAccount | null> {
    return this.familyLedgerAccountMapper.getById(serialNum);
  }

  async listFamilyLedgerAccounts(): Promise<FamilyLedgerAccount[]> {
    return this.familyLedgerAccountMapper.list();
  }

  async listFamilyLedgerAccountsByLedger(ledgerSerialNum: string): Promise<FamilyLedgerAccount[]> {
    return this.familyLedgerAccountMapper.listByLedger(ledgerSerialNum);
  }

  async listFamilyLedgerAccountsByAccount(
    accountSerialNum: string,
  ): Promise<FamilyLedgerAccount[]> {
    return this.familyLedgerAccountMapper.listByAccount(accountSerialNum);
  }

  async updateFamilyLedgerAccount(
    serialNum: string,
    assoc: FamilyLedgerAccountUpdate,
  ): Promise<FamilyLedgerAccount> {
    return this.familyLedgerAccountMapper.update(serialNum, assoc);
  }

  async deleteFamilyLedgerAccount(
    ledgerSerialNum: string,
    accountSerialNum: string,
  ): Promise<void> {
    return this.familyLedgerAccountMapper.delete(ledgerSerialNum, accountSerialNum);
  }

  // FamilyLedgerTransaction 操作
  async createFamilyLedgerTransaction(
    assoc: FamilyLedgerTransactionCreate,
  ): Promise<FamilyLedgerTransaction> {
    return this.familyLedgerTransactionMapper.create(assoc);
  }

  async getFamilyLedgerTransaction(serialNum: string): Promise<{
    familyLedgerSerialNum: string;
    transactionSerialNum: string;
  } | null> {
    return this.familyLedgerTransactionMapper.getById(serialNum);
  }

  async listFamilyLedgerTransactions(): Promise<
    { familyLedgerSerialNum: string; transactionSerialNum: string }[]
  > {
    return this.familyLedgerTransactionMapper.list();
  }

  async deleteFamilyLedgerTransaction(serialNum: string): Promise<void> {
    return this.familyLedgerTransactionMapper.deleteById(serialNum);
  }

  // 新增：根据账本查询关联的交易
  async listFamilyLedgerTransactionsByLedger(
    ledgerSerialNum: string,
  ): Promise<FamilyLedgerTransaction[]> {
    return this.familyLedgerTransactionMapper.listByLedger(ledgerSerialNum);
  }

  // 新增：根据交易查询关联的账本
  async listFamilyLedgerTransactionsByTransaction(
    transactionSerialNum: string,
  ): Promise<FamilyLedgerTransaction[]> {
    return this.familyLedgerTransactionMapper.listByTransaction(transactionSerialNum);
  }

  // 新增：批量创建交易与账本的关联
  async batchCreateFamilyLedgerTransactions(
    associations: FamilyLedgerTransactionCreate[],
  ): Promise<FamilyLedgerTransaction[]> {
    return this.familyLedgerTransactionMapper.batchCreate(associations);
  }

  // 新增：批量删除交易与账本的关联
  async batchDeleteFamilyLedgerTransactions(serialNums: string[]): Promise<void> {
    return this.familyLedgerTransactionMapper.batchDelete(serialNums);
  }

  // 新增：更新交易的账本关联
  async updateTransactionLedgers(
    transactionSerialNum: string,
    ledgerSerialNums: string[],
  ): Promise<FamilyLedgerTransaction[]> {
    return this.familyLedgerTransactionMapper.updateTransactionLedgers(
      transactionSerialNum,
      ledgerSerialNums,
    );
  }

  // FamilyLedgerMember 操作
  async createFamilyLedgerMember(assoc: FamilyLedgerMemberCreate): Promise<FamilyLedgerMember> {
    return this.familyLedgerMemberMapper.create(assoc);
  }

  async getFamilyLedgerMember(serialNum: string): Promise<{
    familyLedgerSerialNum: string;
    familyMemberSerialNum: string;
  } | null> {
    return this.familyLedgerMemberMapper.getById(serialNum);
  }

  async listFamilyLedgerMembers(): Promise<
    { familyLedgerSerialNum: string; familyMemberSerialNum: string }[]
  > {
    return this.familyLedgerMemberMapper.list();
  }

  async deleteFamilyLedgerMember(serialNum: string): Promise<void> {
    return this.familyLedgerMemberMapper.deleteById(serialNum);
  }

  // Category
  async listCategory(): Promise<Category[]> {
    return this.categoryMapper.list();
  }

  async createCategory(data: { name: string; icon: string }): Promise<Category> {
    return this.categoryMapper.create(data);
  }

  async listSubCategory(): Promise<SubCategory[]> {
    return this.subCategoryMapper.list();
  }

  async createSubCategory(data: {
    name: string;
    icon: string;
    categoryName: string;
  }): Promise<SubCategory> {
    return this.subCategoryMapper.create(data);
  }
}

// 导出单例实例
export const MoneyDb = new MoneyDbService();
