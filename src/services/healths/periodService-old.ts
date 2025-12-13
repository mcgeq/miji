/**
 * Period Service
 * 经期服务层，负责经期相关数据的访问和业务逻辑
 * @module services/healths/periodService
 */

import type { PageQuery } from '@/schema/common';
import type {
  PeriodCalendarEvent,
  PeriodDailyRecordCreate,
  PeriodDailyRecords,
  PeriodDailyRecordUpdate,
  PeriodRecordCreate,
  PeriodRecords,
  PeriodRecordUpdate,
  PeriodSettings,
  PeriodSettingsCreate,
  PeriodSettingsUpdate,
  PeriodStats,
} from '@/schema/health/period';
import { wrapError } from '@/utils/errorHandler';
import type { PagedResult } from '../money/baseManager';
import type { PeriodDailyRecordFilter } from './period_daily_record';
import { PeriodDailyRecordMapper } from './period_daily_record';
import type { PeriodRecordFilter } from './period_record';
import { PeriodRecordMapper } from './period_record';
import { PeriodSettingsMapper } from './period_settings';

/**
 * 经期服务类
 * 提供经期记录、每日记录、设置的 CRUD 操作和统计方法
 */
class PeriodService {
  private periodRecordMapper: PeriodRecordMapper;
  private periodDailyRecordMapper: PeriodDailyRecordMapper;
  private periodSettingsMapper: PeriodSettingsMapper;

  constructor() {
    this.periodRecordMapper = new PeriodRecordMapper();
    this.periodDailyRecordMapper = new PeriodDailyRecordMapper();
    this.periodSettingsMapper = new PeriodSettingsMapper();
  }

  // ==================== PeriodRecord CRUD ====================

  /**
   * 创建经期记录
   */
  async createPeriodRecord(data: PeriodRecordCreate): Promise<PeriodRecords> {
    try {
      return await this.periodRecordMapper.create(data);
    } catch (error) {
      throw wrapError('PeriodService', error, 'CREATE_PERIOD_RECORD_FAILED', '创建经期记录失败');
    }
  }

  /**
   * 获取经期记录
   */
  async getPeriodRecord(serialNum: string): Promise<PeriodRecords | null> {
    try {
      return await this.periodRecordMapper.getById(serialNum);
    } catch (error) {
      throw wrapError('PeriodService', error, 'GET_PERIOD_RECORD_FAILED', '获取经期记录失败');
    }
  }

  /**
   * 获取所有经期记录
   */
  async listPeriodRecords(): Promise<PeriodRecords[]> {
    try {
      return await this.periodRecordMapper.list();
    } catch (error) {
      throw wrapError('PeriodService', error, 'LIST_PERIOD_RECORDS_FAILED', '获取经期记录列表失败');
    }
  }

  /**
   * 分页获取经期记录
   */
  async listPagedPeriodRecords(
    query: PageQuery<PeriodRecordFilter>,
  ): Promise<PagedResult<PeriodRecords>> {
    try {
      return await this.periodRecordMapper.listPaged(query);
    } catch (error) {
      throw wrapError(
        'PeriodService',
        error,
        'LIST_PAGED_PERIOD_RECORDS_FAILED',
        '分页获取经期记录失败',
      );
    }
  }

  /**
   * 更新经期记录
   */
  async updatePeriodRecord(serialNum: string, data: PeriodRecordUpdate): Promise<PeriodRecords> {
    try {
      return await this.periodRecordMapper.update(serialNum, data);
    } catch (error) {
      throw wrapError('PeriodService', error, 'UPDATE_PERIOD_RECORD_FAILED', '更新经期记录失败');
    }
  }

  /**
   * 删除经期记录
   */
  async deletePeriodRecord(serialNum: string): Promise<void> {
    try {
      await this.periodRecordMapper.deleteById(serialNum);
    } catch (error) {
      throw wrapError('PeriodService', error, 'DELETE_PERIOD_RECORD_FAILED', '删除经期记录失败');
    }
  }

  // ==================== PeriodDailyRecord CRUD ====================

  /**
   * 创建每日记录
   */
  async createDailyRecord(data: PeriodDailyRecordCreate): Promise<PeriodDailyRecords> {
    try {
      return await this.periodDailyRecordMapper.create(data);
    } catch (error) {
      throw wrapError('PeriodService', error, 'CREATE_DAILY_RECORD_FAILED', '创建每日记录失败');
    }
  }

  /**
   * 获取每日记录
   */
  async getDailyRecord(serialNum: string): Promise<PeriodDailyRecords | null> {
    try {
      return await this.periodDailyRecordMapper.getById(serialNum);
    } catch (error) {
      throw wrapError('PeriodService', error, 'GET_DAILY_RECORD_FAILED', '获取每日记录失败');
    }
  }

  /**
   * 获取所有每日记录
   */
  async listDailyRecords(): Promise<PeriodDailyRecords[]> {
    try {
      return await this.periodDailyRecordMapper.list();
    } catch (error) {
      throw wrapError('PeriodService', error, 'LIST_DAILY_RECORDS_FAILED', '获取每日记录列表失败');
    }
  }

  /**
   * 分页获取每日记录
   */
  async listPagedDailyRecords(
    query: PageQuery<PeriodDailyRecordFilter>,
  ): Promise<PagedResult<PeriodDailyRecords>> {
    try {
      return await this.periodDailyRecordMapper.listPaged(query);
    } catch (error) {
      throw wrapError(
        'PeriodService',
        error,
        'LIST_PAGED_DAILY_RECORDS_FAILED',
        '分页获取每日记录失败',
      );
    }
  }

  /**
   * 更新每日记录
   */
  async updateDailyRecord(
    serialNum: string,
    data: PeriodDailyRecordUpdate,
  ): Promise<PeriodDailyRecords> {
    try {
      return await this.periodDailyRecordMapper.update(serialNum, data);
    } catch (error) {
      throw wrapError('PeriodService', error, 'UPDATE_DAILY_RECORD_FAILED', '更新每日记录失败');
    }
  }

  /**
   * 删除每日记录
   */
  async deleteDailyRecord(serialNum: string): Promise<void> {
    try {
      await this.periodDailyRecordMapper.deleteById(serialNum);
    } catch (error) {
      throw wrapError('PeriodService', error, 'DELETE_DAILY_RECORD_FAILED', '删除每日记录失败');
    }
  }

  // ==================== PeriodSettings CRUD ====================

  /**
   * 创建经期设置
   */
  async createSettings(data: PeriodSettingsCreate): Promise<PeriodSettings> {
    try {
      return await this.periodSettingsMapper.create(data);
    } catch (error) {
      throw wrapError('PeriodService', error, 'CREATE_SETTINGS_FAILED', '创建经期设置失败');
    }
  }

  /**
   * 获取经期设置
   */
  async getSettings(serialNum: string): Promise<PeriodSettings | null> {
    try {
      return await this.periodSettingsMapper.getById(serialNum);
    } catch (error) {
      throw wrapError('PeriodService', error, 'GET_SETTINGS_FAILED', '获取经期设置失败');
    }
  }

  /**
   * 更新经期设置
   */
  async updateSettings(serialNum: string, data: PeriodSettingsUpdate): Promise<PeriodSettings> {
    try {
      return await this.periodSettingsMapper.update(serialNum, data);
    } catch (error) {
      throw wrapError('PeriodService', error, 'UPDATE_SETTINGS_FAILED', '更新经期设置失败');
    }
  }

  /**
   * 删除经期设置
   */
  async deleteSettings(serialNum: string): Promise<void> {
    try {
      await this.periodSettingsMapper.deleteById(serialNum);
    } catch (error) {
      throw wrapError('PeriodService', error, 'DELETE_SETTINGS_FAILED', '删除经期设置失败');
    }
  }

  // ==================== 统计方法 ====================

  /**
   * 计算经期统计数据
   * @param settings - 经期设置
   * @returns 统计数据
   */
  async calculateStats(settings: PeriodSettings): Promise<PeriodStats> {
    try {
      const periodRecords = await this.listPeriodRecords();

      if (periodRecords.length < 2) {
        return {
          averageCycleLength: settings.averageCycleLength,
          averagePeriodLength: settings.averagePeriodLength,
          nextPredictedDate: '',
          currentPhase: 'Follicular',
          daysUntilNext: 0,
        };
      }

      const sortedRecords = [...periodRecords].sort(
        (a, b) => new Date(a.startDate).getTime() - new Date(b.startDate).getTime(),
      );

      // 计算周期长度
      const cycles = sortedRecords.slice(0, -1).map((record, index) => {
        const nextRecord = sortedRecords[index + 1];
        const start = new Date(record.startDate);
        const nextStart = new Date(nextRecord.startDate);
        return Math.abs(nextStart.getTime() - start.getTime()) / (1000 * 60 * 60 * 24);
      });

      const averageCycleLength =
        cycles.length > 0
          ? Math.round(cycles.reduce((sum, cycle) => sum + cycle, 0) / cycles.length)
          : settings.averageCycleLength;

      // 计算经期长度
      const periodLengths = sortedRecords.map(record => {
        const start = new Date(record.startDate);
        const end = new Date(record.endDate);
        return Math.abs(end.getTime() - start.getTime()) / (1000 * 60 * 60 * 24) + 1;
      });

      const averagePeriodLength = Math.round(
        periodLengths.reduce((sum, length) => sum + length, 0) / periodLengths.length,
      );

      // 预测下次经期
      const lastPeriod = sortedRecords[sortedRecords.length - 1];
      const lastPeriodStart = new Date(lastPeriod.startDate);
      const nextPredictedDate = new Date(
        lastPeriodStart.getTime() + averageCycleLength * 24 * 60 * 60 * 1000,
      );

      const today = new Date();
      const daysUntilNext = Math.ceil(
        (nextPredictedDate.getTime() - today.getTime()) / (1000 * 60 * 60 * 24),
      );

      // 计算当前阶段
      const daysSinceLastPeriod = Math.floor(
        (today.getTime() - lastPeriodStart.getTime()) / (1000 * 60 * 60 * 24),
      );

      let currentPhase: 'Menstrual' | 'Follicular' | 'Ovulation' | 'Luteal' = 'Follicular';
      if (daysSinceLastPeriod <= averagePeriodLength) {
        currentPhase = 'Menstrual';
      } else if (daysSinceLastPeriod <= averageCycleLength / 2) {
        currentPhase = 'Follicular';
      } else if (daysSinceLastPeriod <= averageCycleLength / 2 + 3) {
        currentPhase = 'Ovulation';
      } else {
        currentPhase = 'Luteal';
      }

      return {
        averageCycleLength,
        averagePeriodLength,
        nextPredictedDate: nextPredictedDate.toISOString().split('T')[0],
        currentPhase,
        daysUntilNext: Math.max(0, daysUntilNext),
      };
    } catch (error) {
      throw wrapError('PeriodService', error, 'CALCULATE_STATS_FAILED', '计算统计数据失败');
    }
  }

  /**
   * 获取日历事件
   * @param startDate - 开始日期
   * @param endDate - 结束日期
   * @param settings - 经期设置
   * @returns 日历事件列表
   */
  async getCalendarEvents(
    startDate: string,
    endDate: string,
    settings: PeriodSettings,
  ): Promise<PeriodCalendarEvent[]> {
    try {
      const periodRecords = await this.listPeriodRecords();
      const events: PeriodCalendarEvent[] = [];

      // 添加历史经期事件
      periodRecords.forEach(period => {
        const start = new Date(period.startDate);
        const end = new Date(period.endDate);
        const daysDiff = Math.ceil((end.getTime() - start.getTime()) / (1000 * 60 * 60 * 24)) + 1;

        for (let i = 0; i < daysDiff; i++) {
          const currentDate = new Date(start);
          currentDate.setDate(start.getDate() + i);
          const dateStr = currentDate.toISOString().split('T')[0];

          if (dateStr >= startDate && dateStr <= endDate) {
            events.push({
              date: dateStr,
              type: 'period',
              intensity: 'Medium',
              isPredicted: false,
            });
          }
        }
      });

      // 添加历史排卵事件
      periodRecords.forEach(period => {
        const ovulationDate = new Date(period.startDate);
        ovulationDate.setDate(
          ovulationDate.getDate() + Math.floor(settings.averageCycleLength / 2),
        );
        const dateStr = ovulationDate.toISOString().split('T')[0];

        if (dateStr >= startDate && dateStr <= endDate) {
          events.push({
            date: dateStr,
            type: 'ovulation',
            isPredicted: false,
          });

          // 添加易孕期
          for (let i = -1; i <= 1; i++) {
            if (i === 0) continue;
            const fertileDate = new Date(ovulationDate);
            fertileDate.setDate(fertileDate.getDate() + i);
            const fertileDateStr = fertileDate.toISOString().split('T')[0];

            if (fertileDateStr >= startDate && fertileDateStr <= endDate) {
              events.push({
                date: fertileDateStr,
                type: 'fertile',
                isPredicted: false,
              });
            }
          }
        }
      });

      // 添加预测的未来事件
      const stats = await this.calculateStats(settings);
      if (stats.nextPredictedDate && periodRecords.length > 0) {
        const predictedStart = new Date(stats.nextPredictedDate);
        const today = new Date();

        if (predictedStart >= today) {
          const predictedPeriodLength = stats.averagePeriodLength;

          // 预测经期
          for (let i = 0; i < predictedPeriodLength; i++) {
            const predictedDate = new Date(predictedStart);
            predictedDate.setDate(predictedDate.getDate() + i);
            const dateStr = predictedDate.toISOString().split('T')[0];

            if (dateStr >= startDate && dateStr <= endDate) {
              events.push({
                date: dateStr,
                type: 'predicted-period',
                intensity: 'Medium',
                isPredicted: true,
              });
            }
          }

          // 预测排卵期
          const predictedOvulationDate = new Date(predictedStart);
          predictedOvulationDate.setDate(
            predictedOvulationDate.getDate() + Math.floor(stats.averageCycleLength / 2),
          );
          const ovulationDateStr = predictedOvulationDate.toISOString().split('T')[0];

          if (ovulationDateStr >= startDate && ovulationDateStr <= endDate) {
            events.push({
              date: ovulationDateStr,
              type: 'predicted-ovulation',
              isPredicted: true,
            });

            // 预测易孕期
            for (let i = -1; i <= 1; i++) {
              if (i === 0) continue;
              const fertileDate = new Date(predictedOvulationDate);
              fertileDate.setDate(fertileDate.getDate() + i);
              const fertileDateStr = fertileDate.toISOString().split('T')[0];

              if (fertileDateStr >= startDate && fertileDateStr <= endDate) {
                events.push({
                  date: fertileDateStr,
                  type: 'predicted-fertile',
                  isPredicted: true,
                });
              }
            }
          }
        }
      }

      return events;
    } catch (error) {
      throw wrapError('PeriodService', error, 'GET_CALENDAR_EVENTS_FAILED', '获取日历事件失败');
    }
  }

  /**
   * 获取当前月份的每日记录
   * @returns 当前月份的每日记录列表
   */
  async getCurrentMonthDailyRecords(): Promise<PeriodDailyRecords[]> {
    try {
      const allRecords = await this.listDailyRecords();
      const currentMonth = new Date().toISOString().slice(0, 7);
      return allRecords.filter(record => record.date.startsWith(currentMonth));
    } catch (error) {
      throw wrapError(
        'PeriodService',
        error,
        'GET_CURRENT_MONTH_RECORDS_FAILED',
        '获取当前月份记录失败',
      );
    }
  }
}

/**
 * 经期服务单例实例
 * 导出单例以便在整个应用中使用
 */
export const periodService = new PeriodService();
