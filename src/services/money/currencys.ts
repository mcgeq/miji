import { toCamelCase } from '@/utils/common';
import { db } from '@/utils/dbUtils';
import { Lg } from '@/utils/debugLog';
import { BaseMapper } from './baseManager';
import type { Currency } from '@/schema/common';

/**
 * 货币数据映射器
 */
export class CurrencyMapper extends BaseMapper<Currency> {
  protected tableName = 'currency';
  protected entityName = 'Currency';

  async create(currency: Currency): Promise<void> {
    try {
      const { code, locale, symbol, createdAt, updatedAt } = currency;
      await db.execute(
        `INSERT INTO ${this.tableName} (code, locale, symbol, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?)`,
        [code, locale, symbol, createdAt, updatedAt],
      );
      Lg.d('MoneyDb', 'Currency created:', { code });
    }
    catch (error) {
      this.handleError('create', error);
    }
  }

  async getById(code: string): Promise<Currency | null> {
    try {
      const result = await db.select<Currency[]>(
        `SELECT * FROM ${this.tableName} WHERE code = ?`,
        [code],
        true,
      );
      return result.length > 0 ? result[0] : null;
    }
    catch (error) {
      this.handleError('getById', error);
    }
  }

  async list(): Promise<Currency[]> {
    try {
      const currencies = await db.select<Currency[]>(
        `SELECT * FROM ${this.tableName}`,
        [],
        true,
      );
      return toCamelCase<Currency[]>(currencies);
    }
    catch (error) {
      this.handleError('list', error);
    }
  }

  async update(currency: Currency): Promise<void> {
    try {
      const { code, locale, symbol, updatedAt } = currency;
      await db.execute(
        `UPDATE ${this.tableName} SET locale = ?, symbol = ?, updated_at = ?
         WHERE code = ?`,
        [locale, symbol, updatedAt, code],
      );
      Lg.d('MoneyDb', 'Currency updated:', { code });
    }
    catch (error) {
      this.handleError('update', error);
    }
  }

  async deleteById(code: string): Promise<void> {
    try {
      await db.execute(`DELETE FROM ${this.tableName} WHERE code = ?`, [code]);
      Lg.d('MoneyDb', 'Currency deleted:', { code });
    }
    catch (error) {
      this.handleError('deleteById', error);
    }
  }
}
