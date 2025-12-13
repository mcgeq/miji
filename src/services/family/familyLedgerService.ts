/**
 * 家庭账本服务
 * 提供家庭账本的 CRUD 操作、成员管理和分摊计算
 * @module services/family/FamilyLedgerService
 */

import type { PageQuery } from '@/schema/common';
import type {
  FamilyLedger,
  FamilyLedgerAccount,
  FamilyLedgerAccountCreate,
  FamilyLedgerCreate,
  FamilyLedgerMember,
  FamilyLedgerMemberCreate,
  FamilyLedgerStats,
  FamilyLedgerTransaction,
  FamilyLedgerTransactionCreate,
  FamilyLedgerUpdate,
  FamilyMember,
  SplitResult,
} from '@/schema/money';
import { wrapError } from '@/utils/errorHandler';
import { BaseService, type IMapper } from '../base/BaseService';
import type { PagedResult } from '../base/types';
import {
  FamilyLedgerAccountMapper,
  type FamilyLedgerFilters,
  FamilyLedgerMapper,
  FamilyLedgerMemberMapper,
  FamilyLedgerTransactionMapper,
} from '../money/family';

/**
 * 家庭账本服务类
 * 继承 BaseService，提供家庭账本相关的业务逻辑
 */
class FamilyLedgerService extends BaseService<
  FamilyLedger,
  FamilyLedgerCreate,
  FamilyLedgerUpdate
> {
  private familyLedgerMapper: FamilyLedgerMapper;
  private familyLedgerAccountMapper: FamilyLedgerAccountMapper;
  private familyLedgerMemberMapper: FamilyLedgerMemberMapper;
  private familyLedgerTransactionMapper: FamilyLedgerTransactionMapper;

  constructor() {
    const mapper = new FamilyLedgerMapper();
    // Create an adapter to match IMapper interface
    const mapperAdapter: IMapper<FamilyLedger, FamilyLedgerCreate, FamilyLedgerUpdate> = {
      create: data => mapper.create(data),
      getById: id => mapper.getById(id),
      list: () => mapper.list(),
      update: (id, data) => mapper.update(id, data),
      delete: id => mapper.deleteById(id),
    };
    super('family_ledger', mapperAdapter);
    this.familyLedgerMapper = mapper;
    this.familyLedgerAccountMapper = new FamilyLedgerAccountMapper();
    this.familyLedgerMemberMapper = new FamilyLedgerMemberMapper();
    this.familyLedgerTransactionMapper = new FamilyLedgerTransactionMapper();
  }

  /**
   * 获取账本详情（包含成员和账户列表）
   * @param serialNum - 账本序列号
   * @returns 账本详情
   */
  async getDetail(serialNum: string): Promise<FamilyLedger> {
    try {
      return await this.familyLedgerMapper.getDetail(serialNum);
    } catch (error) {
      throw wrapError('FamilyLedgerService', error, 'GET_DETAIL_FAILED', '获取账本详情失败');
    }
  }

  /**
   * 获取账本统计信息
   * @param serialNum - 账本序列号
   * @returns 账本统计信息
   */
  async getStats(serialNum: string): Promise<FamilyLedgerStats | null> {
    try {
      return await this.familyLedgerMapper.getStats(serialNum);
    } catch (error) {
      throw wrapError('FamilyLedgerService', error, 'GET_STATS_FAILED', '获取账本统计失败');
    }
  }

  /**
   * 分页查询账本
   * @param query - 分页查询参数
   * @returns 分页结果
   */
  async listPagedWithFilters(
    query: PageQuery<FamilyLedgerFilters>,
  ): Promise<PagedResult<FamilyLedger>> {
    try {
      const result = await this.familyLedgerMapper.listPaged(query);
      // 转换为标准 PagedResult 格式
      return {
        items: result.rows,
        total: result.totalCount,
        page: result.currentPage,
        pageSize: result.pageSize,
        totalPages: result.totalPages,
      };
    } catch (error) {
      throw wrapError('FamilyLedgerService', error, 'LIST_PAGED_FAILED', '分页查询账本失败');
    }
  }

  // ==================== 成员管理 ====================

  /**
   * 添加成员到账本
   * @param ledgerSerialNum - 账本序列号
   * @param memberSerialNum - 成员序列号
   * @returns 账本成员关联
   */
  async addMember(ledgerSerialNum: string, memberSerialNum: string): Promise<FamilyLedgerMember> {
    try {
      const data: FamilyLedgerMemberCreate = {
        familyLedgerSerialNum: ledgerSerialNum,
        familyMemberSerialNum: memberSerialNum,
      };
      return await this.familyLedgerMemberMapper.create(data);
    } catch (error) {
      throw wrapError('FamilyLedgerService', error, 'ADD_MEMBER_FAILED', '添加成员失败');
    }
  }

  /**
   * 从账本移除成员
   * @param ledgerSerialNum - 账本序列号
   * @param memberSerialNum - 成员序列号
   */
  async removeMember(ledgerSerialNum: string, memberSerialNum: string): Promise<void> {
    try {
      // 查找关联记录
      const members = await this.familyLedgerMemberMapper.list();
      const member = members.find(
        m =>
          m.familyLedgerSerialNum === ledgerSerialNum &&
          m.familyMemberSerialNum === memberSerialNum,
      );

      if (!member) {
        throw new Error('成员关联不存在');
      }

      // 删除关联（需要使用复合键或序列号）
      await this.invokeCommand('remove_member', {
        ledgerSerialNum,
        memberSerialNum,
      });
    } catch (error) {
      throw wrapError('FamilyLedgerService', error, 'REMOVE_MEMBER_FAILED', '移除成员失败');
    }
  }

  /**
   * 获取账本的所有成员
   * @param ledgerSerialNum - 账本序列号
   * @returns 成员列表
   */
  async getMembers(ledgerSerialNum: string): Promise<FamilyMember[]> {
    try {
      // 调用 Rust 后端获取账本成员详情
      return await this.invokeCommand<FamilyMember[]>('get_members', {
        ledgerSerialNum,
      });
    } catch (error) {
      throw wrapError('FamilyLedgerService', error, 'GET_MEMBERS_FAILED', '获取成员列表失败');
    }
  }

  /**
   * 批量添加成员到账本
   * @param ledgerSerialNum - 账本序列号
   * @param memberSerialNums - 成员序列号列表
   * @returns 账本成员关联列表
   */
  async addMembers(
    ledgerSerialNum: string,
    memberSerialNums: string[],
  ): Promise<FamilyLedgerMember[]> {
    try {
      const associations = memberSerialNums.map(memberSerialNum => ({
        familyLedgerSerialNum: ledgerSerialNum,
        familyMemberSerialNum: memberSerialNum,
      }));

      // 批量创建关联
      const results: FamilyLedgerMember[] = [];
      for (const assoc of associations) {
        const result = await this.familyLedgerMemberMapper.create(assoc);
        results.push(result);
      }

      return results;
    } catch (error) {
      throw wrapError('FamilyLedgerService', error, 'ADD_MEMBERS_FAILED', '批量添加成员失败');
    }
  }

  // ==================== 账户管理 ====================

  /**
   * 添加账户到账本
   * @param ledgerSerialNum - 账本序列号
   * @param accountSerialNum - 账户序列号
   * @returns 账本账户关联
   */
  async addAccount(
    ledgerSerialNum: string,
    accountSerialNum: string,
  ): Promise<FamilyLedgerAccount> {
    try {
      const data: FamilyLedgerAccountCreate = {
        familyLedgerSerialNum: ledgerSerialNum,
        accountSerialNum: accountSerialNum,
      };
      return await this.familyLedgerAccountMapper.create(data);
    } catch (error) {
      throw wrapError('FamilyLedgerService', error, 'ADD_ACCOUNT_FAILED', '添加账户失败');
    }
  }

  /**
   * 从账本移除账户
   * @param ledgerSerialNum - 账本序列号
   * @param accountSerialNum - 账户序列号
   */
  async removeAccount(ledgerSerialNum: string, accountSerialNum: string): Promise<void> {
    try {
      await this.familyLedgerAccountMapper.delete(ledgerSerialNum, accountSerialNum);
    } catch (error) {
      throw wrapError('FamilyLedgerService', error, 'REMOVE_ACCOUNT_FAILED', '移除账户失败');
    }
  }

  /**
   * 获取账本的所有账户
   * @param ledgerSerialNum - 账本序列号
   * @returns 账户关联列表
   */
  async getAccounts(ledgerSerialNum: string): Promise<FamilyLedgerAccount[]> {
    try {
      return await this.familyLedgerAccountMapper.listByLedger(ledgerSerialNum);
    } catch (error) {
      throw wrapError('FamilyLedgerService', error, 'GET_ACCOUNTS_FAILED', '获取账户列表失败');
    }
  }

  // ==================== 交易管理 ====================

  /**
   * 添加交易到账本
   * @param ledgerSerialNum - 账本序列号
   * @param transactionSerialNum - 交易序列号
   * @returns 账本交易关联
   */
  async addTransaction(
    ledgerSerialNum: string,
    transactionSerialNum: string,
  ): Promise<FamilyLedgerTransaction> {
    try {
      const data: FamilyLedgerTransactionCreate = {
        familyLedgerSerialNum: ledgerSerialNum,
        transactionSerialNum: transactionSerialNum,
      };
      return await this.familyLedgerTransactionMapper.create(data);
    } catch (error) {
      throw wrapError('FamilyLedgerService', error, 'ADD_TRANSACTION_FAILED', '添加交易失败');
    }
  }

  /**
   * 从账本移除交易
   * @param serialNum - 关联序列号
   */
  async removeTransaction(serialNum: string): Promise<void> {
    try {
      await this.familyLedgerTransactionMapper.deleteById(serialNum);
    } catch (error) {
      throw wrapError('FamilyLedgerService', error, 'REMOVE_TRANSACTION_FAILED', '移除交易失败');
    }
  }

  /**
   * 获取账本的所有交易
   * @param ledgerSerialNum - 账本序列号
   * @returns 交易关联列表
   */
  async getTransactions(ledgerSerialNum: string): Promise<FamilyLedgerTransaction[]> {
    try {
      return await this.familyLedgerTransactionMapper.listByLedger(ledgerSerialNum);
    } catch (error) {
      throw wrapError('FamilyLedgerService', error, 'GET_TRANSACTIONS_FAILED', '获取交易列表失败');
    }
  }

  /**
   * 批量添加交易到账本
   * @param associations - 交易关联列表
   * @returns 账本交易关联列表
   */
  async addTransactions(
    associations: FamilyLedgerTransactionCreate[],
  ): Promise<FamilyLedgerTransaction[]> {
    try {
      return await this.familyLedgerTransactionMapper.batchCreate(associations);
    } catch (error) {
      throw wrapError('FamilyLedgerService', error, 'ADD_TRANSACTIONS_FAILED', '批量添加交易失败');
    }
  }

  /**
   * 更新交易的账本关联
   * @param transactionSerialNum - 交易序列号
   * @param ledgerSerialNums - 账本序列号列表
   * @returns 更新后的关联列表
   */
  async updateTransactionLedgers(
    transactionSerialNum: string,
    ledgerSerialNums: string[],
  ): Promise<FamilyLedgerTransaction[]> {
    try {
      return await this.familyLedgerTransactionMapper.updateTransactionLedgers(
        transactionSerialNum,
        ledgerSerialNums,
      );
    } catch (error) {
      throw wrapError(
        'FamilyLedgerService',
        error,
        'UPDATE_TRANSACTION_LEDGERS_FAILED',
        '更新交易账本关联失败',
      );
    }
  }

  // ==================== 分摊计算 ====================

  /**
   * 计算交易分摊
   * 调用 Rust 后端进行复杂的分摊计算
   * @param ledgerSerialNum - 账本序列号
   * @param transactionSerialNum - 交易序列号
   * @param ruleSerialNum - 分摊规则序列号（可选）
   * @returns 分摊结果
   */
  async calculateSplit(
    ledgerSerialNum: string,
    transactionSerialNum: string,
    ruleSerialNum?: string,
  ): Promise<SplitResult[]> {
    try {
      return await this.invokeCommand<SplitResult[]>('calculate_split', {
        ledgerSerialNum,
        transactionSerialNum,
        ruleSerialNum,
      });
    } catch (error) {
      throw wrapError('FamilyLedgerService', error, 'CALCULATE_SPLIT_FAILED', '计算分摊失败');
    }
  }

  /**
   * 应用分摊规则
   * 创建分摊记录并更新成员余额
   * @param ledgerSerialNum - 账本序列号
   * @param transactionSerialNum - 交易序列号
   * @param splitResults - 分摊结果
   */
  async applySplit(
    ledgerSerialNum: string,
    transactionSerialNum: string,
    splitResults: SplitResult[],
  ): Promise<void> {
    try {
      await this.invokeCommand('apply_split', {
        ledgerSerialNum,
        transactionSerialNum,
        splitResults,
      });
    } catch (error) {
      throw wrapError('FamilyLedgerService', error, 'APPLY_SPLIT_FAILED', '应用分摊失败');
    }
  }

  /**
   * 获取结算建议
   * 计算成员之间的债务关系并提供最优结算方案
   * @param ledgerSerialNum - 账本序列号
   * @returns 结算建议列表
   */
  async getSettlementSuggestions(ledgerSerialNum: string): Promise<any[]> {
    try {
      return await this.invokeCommand<any[]>('get_settlement_suggestions', {
        ledgerSerialNum,
      });
    } catch (error) {
      throw wrapError(
        'FamilyLedgerService',
        error,
        'GET_SETTLEMENT_SUGGESTIONS_FAILED',
        '获取结算建议失败',
      );
    }
  }

  /**
   * 执行结算
   * 根据结算建议创建结算记录并更新债务状态
   * @param ledgerSerialNum - 账本序列号
   * @param settlements - 结算列表
   */
  async executeSettlement(
    ledgerSerialNum: string,
    settlements: Array<{
      fromMemberSerialNum: string;
      toMemberSerialNum: string;
      amount: number;
    }>,
  ): Promise<void> {
    try {
      await this.invokeCommand('execute_settlement', {
        ledgerSerialNum,
        settlements,
      });
    } catch (error) {
      throw wrapError('FamilyLedgerService', error, 'EXECUTE_SETTLEMENT_FAILED', '执行结算失败');
    }
  }
}

/**
 * 导出 FamilyLedgerService 单例
 */
export const familyLedgerService = new FamilyLedgerService();
