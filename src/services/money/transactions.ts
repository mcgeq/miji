import { CURRENCY_CNY } from '@/constants/moneyConst';
import { toCamelCase } from '@/utils/common';
import { db } from '@/utils/dbUtils';
import { Lg } from '@/utils/debugLog';
import { BaseMapper, MoneyDbError } from './baseManager';
import { MoneyDb } from './money';
import type { DateRange, PagedResult } from './baseManager';
import type { Currency, SortOptions } from '@/schema/common';
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
        `SELECT * FROM ${this.tableName} WHERE serial_num = ?`,
        [serialNum],
        true,
      );

      if (result.length === 0) return null;
      const transaction = this.transformTransactionRow(result[0]);
      transaction.currency = await this.getCurrencyByCode(transaction.currency);
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
        `SELECT * FROM ${this.tableName} WHERE related_transaction_serial_num = ?`,
        [serialNum],
        true,
      );

      if (result.length === 0) return null;
      const transaction = this.transformTransactionRow(result[0]);
      transaction.currency = await this.getCurrencyByCode(transaction.currency);
      return toCamelCase<Transaction>(transaction);
    }
    catch (error) {
      this.handleError('getTransferRelatedTransaction', error);
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

  private async getCurrencyByCode(code: string): Promise<Currency> {
    const result = await db.select<Currency[]>(
      'SELECT * FROM currency WHERE code = ?',
      [code],
      true,
    );
    return result.length > 0 ? result[0] : CURRENCY_CNY;
  }
}
