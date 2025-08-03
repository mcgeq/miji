import { CURRENCY_CNY } from '@/constants/moneyConst';
import { toCamelCase } from '@/utils/common';
import { DateUtils } from '@/utils/date';
import { db } from '@/utils/dbUtils';
import { Lg } from '@/utils/debugLog';
import { BaseMapper, MoneyDbError } from './baseManager';
import type { PagedResult } from './baseManager';
import type {
  AccountBalanceSummary,
  Currency,
  DateRange,
  SortOptions,
} from '@/schema/common';
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
        initialBalance,
        currency,
        isShared,
        ownerId,
        isActive,
        color,
        createdAt,
        updatedAt,
      } = account;

      await db.execute(
        `INSERT INTO ${this.tableName} (serial_num, name, description, type, balance, initial_balance,currency, is_shared, owner_id, is_active, color, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
        [
          serialNum,
          name,
          description,
          type,
          balance,
          initialBalance,
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
      await this.recordOperationLog(
        'INSERT',
        account.serialNum,
        account,
        undefined,
      );
    } catch (error) {
      this.handleError('create', error);
    }
  }

  async getById(serialNum: string): Promise<Account | null> {
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

      const account = this.transformAccountRow(result[0]);
      return account;
    } catch (error) {
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
    } catch (error) {
      this.handleError('list', error);
    }
  }

  async update(account: Account): Promise<void> {
    try {
      const oldAccount = await this.getById(account.serialNum);
      if (!oldAccount) {
        this.handleError('update', 'Account not found');
      }
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
      const changes = this.detectChanges(oldAccount, account);
      await this.recordOperationLog(
        'UPDATE',
        account.serialNum,
        changes,
        oldAccount,
      );
    } catch (error) {
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
    } catch (error) {
      this.handleError('updateAccountActive', error);
    }
  }

  async deleteById(serialNum: string): Promise<void> {
    try {
      const oldAccount = await this.getById(serialNum);
      await db.execute(`DELETE FROM ${this.tableName} WHERE serial_num = ?`, [
        serialNum,
      ]);
      Lg.d('MoneyDb', 'Account deleted:', { serialNum });
      await this.recordOperationLog('DELETE', serialNum, undefined, oldAccount);
    } catch (error) {
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
    const baseQuery = `SELECT t.*,
              c.locale as currency_locale,
              c.code as currency_code,
              c.symbol as currency_symbol,
              c.created_at as currency_created_at,
              c.updated_at as currency_updated_at
          FROM ${this.tableName} t
          JOIN currency c ON t.currency = c.code
          `;

    const result = await this.queryPaged<Account>(
      baseQuery,
      filters,
      page,
      pageSize,
      sortOptions,
      'created_at DESC',
      row => this.transformAccountRow(row),
    );

    return result;
  }

  async totalAssets(): Promise<AccountBalanceSummary> {
    const query = `SELECT
          SUM(CASE WHEN type IN ('Savings', 'Bank') THEN balance ELSE 0 END) AS bankSavingsBalance,
          SUM(CASE WHEN type = 'Cash' THEN balance ELSE 0 END) AS cashBalance,
          SUM(CASE WHEN type = 'CreditCard' THEN ABS(balance) ELSE 0 END) AS creditCardBalance,
          SUM(CASE WHEN type = 'Investment' THEN balance ELSE 0 END) AS investmentBalance,
          SUM(CASE WHEN type = 'Alipay' THEN balance ELSE 0 END) AS alipayBalance,
          SUM(CASE WHEN type = 'WeChat' THEN balance ELSE 0 END) AS weChatBalance,
          SUM(CASE WHEN type = 'CloudQuickPass' THEN balance ELSE 0 END) AS cloudQuickPassBalance,
          SUM(CASE WHEN type = 'Other' THEN balance ELSE 0 END) AS otherBalance,
          SUM(balance) AS totalBalance,
          SUM(CASE WHEN type = 'CreditCard' THEN -balance ELSE balance END) AS adjustedNetWorth,
          SUM(CASE WHEN type NOT IN ('CreditCard') THEN balance ELSE 0 END) AS totalAssets
        FROM ${this.tableName}
        WHERE is_active = 1;
      `;

    try {
      const result = await db.select(query, [], false);
      return result[0];
    } catch (err) {
      this.handleError('totalAssets', err);
    }
  }

  /**
   * 构建更新账户余额的 SQL 操作
   * @param serialNum 账户序列号
   * @param amountDelta 余额变化量（正数为增加，负数为减少）
   */
  buildUpdateBalanceOperation(
    serialNum: string,
    amountDelta: number,
  ): { sql: string; params: any[] } {
    return {
      sql: `UPDATE ${this.tableName} 
            SET balance = CAST(balance AS REAL) + ?, 
                updated_at = ? 
            WHERE serial_num = ?`,
      params: [
        amountDelta,
        new Date().toISOString(), // 使用当前时间戳
        serialNum,
      ],
    };
  }

  private transformAccountRow(row: any): any {
    const booleanFields = this.getBooleanFields();
    booleanFields.forEach(field => {
      const f = this.toSnakeCase(field);
      row[f] = this.fromDbBoolean(row[f]);
    });
    return toCamelCase<Account>({
      serial_num: row.serial_num,
      name: row.name,
      description: row.description,
      type: row.type,
      balance: row.balance,
      initial_balance: row.initial_balance,
      currency: {
        locale: row.currency_locale,
        code: row.currency_code,
        symbol: row.currency_symbol,
        created_at: row.currency_created_at,
        updated_at: row.currency_updated_at,
      },
      is_shared: row.is_shared,
      owner_id: row.owner_id,
      is_active: row.is_active,
      color: row.color,
      created_at: row.created_at,
      updated_at: row.updated_at,
    });
  }
}
