import type { AccountBalanceSummary, DateRange, PageQuery } from '@/schema/common';
import type { Account, CreateAccountRequest, UpdateAccountRequest } from '@/schema/money';
import { invokeCommand } from '@/types/api';
import type { PagedResult } from './baseManager';
import { BaseMapper } from './baseManager';

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
export class AccountMapper extends BaseMapper<CreateAccountRequest, UpdateAccountRequest, Account> {
  protected entityName = 'Account';

  async create(account: CreateAccountRequest): Promise<Account> {
    try {
      return await invokeCommand<Account>('account_create', { data: account });
    } catch (error) {
      this.handleError('create', error);
    }
  }

  async getById(serialNum: string): Promise<Account | null> {
    try {
      const account = await invokeCommand<Account>('account_get', {
        serialNum,
      });
      return account;
    } catch (error) {
      this.handleError('getById', error);
    }
  }

  async list(): Promise<Account[]> {
    try {
      return await invokeCommand<Account[]>('account_list', { filter: {} });
    } catch (error) {
      this.handleError('list', error);
    }
  }

  async update(serialNum: string, account: UpdateAccountRequest): Promise<Account> {
    try {
      const result = await invokeCommand<Account>('account_update', {
        serialNum,
        data: account,
      });
      return result;
    } catch (error) {
      this.handleError('update', error);
    }
  }

  async updateAccountActive(serialNum: string, isActive: boolean): Promise<Account> {
    try {
      return await invokeCommand<Account>('account_update_active', {
        serialNum,
        isActive,
      });
    } catch (error) {
      this.handleError('updateAccountActive', error);
    }
  }

  async deleteById(serialNum: string): Promise<void> {
    try {
      await invokeCommand('account_delete', { serialNum });
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
      const result = invokeCommand<PagedResult<Account>>('account_list_paged', {
        query,
      });
      return result;
    } catch (err) {
      this.handleError('listPaged', err);
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
}
