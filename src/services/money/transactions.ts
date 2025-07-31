import { CURRENCY_CNY } from '@/constants/moneyConst';
import { toCamelCase } from '@/utils/common';
import { DateUtils } from '@/utils/date';
import { db } from '@/utils/dbUtils';
import { Lg } from '@/utils/debugLog';
import { BaseMapper, MoneyDbError } from './baseManager';
import { MoneyDb } from './money';
import type { DateRange, PagedResult } from './baseManager';
import type { IncomeExpense, SortOptions } from '@/schema/common';
import type { Transaction, TransactionWithAccount } from '@/schema/money';

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

/**
 * 交易数据映射器
 */
export class TransactionMapper extends BaseMapper<Transaction> {
  protected tableName = 'transactions';
  protected entityName = 'Transaction';

  async create(transaction: Transaction): Promise<void> {
    try {
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
        relatedTransactionSerialNum,
        createdAt,
        updatedAt,
      } = transaction;

      await db.execute(
        `INSERT INTO ${this.tableName} (serial_num, transaction_type, transaction_status, date, amount, currency, description, notes, account_serial_num, category, sub_category, tags, split_members, payment_method, actual_payer_account, related_transaction_serial_num, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          serialNum,
          transactionType,
          transactionStatus,
          date,
          amount,
          currency.code,
          description,
          notes,
          accountSerialNum,
          category,
          subCategory,
          JSON.stringify(tags),
          JSON.stringify(splitMembers),
          paymentMethod,
          actualPayerAccount,
          relatedTransactionSerialNum || null,
          createdAt,
          updatedAt,
        ],
      );

      Lg.d('MoneyDb', 'Transaction created:', { serialNum });
    }
    catch (error) {
      this.handleError('create', error);
    }
  }

  async getById(serialNum: string): Promise<Transaction | null> {
    try {
      const result = await db.select<any[]>(
        `SELECT t.*,
                c.locale as currency_locale,
                c.code as currency_code,
                c.symbol as currency_symbol,
                c.created_at as currency_created_at,
                c.updated_at as currency_updated_at
          FROM ${this.tableName} t
          JOIN currency c ON t.currency = c.code
          WHERE serial_num = ?`,
        [serialNum],
        true,
      );

      if (result.length === 0) return null;
      const row = result[0];
      const ccy = {
        locale: row.currency_locale,
        code: row.currency_code,
        symbol: row.currency_symbol,
        created_at: row.currency_created_at,
        updated_at: row.currency_updated_at,
      };
      const transaction = this.transformTransactionRow(row);
      transaction.currency = ccy;
      return toCamelCase<Transaction>(transaction);
    }
    catch (error) {
      this.handleError('getById', error);
    }
  }

  async getTransferRelatedTransaction(
    serialNum: string,
  ): Promise<Transaction | null> {
    try {
      const result = await db.select<any[]>(
        `SELECT t.*,
                c.locale as currency_locale,
                c.code as currency_code,
                c.symbol as currency_symbol,
                c.created_at as currency_created_at,
                c.updated_at as currency_updated_at
          FROM ${this.tableName} t
          JOIN currency c ON t.currency = c.code
          WHERE related_transaction_serial_num = ?`,
        [serialNum],
        true,
      );

      if (result.length === 0) return null;
      const row = result[0];
      const ccy = {
        locale: row.currency_locale,
        code: row.currency_code,
        symbol: row.currency_symbol,
        created_at: row.currency_created_at,
        updated_at: row.currency_updated_at,
      };

      const transaction = this.transformTransactionRow(row);
      transaction.currency = ccy;
      return toCamelCase<Transaction>(transaction);
    }
    catch (error) {
      this.handleError('getTransferRelatedTransaction', error);
    }
  }

  async getTransactionWithAccount(
    serialNum: string,
  ): Promise<TransactionWithAccount | null> {
    try {
      const result = await db.select<any[]>(
        `SELECT t.*, 
               a.serial_num as account_serial_num_detail,
               a.name as account_name,
               a.description as account_description,
               a.type as account_type,
               a.balance as account_balance,
                c.locale as account_currency_locale,
                c.code as account_currency_code,
                c.symbol as account_currency_symbol,
                c.created_at as account_currency_created_at,
                c.updated_at as account_currency_updated_at,
               a.is_shared as account_is_shared,
               a.owner_id as account_owner_id,
               a.is_active as account_is_active,
               a.color as account_color,
               a.created_at as account_created_at,
               a.updated_at as account_updated_at
         FROM transactions t
         JOIN account a ON t.account_serial_num = a.serial_num
         JOIN currency c ON a.currency = c.code
         WHERE t.serial_num = ?`,
        [serialNum],
        true,
      );

      if (result.length === 0) return null;

      const row = result[0];
      const ccy = {
        locale: row.account_currency_locale,
        code: row.account_currency_code,
        symbol: row.account_currency_symbol,
        created_at: row.account_currency_created_at,
        updated_at: row.account_currency_updated_at,
      };
      return toCamelCase<TransactionWithAccount>({
        ...row,
        tags: JSON.parse(row.tags || '[]'),
        split_members: JSON.parse(row.split_members || '[]'),
        currency: ccy,
        account: {
          serial_num: row.account_serial_num_detail,
          name: row.account_name,
          description: row.account_description,
          type: row.account_type,
          balance: row.account_balance,
          currency: ccy,
          is_shared: row.account_is_shared,
          owner_id: row.account_owner_id,
          is_active: row.account_is_active,
          color: row.account_color,
          created_at: row.account_created_at,
          updated_at: row.account_updated_at,
        },
      });
    }
    catch (error) {
      this.handleError('getTransactionWithAccount', error);
    }
  }

  async getTransferRelatedTransactionWithAccount(
    serialNum: string,
  ): Promise<TransactionWithAccount | null> {
    try {
      const result = await db.select<any[]>(
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
         JOIN account a ON t.account_serial_num = a.serial_num
         WHERE t.serial_num = ?`,
        [serialNum],
        true,
      );

      if (result.length === 0) return null;

      const row = result[0];
      return {
        ...row,
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
      } as TransactionWithAccount;
    }
    catch (error) {
      this.handleError('getTransferRelatedTransactionWithAccount', error);
    }
  }

  async list(): Promise<Transaction[]> {
    try {
      const result = await db.select<any[]>(
        `SELECT * FROM ${this.tableName}`,
        [],
        true,
      );

      const currencyMap = await this.getCurrencies(result);
      const act = result.map(a => {
        const transformed = this.transformTransactionRow(a);
        return {
          ...transformed,
          currency: currencyMap[a.currency] ?? CURRENCY_CNY,
        };
      }) as Transaction[];
      return toCamelCase<Transaction[]>(act);
    }
    catch (error) {
      this.handleError('list', error);
    }
  }

  async update(transaction: Transaction): Promise<void> {
    try {
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
        relatedTransactionSerialNum,
        updatedAt,
      } = transaction;

      await db.execute(
        `UPDATE ${this.tableName} SET transaction_type = ?, transaction_status = ?, date = ?, amount = ?, currency = ?, description = ?, notes = ?, account_serial_num = ?, category = ?, sub_category = ?, tags = ?, split_members = ?, payment_method = ?, actual_payer_account = ?, related_transaction_serial_num = ?, updated_at = ?
         WHERE serial_num = ?`,
        [
          transactionType,
          transactionStatus,
          date,
          amount,
          currency.code,
          description,
          notes,
          accountSerialNum,
          category,
          subCategory,
          JSON.stringify(tags),
          JSON.stringify(splitMembers),
          paymentMethod,
          actualPayerAccount,
          relatedTransactionSerialNum || null,
          updatedAt,
          serialNum,
        ],
      );

      Lg.d('MoneyDb', 'Transaction updated:', { serialNum });
    }
    catch (error) {
      this.handleError('update', error);
    }
  }

  async deleteById(serialNum: string): Promise<void> {
    try {
      await db.execute(`DELETE FROM ${this.tableName} WHERE serial_num = ?`, [
        serialNum,
      ]);
      Lg.d('MoneyDb', 'Transaction deleted:', { serialNum });
    }
    catch (error) {
      this.handleError('deleteById', error);
    }
  }

  async updateSmart(newTransaction: Transaction): Promise<void> {
    const oldTransaction = await this.getById(newTransaction.serialNum);
    if (!oldTransaction) {
      throw new MoneyDbError(
        'Transaction not found',
        'updateSmart',
        'Transaction',
      );
    }
    await this.doSmartUpdate(
      newTransaction.serialNum,
      newTransaction,
      oldTransaction,
    );
  }

  async updateTransactionPartial(
    serialNum: string,
    updates: Partial<Transaction>,
  ): Promise<void> {
    await this.updatePartial(serialNum, updates);
  }

  async listPaged(
    filters: TransactionFilters = {},
    page = 1,
    pageSize = 10,
    sortOptions: SortOptions = {},
  ): Promise<PagedResult<Transaction>> {
    const baseQuery = `SELECT * FROM ${this.tableName}`;

    const result = await this.queryPaged(
      baseQuery,
      filters,
      page,
      pageSize,
      sortOptions,
      'date DESC, created_at DESC',
      row => this.transformTransactionRow(row),
    );
    const currencyCodes = [...new Set(result.rows.map((a: any) => a.currency))];
    if (currencyCodes.length > 0) {
      const currencyMap = await this.getCurrencies(result.rows);
      result.rows = result.rows.map((a: any) => ({
        ...a,
        currency: currencyMap[a.currency] ?? CURRENCY_CNY,
      }));
    }
    return toCamelCase<PagedResult<Transaction>>(result);
  }

  async listWithAccountPaged(
    filters: TransactionFilters = {},
    page = 1,
    pageSize = 10,
    sortOptions: SortOptions = {},
  ): Promise<PagedResult<TransactionWithAccount>> {
    const baseQuery = `
      SELECT t.*, 
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
      FROM ${this.tableName} t
      JOIN account a ON t.account_serial_num = a.serial_num
    `;

    return await this.queryPaged(
      baseQuery,
      filters,
      page,
      pageSize,
      sortOptions,
      't.date DESC, t.created_at DESC',
      async row => await this.transformTransactionWithAccountRow(row),
    );
  }

  /**
   * 本月收入、支出与转账
   */
  async monthlyIncomeAndExpense(): Promise<IncomeExpense> {
    const [startDate, endDate] = DateUtils.getCurrentMonthRange();
    return this.queryIncomeAndExpense(startDate, endDate);
  }

  /**
   * 上个月收入、支出与转账
   */
  async lastMonthIncomeAndExpense(): Promise<IncomeExpense> {
    const [startDate, endDate] = DateUtils.getLastMonthRange();
    return this.queryIncomeAndExpense(startDate, endDate);
  }

  /**
   * 本年度收入、支出与转账
   */
  async yearlyIncomeAndExpense(): Promise<IncomeExpense> {
    const [startDate, endDate] = DateUtils.getCurrentYearRange();
    return this.queryIncomeAndExpense(startDate, endDate);
  }

  /**
   * 去年整年收入、支出与转账
   */
  async lastYearIncomeAndExpense(): Promise<IncomeExpense> {
    const [startDate, endDate] = DateUtils.getLastYearRange();
    return this.queryIncomeAndExpense(startDate, endDate);
  }

  private async queryIncomeAndExpense(
    startDate: string,
    endDate: string,
  ): Promise<IncomeExpense> {
    const query = `
    SELECT
      SUM(CASE WHEN transaction_type = 'Income' THEN amount ELSE 0 END) AS totalIncome,
      SUM(CASE WHEN transaction_type = 'Expense' THEN amount ELSE 0 END) AS totalExpense,
      SUM(CASE
            WHEN category = 'Transfer' AND transaction_type = 'Income' THEN amount ELSE 0 END) AS transferIncome,
      SUM(CASE
            WHEN category = 'Transfer' AND transaction_type = 'Expense' THEN amount ELSE 0 END) AS transferExpense
    FROM transactions
    WHERE date >= ? AND date < ?;
  `;
    try {
      const result = await db.select(query, [startDate, endDate], false);
      const row = result[0];
      return {
        income: {
          total: row?.totalIncome || 0,
          transfer: row?.transferIncome || 0,
        },
        expense: {
          total: row?.totalExpense || 0,
          transfer: row?.transferExpense || 0,
        },
        transfer: {
          income: 0,
          expense: 0,
        },
      };
    }
    catch (error) {
      console.error('查询失败:', error);
      throw error;
    }
  }

  private transformTransactionRow(row: any): any {
    return {
      ...row,
      tags: JSON.parse(row.tags || '[]'),
      split_members: JSON.parse(row.split_members || '[]'),
    } as Transaction;
  }

  private async transformTransactionWithAccountRow(
    row: any,
  ): Promise<TransactionWithAccount> {
    const account = await MoneyDb.getAccount(row.account_serial_num);
    return {
      ...this.transformTransactionRow(row),
      account,
    } as TransactionWithAccount;
  }
}
