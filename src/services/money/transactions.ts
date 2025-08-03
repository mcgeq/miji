import { CURRENCY_CNY } from '@/constants/moneyConst';
import { toCamelCase } from '@/utils/common';
import { DateUtils } from '@/utils/date';
import { db } from '@/utils/dbUtils';
import { Lg } from '@/utils/debugLog';
import { BaseMapper, MoneyDbError } from './baseManager';
import type { PagedResult } from './baseManager';
import type { DateRange, IncomeExpense, SortOptions } from '@/schema/common';
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
    } catch (error) {
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
      const transaction = this.transformTransactionRow(result[0]);
      return transaction;
    } catch (error) {
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

      const transaction = this.transformTransactionRow(result[0]);
      return transaction;
    } catch (error) {
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
               a.initial_balance as account_initial_balance,
               a.is_shared as account_is_shared,
               a.owner_id as account_owner_id,
               a.is_active as account_is_active,
               a.color as account_color,
               a.created_at as account_created_at,
               a.updated_at as account_updated_at,
               c.locale as account_currency_locale,
               c.code as account_currency_code,
               c.symbol as account_currency_symbol,
               c.created_at as account_currency_created_at,
               c.updated_at as account_currency_updated_at
         FROM ${this.tableName} t
         JOIN account a ON t.account_serial_num = a.serial_num
         JOIN currency c ON a.currency = c.code
         WHERE t.serial_num = ?`,
        [serialNum],
        true,
      );

      if (result.length === 0) return null;

      return this.transformTransactionWithAccountRow(result[0]);
    } catch (error) {
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
              a.initial_balance as account_initial_balance,
              a.currency as account_currency,
              a.is_shared as account_is_shared,
              a.owner_id as account_owner_id,
              a.is_active as account_is_active,
              a.color as account_color,
              a.created_at as account_created_at,
              a.updated_at as account_updated_at,
              c.locale as currency_locale,
              c.code as currency_code,
              c.symbol as currency_symbol,
              c.created_at as currency_created_at,
              c.updated_at as currency_updated_at,
              ca.locale as account_currency_locale,
              ca.code as account_currency_code,
              ca.symbol as account_currency_symbol,
              ca.created_at as account_currency_created_at,
              ca.updated_at as account_currency_updated_at
          FROM ${this.tableName} t
          JOIN account a ON t.account_serial_num = a.serial_num
          JOIN currency c ON t.currency = c.code
          JOIN currency ca ON a.currency = ca.code
          WHERE t.serial_num = ?`,
        [serialNum],
        true,
      );

      if (result.length === 0) return null;
      return this.transformTransactionWithAccountRow(result[0]);
    } catch (error) {
      this.handleError('getTransferRelatedTransactionWithAccount', error);
    }
  }

  async list(): Promise<Transaction[]> {
    try {
      const result = await db.select<any[]>(
        `SELECT
            t.*,
            c.locale as currency_locale,
            c.code as currency_code,
            c.symbol as currency_symbol,
            c.created_at as currency_created_at,
            c.updated_at as currency_updated_at
        FROM ${this.tableName} t
        JOIN currency c ON t.currency = c.code
        WHERE is_deleted = 0`,
        [],
        false,
      );

      const act = result.map(a => {
        return this.transformTransactionRow(a);
      });
      return act;
    } catch (error) {
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
    } catch (error) {
      this.handleError('update', error);
    }
  }

  async deleteById(serialNum: string): Promise<void> {
    try {
      await db.execute(`DELETE FROM ${this.tableName} WHERE serial_num = ?`, [
        serialNum,
      ]);
      Lg.d('MoneyDb', 'Transaction deleted:', { serialNum });
    } catch (error) {
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
    const baseQuery = `SELECT
            t.*,
            c.locale as currency_locale,
            c.code as currency_code,
            c.symbol as currency_symbol,
            c.created_at as currency_created_at,
            c.updated_at as currency_updated_at
        FROM ${this.tableName} t
        JOIN currency c ON t.currency = c.code
        WHERE is_deleted = 0`;

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
              a.initial_balance as account_initial_balance,
              a.currency as account_currency,
              a.is_shared as account_is_shared,
              a.owner_id as account_owner_id,
              a.is_active as account_is_active,
              a.color as account_color,
              a.created_at as account_created_at,
              a.updated_at as account_updated_at,
              c.locale as currency_locale,
              c.code as currency_code,
              c.symbol as currency_symbol,
              c.created_at as currency_created_at,
              c.updated_at as currency_updated_at,
              ca.locale as account_currency_locale,
              ca.code as account_currency_code,
              ca.symbol as account_currency_symbol,
              ca.created_at as account_currency_created_at,
              ca.updated_at as account_currency_updated_at
        FROM ${this.tableName} t
        JOIN account a ON t.account_serial_num = a.serial_num
        JOIN currency c ON t.currency = c.code
        JOIN currency ca ON a.currency = ca.code
        WHERE is_deleted = 0
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

  /**
   * 构建删除交易的 SQL 操作
   * @param serialNum 交易序列号
   */
  buildDeleteOperation(serialNum: string): { sql: string; params: any[] } {
    return {
      sql: `DELETE FROM ${this.tableName} WHERE serial_num = ?`,
      params: [serialNum],
    };
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
    WHERE date >= ? AND date < ? and is_deleted = 0;
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
    } catch (error) {
      this.handleError('queryIncomeAndExpense', error);
    }
  }

  private transformTransactionRow(row: any): any {
    return toCamelCase<Transaction>({
      serial_num: row.serial_num,
      transaction_type: row.transaction_type,
      transaction_status: row.transaction_status,
      date: row.date,
      amount: row.amount,
      currency: {
        locale: row.currency_locale,
        code: row.currency_code,
        symbol: row.currency_symbol,
        created_at: row.currency_created_at,
        updated_at: row.currency_updated_at,
      },
      description: row.description,
      notes: row.notes,
      account_serial_num: row.account_serial_num,
      category: row.category,
      sub_category: row.sub_category,
      tags: JSON.parse(row.tags || '[]'),
      split_members: JSON.parse(row.split_members || '[]'),
      payment_method: row.payment_method,
      actual_payer_account: row.actual_payer_account,
      related_transaction_serial_num: row.related_transaction_serial_num,
      created_at: row.created_at,
      updated_at: row.updated_at,
    });
  }

  private async transformTransactionWithAccountRow(
    row: any,
  ): Promise<TransactionWithAccount> {
    return toCamelCase<TransactionWithAccount>({
      serial_num: row.serial_num,
      transaction_type: row.transaction_type,
      transaction_status: row.transaction_status,
      date: row.date,
      amount: row.amount,
      currency: {
        locale: row.currency_locale,
        code: row.currency_code,
        symbol: row.currency_symbol,
        created_at: row.currency_created_at,
        updated_at: row.currency_updated_at,
      },
      account: {
        serial_num: row.account_serial_num_detail,
        name: row.account_name,
        description: row.account_description,
        type: row.account_type,
        balance: row.account_balance,
        initial_balance: row.account_initial_balance,
        currency: {
          locale: row.account_currency_locale,
          code: row.account_currency_code,
          symbol: row.account_currency_symbol,
          created_at: row.account_currency_created_at,
          updated_at: row.account_currency_updated_at,
        },
        is_shared: row.account_is_shared,
        owner_id: row.account_owner_id,
        is_active: row.account_is_active,
        color: row.account_color,
        created_at: row.account_created_at,
        updated_at: row.account_updated_at,
      },
      description: row.description,
      notes: row.notes,
      account_serial_num: row.account_serial_num,
      category: row.category,
      sub_category: row.sub_category,
      tags: JSON.parse(row.tags || '[]'),
      split_members: JSON.parse(row.split_members || '[]'),
      payment_method: row.payment_method,
      actual_payer_account: row.actual_payer_account,
      related_transaction_serial_num: row.related_transaction_serial_num,
      created_at: row.created_at,
      updated_at: row.updated_at,
    });
  }
}
