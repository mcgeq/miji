import { db } from '@/utils/dbUtils';
import { Lg } from '@/utils/debugLog';
import { BaseMapper, MoneyDbError } from './baseManager';
import type { PagedResult } from './baseManager';
import type { DateRange, SortOptions } from '@/schema/common';
import type { Budget } from '@/schema/money';

export interface BudgetFilters {
  category?: string;
  isActive?: boolean;
  accountSerialNum?: string;
  alertEnabled?: boolean;
  dateRange?: DateRange;
  createdAtRange?: DateRange;
}

/**
 * 预算数据映射器
 */
export class BudgetMapper extends BaseMapper<Budget> {
  protected tableName = 'budget';
  protected entityName = 'Budget';

  async create(budget: Budget): Promise<void> {
    try {
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

      await db.execute(
        `INSERT INTO ${this.tableName} (serial_num, description, account_serial_num, name, category, amount, currency, repeat_period, start_date, end_date, used_amount, is_active, alert_enabled, alert_threshold, color, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          serialNum,
          description,
          accountSerialNum,
          name,
          category,
          amount,
          JSON.stringify(currency),
          JSON.stringify(repeatPeriod),
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

      Lg.d('MoneyDb', 'Budget created:', { serialNum });
    }
    catch (error) {
      this.handleError('create', error);
    }
  }

  async getById(serialNum: string): Promise<Budget | null> {
    try {
      const result = await db.select<any[]>(
        `SELECT * FROM ${this.tableName} WHERE serial_num = ?`,
        [serialNum],
        true,
      );

      if (result.length === 0) return null;

      return this.transformBudgetRow(result[0]);
    }
    catch (error) {
      this.handleError('getById', error);
    }
  }

  async list(): Promise<Budget[]> {
    try {
      const result = await db.select<any[]>(
        `SELECT * FROM ${this.tableName}`,
        [],
        true,
      );
      return result.map(b => this.transformBudgetRow(b));
    }
    catch (error) {
      this.handleError('list', error);
    }
  }

  async update(budget: Budget): Promise<void> {
    try {
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

      await db.execute(
        `UPDATE ${this.tableName} SET description = ?, account_serial_num = ?, name = ?, category = ?, amount = ?, currency = ?, repeat_period = ?, start_date = ?, end_date = ?, used_amount = ?, is_active = ?, alert_enabled = ?, alert_threshold = ?, color = ?, updated_at = ?
         WHERE serial_num = ?`,
        [
          description,
          accountSerialNum,
          name,
          category,
          amount,
          JSON.stringify(currency),
          JSON.stringify(repeatPeriod),
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

      Lg.d('MoneyDb', 'Budget updated:', { serialNum });
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
      Lg.d('MoneyDb', 'Budget deleted:', { serialNum });
    }
    catch (error) {
      this.handleError('deleteById', error);
    }
  }

  async updateSmart(newBudget: Budget): Promise<void> {
    const oldBudget = await this.getById(newBudget.serialNum);
    if (!oldBudget)
      throw new MoneyDbError('Budget not found', 'updateSmart', 'Budget');
    await this.doSmartUpdate(newBudget.serialNum, newBudget, oldBudget);
  }

  async updateBudgetPartial(
    serialNum: string,
    updates: Partial<Budget>,
  ): Promise<void> {
    await this.updatePartial(serialNum, updates);
  }

  async listPaged(
    filters: BudgetFilters = {},
    page = 1,
    pageSize = 10,
    sortOptions: SortOptions = {},
  ): Promise<PagedResult<Budget>> {
    const baseQuery = `SELECT * FROM ${this.tableName}`;

    return await this.queryPaged(
      baseQuery,
      filters,
      page,
      pageSize,
      sortOptions,
      'created_at DESC',
      row => this.transformBudgetRow(row),
    );
  }

  private transformBudgetRow(row: any): Budget {
    return {
      ...row,
      repeat_period: JSON.parse(row.repeat_period || '{}'),
      currency: JSON.parse(row.currency),
    } as Budget;
  }
}
