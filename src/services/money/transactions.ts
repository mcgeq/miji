import { db } from '@/utils/dbUtils';
import { Lg } from '@/utils/debugLog';
import { BaseMapper, MoneyDbError } from './baseManager';
import type { DateRange, PagedResult } from './baseManager';
import type { SortOptions } from '@/schema/common';
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
        createdAt,
        updatedAt,
      } = transaction;

      await db.execute(
        `INSERT INTO ${this.tableName} (serial_num, transaction_type, transaction_status, date, amount, currency, description, notes, account_serial_num, category, sub_category, tags, split_members, payment_method, actual_payer_account, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          serialNum,
          transactionType,
          transactionStatus,
          date,
          amount,
          JSON.stringify(currency),
          description,
          notes,
          accountSerialNum,
          category,
          subCategory,
          JSON.stringify(tags),
          JSON.stringify(splitMembers),
          paymentMethod,
          actualPayerAccount,
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

      return this.transformTransactionRow(result[0]);
    }
    catch (error) {
      this.handleError('getById', error);
    }
  }

  async list(): Promise<Transaction[]> {
    try {
      const result = await db.select<any[]>(
        `SELECT * FROM ${this.tableName}`,
        [],
        true,
      );
      return result.map(t => this.transformTransactionRow(t));
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
        updatedAt,
      } = transaction;

      await db.execute(
        `UPDATE ${this.tableName} SET transaction_type = ?, transaction_status = ?, date = ?, amount = ?, currency = ?, description = ?, notes = ?, account_serial_num = ?, category = ?, sub_category = ?, tags = ?, split_members = ?, payment_method = ?, actual_payer_account = ?, updated_at = ?
         WHERE serial_num = ?`,
        [
          transactionType,
          transactionStatus,
          date,
          amount,
          JSON.stringify(currency),
          description,
          notes,
          accountSerialNum,
          category,
          subCategory,
          JSON.stringify(tags),
          JSON.stringify(splitMembers),
          paymentMethod,
          actualPayerAccount,
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

    return await this.queryPaged(
      baseQuery,
      filters,
      page,
      pageSize,
      sortOptions,
      'date DESC, created_at DESC',
      row => this.transformTransactionRow(row),
    );
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
      row => this.transformTransactionWithAccountRow(row),
    );
  }

  private transformTransactionRow(row: any): Transaction {
    return {
      ...row,
      tags: JSON.parse(row.tags || '[]'),
      split_members: JSON.parse(row.split_members || '[]'),
      currency: JSON.parse(row.currency),
    } as Transaction;
  }

  private transformTransactionWithAccountRow(row: any): TransactionWithAccount {
    return {
      ...this.transformTransactionRow(row),
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
}
