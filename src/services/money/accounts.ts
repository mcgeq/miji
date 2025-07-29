import { CURRENCY_CNY } from '@/constants/moneyConst';
import { toCamelCase } from '@/utils/common';
import { DateUtils } from '@/utils/date';
import { db } from '@/utils/dbUtils';
import { Lg } from '@/utils/debugLog';
import { BaseMapper, MoneyDbError } from './baseManager';
import type { DateRange, PagedResult } from './baseManager';
import type { Currency, SortOptions } from '@/schema/common';
import type { Account } from '@/schema/money';

// 查询过滤器接口
export interface AccountFilters {
  type?: string;
  isActive?: boolean;
  isShared?: boolean;
  ownerId?: string;
  createdAtRange?: DateRange;
  updatedAtRange?: DateRange;
}

/**
 * 账户数据映射器
 */
export class AccountMapper extends BaseMapper<Account> {
  protected tableName = 'account';
  protected entityName = 'Account';

  protected getBooleanFields(): string[] {
    return ['isShared', 'isActive'];
  }

  async create(account: Account): Promise<void> {
    try {
      const {
        serialNum,
        name,
        description,
        type,
        balance,
        currency,
        isShared,
        ownerId,
        isActive,
        color,
        createdAt,
        updatedAt,
      } = account;

      await db.execute(
        `INSERT INTO ${this.tableName} (serial_num, name, description, type, balance, currency, is_shared, owner_id, is_active, color, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          serialNum,
          name,
          description,
          type,
          balance,
          currency.code,
          this.toDbBoolean(isShared),
          ownerId,
          this.toDbBoolean(isActive),
          color,
          createdAt,
          updatedAt,
        ],
      );
      Lg.d('MoneyDb', 'Account created:', { account });
    }
    catch (error) {
      this.handleError('create', error);
    }
  }

  async getById(serialNum: string): Promise<Account | null> {
    try {
      const result = await db.select<any[]>(
        `SELECT * FROM ${this.tableName} WHERE serial_num = ?`,
        [serialNum],
        true,
      );

      if (result.length === 0) return null;

      const account = this.transformAccountRow(result[0]);
      account.currency = await this.getCurrencyByCode(account.currency);
      return toCamelCase<Account>(account) as Account;
    }
    catch (error) {
      this.handleError('getById', error);
    }
  }

  async list(): Promise<Account[]> {
    try {
      const accounts = await db.select<any[]>(
        `SELECT * FROM ${this.tableName}`,
        [],
        false,
      );

      // 批量获取货币信息以提高性能
      const currencyCodes = [...new Set(accounts.map(a => a.currency))];
      const currencies = await db.select<Currency[]>(
        `SELECT * FROM currency WHERE code IN (${currencyCodes.map(() => '?').join(',')})`,
        currencyCodes,
        true,
      );

      const currencyMap = this.keyBy(currencies, 'code');

      const act = accounts.map(a => {
        const transformed = this.transformAccountRow(a);
        return {
          ...transformed,
          currency: currencyMap[a.currency] ?? CURRENCY_CNY,
        };
      }) as Account[];
      return toCamelCase<Account[]>(act);
    }
    catch (error) {
      this.handleError('list', error);
    }
  }

  async update(account: Account): Promise<void> {
    try {
      const {
        serialNum,
        name,
        description,
        type,
        balance,
        currency,
        isShared,
        ownerId,
        isActive,
        color,
        updatedAt,
      } = account;

      await db.execute(
        `UPDATE ${this.tableName} SET name = ?, description = ?, type = ?, balance = ?, currency = ?, is_shared = ?, owner_id = ?, is_active = ?, color = ?, updated_at = ?
         WHERE serial_num = ?`,
        [
          name,
          description,
          type,
          balance,
          currency.code,
          this.toDbBoolean(isShared),
          ownerId,
          this.toDbBoolean(isActive),
          color,
          updatedAt,
          serialNum,
        ],
      );

      Lg.d('MoneyDb', 'Account updated:', { serialNum });
    }
    catch (error) {
      this.handleError('update', error);
    }
  }

  async updateAccountActive(
    serialNum: string,
    isActive: boolean,
  ): Promise<void> {
    try {
      await db.execute(
        `UPDATE ${this.tableName} SET is_active = ?, updated_at = ? WHERE serial_num = ?`,
        [
          this.toDbBoolean(isActive),
          DateUtils.getLocalISODateTimeWithOffset(),
          serialNum,
        ],
      );
      Lg.d('MoneyDb', 'Account isActive updated:', { serialNum, isActive });
    }
    catch (error) {
      this.handleError('updateAccountActive', error);
    }
  }

  async deleteById(serialNum: string): Promise<void> {
    try {
      await db.execute(`DELETE FROM ${this.tableName} WHERE serial_num = ?`, [
        serialNum,
      ]);
      Lg.d('MoneyDb', 'Account deleted:', { serialNum });
    }
    catch (error) {
      this.handleError('deleteById', error);
    }
  }

  async updateSmart(newAccount: Account): Promise<void> {
    const oldAccount = await this.getById(newAccount.serialNum);
    if (!oldAccount)
      throw new MoneyDbError('Account not found', 'updateSmart', 'Account');
    await this.doSmartUpdate(newAccount.serialNum, newAccount, oldAccount);
  }

  async updateAccountPartial(
    serialNum: string,
    updates: Partial<Account>,
  ): Promise<void> {
    await this.updatePartial(serialNum, updates);
  }

  async listPaged(
    filters: AccountFilters = {},
    page = 1,
    pageSize = 10,
    sortOptions: SortOptions = {},
  ): Promise<PagedResult<Account>> {
    const baseQuery = `SELECT * FROM ${this.tableName}`;

    const result = await this.queryPaged(
      baseQuery,
      filters,
      page,
      pageSize,
      sortOptions,
      'created_at DESC',
      row => this.transformAccountRow(row),
    );

    // 批量获取货币信息
    const currencyCodes = [...new Set(result.rows.map((a: any) => a.currency))];
    if (currencyCodes.length > 0) {
      const currencyMap = await this.getCurrencies(result.rows);

      result.rows = result.rows.map((a: any) => ({
        ...a,
        currency: currencyMap[a.currency] ?? CURRENCY_CNY,
      }));
    }

    return toCamelCase<PagedResult<Account>>(result);
  }

  private transformAccountRow(row: any): any {
    const booleanFields = this.getBooleanFields();
    booleanFields.forEach(field => {
      const f = this.toSnakeCase(field);
      row[f] = this.fromDbBoolean(row[f]);
    });
    return row;
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
