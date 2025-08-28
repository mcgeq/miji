import { invokeCommand } from '@/types/api';
import { DateUtils } from '@/utils/date';
import { BaseMapper } from './baseManager';
import type { PagedResult } from './baseManager';
import type {
  AccountBalanceSummary,
  DateRange,
  PageQuery,
} from '@/schema/common';
import type {
  Account,
  CreateAccountRequest,
  UpdateAccountRequest,
} from '@/schema/money';

// 查询过滤器接口
export interface AccountFilters {
  name?: string;
  type?: string;
  currency?: string;
  isShared?: boolean;
  ownerId?: string;
  isActive?: boolean;
  createdAtRange?: DateRange;
  updatedAtRange?: DateRange;
}

/**
 * 账户数据映射器
 */
export class AccountMapper extends BaseMapper<
  CreateAccountRequest,
  UpdateAccountRequest,
  Account
> {
  protected tableName = 'account';
  protected entityName = 'Account';

  async create(account: CreateAccountRequest): Promise<Account> {
    try {
      return await invokeCommand<Account>('create_account', { data: account });
    } catch (error) {
      this.handleError('create', error);
    }
  }

  async getById(serialNum: string): Promise<Account | null> {
    try {
      const account = await invokeCommand<Account>('get_account', {
        serialNum,
      });
      return account;
    } catch (error) {
      this.handleError('getById', error);
    }
  }

  async list(): Promise<Account[]> {
    try {
      return await invokeCommand<Account[]>('list_accounts', { filter: {} });
    } catch (error) {
      this.handleError('list', error);
    }
  }

  async update(
    serialNum: string,
    account: UpdateAccountRequest,
  ): Promise<Account> {
    try {
      const result = await invokeCommand<Account>('update_account', {
        serialNum,
        data: account,
      });
      return result;
    } catch (error) {
      this.handleError('update', error);
    }
  }

  async updateAccountActive(
    serialNum: string,
    isActive: boolean,
  ): Promise<Account> {
    try {
      console.log('updateAccountActive account ', isActive);
      return await invokeCommand<Account>('update_account_active', {
        serialNum,
        isActive,
      });
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
    query: PageQuery<AccountFilters> = {
      currentPage: 1,
      pageSize: 10,
      sortOptions: {},
      filter: {},
    },
  ): Promise<PagedResult<Account>> {
    try {
      const result = invokeCommand<PagedResult<Account>>(
        'list_accounts_paged_with_relations',
        { query },
      );
      return result;
    } catch (err) {
      this.handleError('totalAssets', err);
    }
  }

  async totalAssets(): Promise<AccountBalanceSummary> {
    try {
      const result = await invokeCommand<AccountBalanceSummary>('total_assets');
      return result;
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
}
