import { invokeCommand } from '@/types/api';
import { toCamelCase } from '@/utils/common';
import { DateUtils } from '@/utils/date';
import { db } from '@/utils/dbUtils';
import { Lg } from '@/utils/debugLog';
import { BaseMapper } from './baseManager';
import type { PagedResult } from './baseManager';
import type {
  AccountBalanceSummary,
  DateRange,
  SortOptions,
} from '@/schema/common';
import type {
  Account,
  AccountResponseWithRelations,
  CreateAccountRequest,
  UpdateAccountRequest,
} from '@/schema/money';

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
export class AccountMapper extends BaseMapper<
  CreateAccountRequest,
  UpdateAccountRequest,
  AccountResponseWithRelations
> {
  protected tableName = 'account';
  protected entityName = 'Account';

  protected getBooleanFields(): string[] {
    return ['isShared', 'isActive'];
  }

  async create(
    account: CreateAccountRequest,
  ): Promise<AccountResponseWithRelations> {
    try {
      return await invokeCommand<AccountResponseWithRelations>(
        'create_account',
        { data: account },
      );
    } catch (error) {
      this.handleError('create', error);
    }
  }

  async getById(
    serialNum: string,
  ): Promise<AccountResponseWithRelations | null> {
    try {
      const account = await invokeCommand<AccountResponseWithRelations>(
        'get_account',
        {
          serialNum,
        },
      );
      return account;
    } catch (error) {
      this.handleError('getById', error);
    }
  }

  async list(): Promise<AccountResponseWithRelations[]> {
    try {
      return await invokeCommand<AccountResponseWithRelations[]>(
        'list_accounts',
      );
    } catch (error) {
      this.handleError('list', error);
    }
  }

  async update(
    account: UpdateAccountRequest,
  ): Promise<AccountResponseWithRelations> {
    try {
      const result = await invokeCommand<AccountResponseWithRelations>(
        'update_account',
        { serialNum: account.serialNum, data: account },
      );
      Lg.d('MoneyDb', 'Account updated:', account.serialNum);
      return result;
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
      await invokeCommand('delete_account', { serialNum });
    } catch (error) {
      this.handleError('deleteById', error);
    }
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
        DateUtils.getLocalISODateTimeWithOffset(), // 使用当前时间戳
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
