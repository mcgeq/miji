/**
 * 交易服务
 * 提供交易的 CRUD 操作和业务逻辑
 * @module services/money/TransactionService
 */

import type { IncomeExpense, PageQuery } from '@/schema/common';
import type {
  Transaction,
  TransactionCreate,
  TransactionUpdate,
  TransferCreate,
} from '@/schema/money';
import { wrapError } from '@/utils/errorHandler';
import { BaseService, type IMapper } from '../base/BaseService';
import type { PagedResult } from '../base/types';
import {
  type InstallmentPlanResponse,
  type TransactionFilters,
  TransactionMapper,
  type TransactionStatsRequest,
  type TransactionStatsResponse,
} from './transactions';

/**
 * 交易服务类
 * 继承 BaseService，提供交易相关的业务逻辑
 */
class TransactionService extends BaseService<Transaction, TransactionCreate, TransactionUpdate> {
  private transactionMapper: TransactionMapper;

  constructor() {
    const mapper = new TransactionMapper();
    // Create an adapter to match IMapper interface
    const mapperAdapter: IMapper<Transaction, TransactionCreate, TransactionUpdate> = {
      create: data => mapper.create(data),
      getById: id => mapper.getById(id),
      list: () => mapper.list(),
      update: (id, data) => mapper.update(id, data),
      delete: id => mapper.deleteById(id),
    };
    super('transaction', mapperAdapter);
    this.transactionMapper = mapper;
  }

  /**
   * 删除交易（覆盖基类方法以使用正确的 Mapper 方法）
   */
  async delete(id: string): Promise<void> {
    try {
      await this.transactionMapper.deleteById(id);
    } catch (error) {
      throw wrapError(
        'TransactionService',
        error,
        'DELETE_FAILED',
        `删除${this.commandPrefix}失败`,
      );
    }
  }

  /**
   * 分页查询交易
   * @param query - 分页查询参数
   * @returns 分页结果
   */
  async listPagedWithFilters(
    query: PageQuery<TransactionFilters>,
  ): Promise<PagedResult<Transaction>> {
    try {
      const result = await this.transactionMapper.listPaged(query);
      // 转换为标准 PagedResult 格式
      return {
        items: result.rows,
        total: result.totalCount,
        page: result.currentPage,
        pageSize: result.pageSize,
        totalPages: result.totalPages,
      };
    } catch (error) {
      throw wrapError('TransactionService', error, 'LIST_PAGED_FAILED', '分页查询交易失败');
    }
  }

  // ============ 转账相关方法 ============

  /**
   * 创建转账交易
   * @param transfer - 转账数据
   * @returns 转账交易对（转出和转入）
   */
  async createTransfer(transfer: TransferCreate): Promise<[Transaction, Transaction]> {
    try {
      return await this.transactionMapper.transfer(transfer);
    } catch (error) {
      throw wrapError('TransactionService', error, 'CREATE_TRANSFER_FAILED', '创建转账失败');
    }
  }

  /**
   * 更新转账交易
   * @param serialNum - 转账序列号
   * @param transfer - 转账数据
   * @returns 更新后的转账交易对
   */
  async updateTransfer(
    serialNum: string,
    transfer: TransferCreate,
  ): Promise<[Transaction, Transaction]> {
    try {
      return await this.transactionMapper.transferUpdate(serialNum, transfer);
    } catch (error) {
      throw wrapError('TransactionService', error, 'UPDATE_TRANSFER_FAILED', '更新转账失败');
    }
  }

  /**
   * 删除转账交易
   * @param serialNum - 转账序列号
   * @returns 删除的转账交易对
   */
  async deleteTransfer(serialNum: string): Promise<[Transaction, Transaction]> {
    try {
      return await this.transactionMapper.transferDelete(serialNum);
    } catch (error) {
      throw wrapError('TransactionService', error, 'DELETE_TRANSFER_FAILED', '删除转账失败');
    }
  }

  // ============ 统计方法 ============

  /**
   * 获取交易统计数据
   * @param request - 统计请求参数
   * @returns 统计数据
   */
  async getStats(request: TransactionStatsRequest): Promise<TransactionStatsResponse> {
    try {
      return await this.transactionMapper.getStats(request);
    } catch (error) {
      throw wrapError('TransactionService', error, 'GET_STATS_FAILED', '获取交易统计失败');
    }
  }

  /**
   * 获取本月收入和支出
   * @returns 本月收入支出数据
   */
  async getMonthlyIncomeAndExpense(): Promise<IncomeExpense> {
    try {
      return await this.transactionMapper.monthlyIncomeAndExpense();
    } catch (error) {
      throw wrapError(
        'TransactionService',
        error,
        'GET_MONTHLY_INCOME_EXPENSE_FAILED',
        '获取本月收支失败',
      );
    }
  }

  /**
   * 获取上月收入和支出
   * @returns 上月收入支出数据
   */
  async getLastMonthIncomeAndExpense(): Promise<IncomeExpense> {
    try {
      return await this.transactionMapper.lastMonthIncomeAndExpense();
    } catch (error) {
      throw wrapError(
        'TransactionService',
        error,
        'GET_LAST_MONTH_INCOME_EXPENSE_FAILED',
        '获取上月收支失败',
      );
    }
  }

  /**
   * 获取本年度收入和支出
   * @returns 本年度收入支出数据
   */
  async getYearlyIncomeAndExpense(): Promise<IncomeExpense> {
    try {
      return await this.transactionMapper.yearlyIncomeAndExpense();
    } catch (error) {
      throw wrapError(
        'TransactionService',
        error,
        'GET_YEARLY_INCOME_EXPENSE_FAILED',
        '获取本年收支失败',
      );
    }
  }

  /**
   * 获取去年收入和支出
   * @returns 去年收入支出数据
   */
  async getLastYearIncomeAndExpense(): Promise<IncomeExpense> {
    try {
      return await this.transactionMapper.lastYearIncomeAndExpense();
    } catch (error) {
      throw wrapError(
        'TransactionService',
        error,
        'GET_LAST_YEAR_INCOME_EXPENSE_FAILED',
        '获取去年收支失败',
      );
    }
  }

  // ============ 分期付款方法 ============

  /**
   * 获取分期付款计划
   * @param planSerialNum - 分期计划序列号
   * @returns 分期付款计划详情
   */
  async getInstallmentPlan(planSerialNum: string): Promise<InstallmentPlanResponse> {
    try {
      return await this.transactionMapper.getInstallmentPlan(planSerialNum);
    } catch (error) {
      throw wrapError(
        'TransactionService',
        error,
        'GET_INSTALLMENT_PLAN_FAILED',
        '获取分期计划失败',
      );
    }
  }

  /**
   * 获取待还款的分期明细
   * @returns 待还款分期列表
   */
  async getPendingInstallments(): Promise<InstallmentPlanResponse[]> {
    try {
      return await this.transactionMapper.getPendingInstallments();
    } catch (error) {
      throw wrapError(
        'TransactionService',
        error,
        'GET_PENDING_INSTALLMENTS_FAILED',
        '获取待还款分期失败',
      );
    }
  }
}

/**
 * 导出 TransactionService 单例
 */
export const transactionService = new TransactionService();
