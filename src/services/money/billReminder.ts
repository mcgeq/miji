import { db } from '@/utils/dbUtils';
import { Lg } from '@/utils/debugLog';
import { BaseMapper } from './baseManager';
import type { DateRange, PagedResult } from './baseManager';
import type { SortOptions } from '@/schema/common';
import type { BilReminder } from '@/schema/money';

export interface BilReminderFilters {
  type?: string;
  enabled?: boolean;
  category?: string;
  isPaid?: boolean;
  priority?: string;
  dueDateRange?: DateRange;
  createdAtRange?: DateRange;
}

/**
 * 账单提醒数据映射器
 */
export class BilReminderMapper extends BaseMapper<BilReminder> {
  protected tableName = 'bil_reminder';
  protected entityName = 'BilReminder';

  async create(reminder: BilReminder): Promise<void> {
    try {
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

      await db.execute(
        `INSERT INTO ${this.tableName} (serial_num, name, enabled, type, description, category, amount, currency, due_date, bill_date, remind_date, repeat_period, is_paid, priority, advance_value, advance_unit, color, related_transaction_serial_num, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          serialNum,
          name,
          enabled,
          type,
          description,
          category,
          amount,
          JSON.stringify(currency),
          dueDate,
          billDate,
          remindDate,
          JSON.stringify(repeatPeriod),
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

      Lg.d('MoneyDb', 'BilReminder created:', { serialNum });
    }
    catch (error) {
      this.handleError('create', error);
    }
  }

  async getById(serialNum: string): Promise<BilReminder | null> {
    try {
      const result = await db.select<any[]>(
        `SELECT * FROM ${this.tableName} WHERE serial_num = ?`,
        [serialNum],
        true,
      );

      if (result.length === 0) return null;

      const reminder = result[0];
      return {
        ...reminder,
        repeat_period: JSON.parse(reminder.repeat_period || '{}'),
        currency: JSON.parse(reminder.currency),
      } as BilReminder;
    }
    catch (error) {
      this.handleError('getById', error);
    }
  }

  async list(): Promise<BilReminder[]> {
    try {
      const result = await db.select<any[]>(
        `SELECT * FROM ${this.tableName}`,
        [],
        true,
      );
      return result.map(r => ({
        ...r,
        repeat_period: JSON.parse(r.repeat_period || '{}'),
        currency: JSON.parse(r.currency),
      })) as BilReminder[];
    }
    catch (error) {
      this.handleError('list', error);
    }
  }

  async update(reminder: BilReminder): Promise<void> {
    try {
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

      await db.execute(
        `UPDATE ${this.tableName} SET name = ?, enabled = ?, type = ?, description = ?, category = ?, amount = ?, currency = ?, due_date = ?, bill_date = ?, remind_date = ?, repeat_period = ?, is_paid = ?, priority = ?, advance_value = ?, advance_unit = ?, color = ?, related_transaction_serial_num = ?, updated_at = ?
         WHERE serial_num = ?`,
        [
          name,
          enabled,
          type,
          description,
          category,
          amount,
          JSON.stringify(currency),
          dueDate,
          billDate,
          remindDate,
          JSON.stringify(repeatPeriod),
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

      Lg.d('MoneyDb', 'BilReminder updated:', { serialNum });
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
      Lg.d('MoneyDb', 'BilReminder deleted:', { serialNum });
    }
    catch (error) {
      this.handleError('deleteById', error);
    }
  }

  async listPaged(
    filters: BilReminderFilters = {},
    page = 1,
    pageSize = 10,
    sortOptions: SortOptions = {},
  ): Promise<PagedResult<BilReminder>> {
    const baseQuery = `SELECT * FROM ${this.tableName}`;
    return await this.queryPaged(
      baseQuery,
      filters,
      page,
      pageSize,
      sortOptions,
      'due_date ASC, created_at DESC',
      row => ({
        ...row,
        repeat_period: JSON.parse(row.repeat_period || '{}'),
        currency: JSON.parse(row.currency),
      }),
    );
  }
}
