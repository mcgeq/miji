import { invokeCommand } from '@/types/api';
import { DateUtils } from '@/utils/date';
import { Lg } from '@/utils/debugLog';
import { BaseMapper } from './baseManager';
import type { PagedResult } from './baseManager';
import type {
  AccountBalanceSummary,
  DateRange,
  PageQuery,
} from '@/schema/common';
import type {
  AccountResponseWithRelations,
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
  AccountResponseWithRelations
> {
  protected tableName = 'account';
  protected entityName = 'Account';

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
        { filter: {} },
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
  ): Promise<AccountResponseWithRelations> {
    try {
      const account = await invokeCommand<AccountResponseWithRelations>(
        'update_account_active',
        { isActive },
      );
      Lg.d('MoneyDb', 'Account isActive updated:', { serialNum, isActive });
      return account;
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
  ): Promise<PagedResult<AccountResponseWithRelations>> {
    try {
      const result = invokeCommand<PagedResult<AccountResponseWithRelations>>(
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
