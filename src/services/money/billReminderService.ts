/**
 * 账单提醒服务
 * 提供账单提醒的 CRUD 操作和业务逻辑
 * @module services/money/BillReminderService
 */

import type { PageQuery } from '@/schema/common';
import type { BilReminder, BilReminderCreate, BilReminderUpdate } from '@/schema/money';
import { wrapError } from '@/utils/errorHandler';
import { BaseService, type IMapper } from '../base/BaseService';
import type { PagedResult } from '../base/types';
import { type BilReminderFilters, BilReminderMapper } from './billReminder';

/**
 * 账单提醒服务类
 * 继承 BaseService，提供账单提醒相关的业务逻辑
 */
class BillReminderService extends BaseService<BilReminder, BilReminderCreate, BilReminderUpdate> {
  private billReminderMapper: BilReminderMapper;

  constructor() {
    const mapper = new BilReminderMapper();
    // Create an adapter to match IMapper interface
    const mapperAdapter: IMapper<BilReminder, BilReminderCreate, BilReminderUpdate> = {
      create: data => mapper.create(data),
      getById: id => mapper.getById(id),
      list: () => mapper.list(),
      update: (id, data) => mapper.update(id, data),
      delete: id => mapper.deleteById(id),
    };
    super('bil_reminder', mapperAdapter);
    this.billReminderMapper = mapper;
  }

  /**
   * 删除账单提醒（覆盖基类方法以使用正确的 Mapper 方法）
   */
  async delete(id: string): Promise<void> {
    try {
      await this.billReminderMapper.deleteById(id);
    } catch (error) {
      throw wrapError(
        'BillReminderService',
        error,
        'DELETE_FAILED',
        `删除${this.commandPrefix}失败`,
      );
    }
  }

  /**
   * 更新账单提醒激活状态
   * @param serialNum - 账单提醒序列号
   * @param isActive - 是否激活
   * @returns 更新后的账单提醒
   */
  async updateActive(serialNum: string, isActive: boolean): Promise<BilReminder> {
    try {
      return await this.billReminderMapper.updateActive(serialNum, isActive);
    } catch (error) {
      throw wrapError('BillReminderService', error, 'UPDATE_ACTIVE_FAILED', '更新账单提醒状态失败');
    }
  }

  /**
   * 分页查询账单提醒
   * @param query - 分页查询参数
   * @returns 分页结果
   */
  async listPagedWithFilters(
    query: PageQuery<BilReminderFilters>,
  ): Promise<PagedResult<BilReminder>> {
    try {
      const result = await this.billReminderMapper.listPaged(query);
      // 转换为标准 PagedResult 格式
      return {
        items: result.rows,
        total: result.totalCount,
        page: result.currentPage,
        pageSize: result.pageSize,
        totalPages: result.totalPages,
      };
    } catch (error) {
      throw wrapError('BillReminderService', error, 'LIST_PAGED_FAILED', '分页查询账单提醒失败');
    }
  }

  /**
   * 获取启用的账单提醒
   * @returns 启用的账单提醒列表
   */
  async listEnabled(): Promise<BilReminder[]> {
    try {
      const allReminders = await this.list();
      return allReminders.filter(reminder => reminder.enabled);
    } catch (error) {
      throw wrapError(
        'BillReminderService',
        error,
        'LIST_ENABLED_FAILED',
        '获取启用的账单提醒失败',
      );
    }
  }

  /**
   * 获取即将到期的账单提醒
   * @param days - 天数（默认7天）
   * @returns 即将到期的账单提醒列表
   */
  async getUpcomingReminders(days = 7): Promise<BilReminder[]> {
    try {
      const allReminders = await this.listEnabled();
      const now = Date.now();
      const futureTime = now + days * 24 * 60 * 60 * 1000;

      return allReminders.filter(reminder => {
        const dueTime = new Date(reminder.dueAt).getTime();
        return dueTime >= now && dueTime <= futureTime && !reminder.isPaid;
      });
    } catch (error) {
      throw wrapError(
        'BillReminderService',
        error,
        'GET_UPCOMING_REMINDERS_FAILED',
        '获取即将到期的账单提醒失败',
      );
    }
  }

  /**
   * 获取逾期的账单提醒
   * @returns 逾期的账单提醒列表
   */
  async getOverdueReminders(): Promise<BilReminder[]> {
    try {
      const allReminders = await this.listEnabled();
      const now = Date.now();

      return allReminders.filter(reminder => {
        const dueTime = new Date(reminder.dueAt).getTime();
        return dueTime < now && !reminder.isPaid;
      });
    } catch (error) {
      throw wrapError(
        'BillReminderService',
        error,
        'GET_OVERDUE_REMINDERS_FAILED',
        '获取逾期的账单提醒失败',
      );
    }
  }

  /**
   * 标记账单为已支付
   * @param serialNum - 账单提醒序列号
   * @returns 更新后的账单提醒
   */
  async markAsPaid(serialNum: string): Promise<BilReminder> {
    try {
      return await this.update(serialNum, { isPaid: true });
    } catch (error) {
      throw wrapError('BillReminderService', error, 'MARK_AS_PAID_FAILED', '标记账单为已支付失败');
    }
  }
}

/**
 * 导出 BillReminderService 单例
 */
export const billReminderService = new BillReminderService();
