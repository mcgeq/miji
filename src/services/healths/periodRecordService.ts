/**
 * 经期记录服务
 * 提供经期记录的 CRUD 操作
 * @module services/healths/PeriodRecordService
 */

import type { PageQuery } from '@/schema/common';
import type { PeriodRecordCreate, PeriodRecords, PeriodRecordUpdate } from '@/schema/health/period';
import { wrapError } from '@/utils/errorHandler';
import { BaseService, type IMapper } from '../base/BaseService';
import type { PagedResult } from '../base/types';
import { type PeriodRecordFilter, PeriodRecordMapper } from './period_record';

/**
 * 经期记录服务类
 * 继承 BaseService，提供经期记录相关的业务逻辑
 */
class PeriodRecordService extends BaseService<
  PeriodRecords,
  PeriodRecordCreate,
  PeriodRecordUpdate
> {
  private periodRecordMapper: PeriodRecordMapper;

  constructor() {
    const mapper = new PeriodRecordMapper();
    // Create an adapter to match IMapper interface
    const mapperAdapter: IMapper<PeriodRecords, PeriodRecordCreate, PeriodRecordUpdate> = {
      create: data => mapper.create(data),
      getById: id => mapper.getById(id),
      list: () => mapper.list(),
      update: (id, data) => mapper.update(id, data),
      delete: id => mapper.deleteById(id),
    };
    super('period_record', mapperAdapter);
    this.periodRecordMapper = mapper;
  }

  /**
   * 删除经期记录（覆盖基类方法以使用正确的 Mapper 方法）
   */
  async delete(id: string): Promise<void> {
    try {
      await this.periodRecordMapper.deleteById(id);
    } catch (error) {
      throw wrapError(
        'PeriodRecordService',
        error,
        'DELETE_FAILED',
        `删除${this.commandPrefix}失败`,
      );
    }
  }

  /**
   * 分页查询经期记录
   * @param query - 分页查询参数
   * @returns 分页结果
   */
  async listPagedWithFilters(
    query: PageQuery<PeriodRecordFilter>,
  ): Promise<PagedResult<PeriodRecords>> {
    try {
      const result = await this.periodRecordMapper.listPaged(query);
      // 转换为标准 PagedResult 格式
      return {
        items: result.rows,
        total: result.totalCount,
        page: result.currentPage,
        pageSize: result.pageSize,
        totalPages: result.totalPages,
      };
    } catch (error) {
      throw wrapError('PeriodRecordService', error, 'LIST_PAGED_FAILED', '分页查询经期记录失败');
    }
  }

  /**
   * 获取最近的经期记录
   * @param limit - 限制数量
   * @returns 最近的经期记录列表
   */
  async getRecentRecords(limit = 10): Promise<PeriodRecords[]> {
    try {
      const allRecords = await this.list();
      return allRecords
        .sort((a, b) => new Date(b.startDate).getTime() - new Date(a.startDate).getTime())
        .slice(0, limit);
    } catch (error) {
      throw wrapError(
        'PeriodRecordService',
        error,
        'GET_RECENT_RECORDS_FAILED',
        '获取最近经期记录失败',
      );
    }
  }

  /**
   * 获取指定日期范围内的经期记录
   * @param startDate - 开始日期
   * @param endDate - 结束日期
   * @returns 经期记录列表
   */
  async getRecordsByDateRange(startDate: string, endDate: string): Promise<PeriodRecords[]> {
    try {
      const allRecords = await this.list();
      const start = new Date(startDate).getTime();
      const end = new Date(endDate).getTime();

      return allRecords.filter(record => {
        const recordStart = new Date(record.startDate).getTime();
        const recordEnd = new Date(record.endDate).getTime();
        return (
          (recordStart >= start && recordStart <= end) ||
          (recordEnd >= start && recordEnd <= end) ||
          (recordStart <= start && recordEnd >= end)
        );
      });
    } catch (error) {
      throw wrapError(
        'PeriodRecordService',
        error,
        'GET_RECORDS_BY_DATE_RANGE_FAILED',
        '获取日期范围内的经期记录失败',
      );
    }
  }
}

/**
 * 导出 PeriodRecordService 单例
 */
export const periodRecordService = new PeriodRecordService();
