/**
 * 账户服务
 * 提供账户的 CRUD 操作和业务逻辑
 * @module services/money/AccountService
 */

import type { AccountBalanceSummary, PageQuery } from '@/schema/common';
import type { Account, CreateAccountRequest, UpdateAccountRequest } from '@/schema/money';
import { wrapError } from '@/utils/errorHandler';
import { BaseService, type IMapper } from '../base/BaseService';
import type { PagedResult } from '../base/types';
import { type AccountFilters, AccountMapper } from './accounts';

/**
 * 账户服务类
 * 继承 BaseService，提供账户相关的业务逻辑
 */
class AccountService extends BaseService<Account, CreateAccountRequest, UpdateAccountRequest> {
  private accountMapper: AccountMapper;

  constructor() {
    const mapper = new AccountMapper();
    // Create an adapter to match IMapper interface
    const mapperAdapter: IMapper<Account, CreateAccountRequest, UpdateAccountRequest> = {
      create: data => mapper.create(data),
      getById: id => mapper.getById(id),
      list: () => mapper.list(),
      update: (id, data) => mapper.update(id, data),
      delete: id => mapper.deleteById(id),
    };
    super('account', mapperAdapter);
    this.accountMapper = mapper;
  }

  /**
   * 删除账户（覆盖基类方法以使用正确的 Mapper 方法）
   */
  async delete(id: string): Promise<void> {
    try {
      await this.accountMapper.deleteById(id);
    } catch (error) {
      throw wrapError('AccountService', error, 'DELETE_FAILED', `删除${this.commandPrefix}失败`);
    }
  }

  /**
   * 获取账户余额
   * @param accountId - 账户 ID
   * @returns 账户余额
   */
  async getBalance(accountId: string): Promise<number> {
    try {
      const account = await this.getById(accountId);
      return account?.balance ? Number.parseFloat(account.balance) : 0;
    } catch (error) {
      throw wrapError('AccountService', error, 'GET_BALANCE_FAILED', '获取余额失败');
    }
  }

  /**
   * 转账操作
   * 调用 Rust 后端的转账命令
   * @param fromId - 转出账户 ID
   * @param toId - 转入账户 ID
   * @param amount - 转账金额
   */
  async transfer(fromId: string, toId: string, amount: number): Promise<void> {
    try {
      await this.invokeCommand('transfer', {
        fromId,
        toId,
        amount,
      });
    } catch (error) {
      throw wrapError('AccountService', error, 'TRANSFER_FAILED', '转账失败');
    }
  }

  /**
   * 更新账户激活状态
   * @param serialNum - 账户序列号
   * @param isActive - 是否激活
   * @returns 更新后的账户
   */
  async updateActive(serialNum: string, isActive: boolean): Promise<Account> {
    try {
      return await this.accountMapper.updateAccountActive(serialNum, isActive);
    } catch (error) {
      throw wrapError('AccountService', error, 'UPDATE_ACTIVE_FAILED', '更新账户状态失败');
    }
  }

  /**
   * 分页查询账户
   * @param query - 分页查询参数
   * @returns 分页结果
   */
  async listPagedWithFilters(query: PageQuery<AccountFilters>): Promise<PagedResult<Account>> {
    try {
      const result = await this.accountMapper.listPaged(query);
      // 转换为标准 PagedResult 格式
      return {
        items: result.rows,
        total: result.totalCount,
        page: result.currentPage,
        pageSize: result.pageSize,
        totalPages: result.totalPages,
      };
    } catch (error) {
      throw wrapError('AccountService', error, 'LIST_PAGED_FAILED', '分页查询账户失败');
    }
  }

  /**
   * 获取总资产统计
   * @returns 资产汇总信息
   */
  async getTotalAssets(): Promise<AccountBalanceSummary> {
    try {
      return await this.accountMapper.totalAssets();
    } catch (error) {
      throw wrapError('AccountService', error, 'GET_TOTAL_ASSETS_FAILED', '获取总资产失败');
    }
  }
}

/**
 * 导出 AccountService 单例
 */
export const accountService = new AccountService();
