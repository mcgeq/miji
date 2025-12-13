/**
 * 经期每日记录服务
 * 提供每日记录的 CRUD 操作
 * @module services/healths/PeriodDailyRecordService
 */

import type { PageQuery } from '@/schema/common';
import type {
  PeriodDailyRecordCreate,
  PeriodDailyRecords,
  PeriodDailyRecordUpdate,
} from '@/schema/health/period';
import { wrapError } from '@/utils/errorHandler';
import { BaseService, type IMapper } from '../base/BaseService';
import type { PagedResult } from '../base/types';
import { type PeriodDailyRecordFilter, PeriodDailyRecordMapper } from './period_daily_record';

/**
 * 经期每日记录服务类
 * 继承 BaseService，提供每日记录相关的业务逻辑
 */
class PeriodDailyRecordService extends BaseService<
  PeriodDailyRecords,
  PeriodDailyRecordCreate,
  PeriodDailyRecordUpdate
> {
  private periodDailyRecordMapper: PeriodDailyRecordMapper;

  constructor() {
    const mapper = new PeriodDailyRecordMapper();
    // Create an adapter to match IMapper interface
    const mapperAdapter: IMapper<
      PeriodDailyRecords,
      PeriodDailyRecordCreate,
      PeriodDailyRecordUpdate
    > = {
      create: data => mapper.create(data),
      getById: id => mapper.getById(id),
      list: () => mapper.list(),
      update: (id, data) => mapper.update(id, data),
      delete: id => mapper.deleteById(id),
    };
    super('period_daily_record', mapperAdapter);
    this.periodDailyRecordMapper = mapper;
  }

  /**
   * 删除每日记录（覆盖基类方法以使用正确的 Mapper 方法）
   */
  async delete(id: string): Promise<void> {
    try {
      await this.periodDailyRecordMapper.deleteById(id);
    } catch (error) {
      throw wrapError(
        'PeriodDailyRecordService',
        error,
        'DELETE_FAILED',
        `删除${this.commandPrefix}失败`,
      );
    }
  }

  /**
   * 分页查询每日记录
   * @param query - 分页查询参数
   * @returns 分页结果
   */
  async listPagedWithFilters(
    query: PageQuery<PeriodDailyRecordFilter>,
  ): Promise<PagedResult<PeriodDailyRecords>> {
    try {
      const result = await this.periodDailyRecordMapper.listPaged(query);
      // 转换为标准 PagedResult 格式
      return {
        items: result.rows,
        total: result.totalCount,
        page: result.currentPage,
        pageSize: result.pageSize,
        totalPages: result.totalPages,
      };
    } catch (error) {
      throw wrapError(
        'PeriodDailyRecordService',
        error,
        'LIST_PAGED_FAILED',
        '分页查询每日记录失败',
      );
    }
  }

  /**
   * 根据日期获取每日记录
   * @param date - 日期（YYYY-MM-DD）
   * @returns 每日记录或 null
   */
  async getByDate(date: string): Promise<PeriodDailyRecords | null> {
    try {
      const allRecords = await this.list();
      return allRecords.find(record => record.date === date) || null;
    } catch (error) {
      throw wrapError(
        'PeriodDailyRecordService',
        error,
        'GET_BY_DATE_FAILED',
        '根据日期获取每日记录失败',
      );
    }
  }

  /**
   * 获取当前月份的每日记录
   * @returns 当前月份的每日记录列表
   */
  async getCurrentMonthRecords(): Promise<PeriodDailyRecords[]> {
    try {
      const allRecords = await this.list();
      const currentMonth = new Date().toISOString().slice(0, 7);
      return allRecords.filter(record => record.date.startsWith(currentMonth));
    } catch (error) {
      throw wrapError(
        'PeriodDailyRecordService',
        error,
        'GET_CURRENT_MONTH_RECORDS_FAILED',
        '获取当前月份记录失败',
      );
    }
  }

  /**
   * 获取指定日期范围内的每日记录
   * @param startDate - 开始日期
   * @param endDate - 结束日期
   * @returns 每日记录列表
   */
  async getRecordsByDateRange(startDate: string, endDate: string): Promise<PeriodDailyRecords[]> {
    try {
      const allRecords = await this.list();
      return allRecords.filter(record => record.date >= startDate && record.date <= endDate);
    } catch (error) {
      throw wrapError(
        'PeriodDailyRecordService',
        error,
        'GET_RECORDS_BY_DATE_RANGE_FAILED',
        '获取日期范围内的每日记录失败',
      );
    }
  }
}

/**
 * 导出 PeriodDailyRecordService 单例
 */
export const periodDailyRecordService = new PeriodDailyRecordService();
