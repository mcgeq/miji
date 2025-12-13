/**
 * 预算服务
 * 提供预算的 CRUD 操作和统计分析功能
 * @module services/money/BudgetService
 */

import type { PageQuery } from '@/schema/common';
import type { Budget, BudgetCreate, BudgetUpdate } from '@/schema/money';
import { wrapError } from '@/utils/errorHandler';
import { BaseService, type IMapper } from '../base/BaseService';
import type { PagedResult } from '../base/types';
import type {
  BudgetCategoryStats,
  BudgetOverviewRequest,
  BudgetOverviewSummary,
  BudgetScopeStats,
  BudgetTrendData,
  BudgetTypeStats,
} from './budgetStats';
import { type BudgetFilters, BudgetMapper } from './budgets';

/**
 * 预算服务类
 * 继承 BaseService，提供预算相关的业务逻辑
 */
class BudgetService extends BaseService<Budget, BudgetCreate, BudgetUpdate> {
  private budgetMapper: BudgetMapper;

  constructor() {
    const mapper = new BudgetMapper();
    // Create an adapter to match IMapper interface
    const mapperAdapter: IMapper<Budget, BudgetCreate, BudgetUpdate> = {
      create: data => mapper.create(data),
      getById: id => mapper.getById(id),
      list: () => mapper.list(),
      update: (id, data) => mapper.update(id, data),
      delete: id => mapper.deleteById(id),
    };
    super('budget', mapperAdapter);
    this.budgetMapper = mapper;
  }

  /**
   * 删除预算（覆盖基类方法以使用正确的 Mapper 方法）
   */
  async delete(id: string): Promise<void> {
    try {
      await this.budgetMapper.deleteById(id);
    } catch (error) {
      throw wrapError('BudgetService', error, 'DELETE_FAILED', `删除${this.commandPrefix}失败`);
    }
  }

  /**
   * 更新预算激活状态
   * @param serialNum - 预算序列号
   * @param isActive - 是否激活
   * @returns 更新后的预算
   */
  async updateActive(serialNum: string, isActive: boolean): Promise<Budget> {
    try {
      return await this.budgetMapper.updateActive(serialNum, isActive);
    } catch (error) {
      throw wrapError('BudgetService', error, 'UPDATE_ACTIVE_FAILED', '更新预算状态失败');
    }
  }

  /**
   * 分页查询预算
   * @param query - 分页查询参数
   * @returns 分页结果
   */
  async listPagedWithFilters(query: PageQuery<BudgetFilters>): Promise<PagedResult<Budget>> {
    try {
      const result = await this.budgetMapper.listPaged(query);
      // 转换为标准 PagedResult 格式
      return {
        items: result.rows,
        total: result.totalCount,
        page: result.currentPage,
        pageSize: result.pageSize,
        totalPages: result.totalPages,
      };
    } catch (error) {
      throw wrapError('BudgetService', error, 'LIST_PAGED_FAILED', '分页查询预算失败');
    }
  }

  // ============ 预算统计方法 ============

  /**
   * 获取预算总览统计
   * @param request - 预算总览请求参数
   * @returns 预算总览统计数据
   */
  async getBudgetOverview(request: BudgetOverviewRequest): Promise<BudgetOverviewSummary> {
    try {
      return await this.invokeCommand<BudgetOverviewSummary>('overview_calculate', {
        request,
      });
    } catch (error) {
      throw wrapError('BudgetService', error, 'GET_OVERVIEW_FAILED', '获取预算总览统计失败');
    }
  }

  /**
   * 按预算类型获取统计
   * @param request - 预算总览请求参数
   * @returns 按预算类型分组的统计数据
   */
  async getBudgetStatsByType(request: BudgetOverviewRequest): Promise<BudgetTypeStats> {
    try {
      return await this.invokeCommand<BudgetTypeStats>('overview_by_type', {
        request,
      });
    } catch (error) {
      throw wrapError('BudgetService', error, 'GET_STATS_BY_TYPE_FAILED', '按预算类型获取统计失败');
    }
  }

  /**
   * 按预算范围获取统计
   * @param request - 预算总览请求参数
   * @returns 按预算范围分组的统计数据
   */
  async getBudgetStatsByScope(request: BudgetOverviewRequest): Promise<BudgetScopeStats> {
    try {
      return await this.invokeCommand<BudgetScopeStats>('overview_by_scope', {
        request,
      });
    } catch (error) {
      throw wrapError(
        'BudgetService',
        error,
        'GET_STATS_BY_SCOPE_FAILED',
        '按预算范围获取统计失败',
      );
    }
  }

  /**
   * 获取预算趋势数据
   * @param startDate - 开始日期
   * @param endDate - 结束日期
   * @param period - 周期类型（月/周）
   * @returns 预算趋势数据数组
   */
  async getBudgetTrends(
    startDate: string,
    endDate: string,
    period: 'month' | 'week' = 'month',
  ): Promise<BudgetTrendData[]> {
    try {
      const request = {
        startDate: new Date(startDate).toISOString(),
        endDate: new Date(endDate).toISOString(),
        periodType: period,
        baseCurrency: 'CNY',
        includeInactive: false,
      };
      return await this.invokeCommand<BudgetTrendData[]>('trends_get', {
        request,
      });
    } catch (error) {
      throw wrapError('BudgetService', error, 'GET_TRENDS_FAILED', '获取预算趋势数据失败');
    }
  }

  /**
   * 获取预算分类统计
   * @returns 预算分类统计数据数组
   */
  async getBudgetCategoryStats(): Promise<BudgetCategoryStats[]> {
    try {
      return await this.invokeCommand<BudgetCategoryStats[]>('category_stats_get', {
        baseCurrency: 'CNY',
        includeInactive: false,
      });
    } catch (error) {
      throw wrapError('BudgetService', error, 'GET_CATEGORY_STATS_FAILED', '获取预算分类统计失败');
    }
  }
}

/**
 * 导出 BudgetService 单例
 */
export const budgetService = new BudgetService();
