import type { PageQuery } from '@/schema/common';
import type {
  PeriodDailyRecordCreate,
  PeriodDailyRecords,
  PeriodDailyRecordUpdate,
  PeriodRecordCreate,
  PeriodRecords,
  PeriodRecordUpdate,
  PeriodSettings,
  PeriodSettingsCreate,
  PeriodSettingsUpdate,
} from '@/schema/health/period';
import type { PagedResult } from '../money/baseManager';
import type { PeriodDailyRecordFilter } from './period_daily_record';
import { PeriodDailyRecordMapper } from './period_daily_record';
import type { PeriodRecordFilter } from './period_record';
import { PeriodRecordMapper } from './period_record';
import { PeriodSettingsMapper } from './period_settings';

/**
 * 健康数据数据库服务 - 使用映射器模式
 *
 * 这是一个门面（Facade）类，聚合了健康相关的数据访问映射器
 * 提供统一的健康数据访问入口点
 */
class HealthsDbService {
  private periodRecordMapper = new PeriodRecordMapper();
  private periodDailyRecordMapper = new PeriodDailyRecordMapper();
  private periodSettingsMapper = new PeriodSettingsMapper();

  // =================== PeriodRecord ===================
  async getPeriodRecord(serialNum: string): Promise<PeriodRecords | null> {
    return this.periodRecordMapper.getById(serialNum);
  }

  async createPeriodRecord(periodRecord: PeriodRecordCreate): Promise<PeriodRecords> {
    return this.periodRecordMapper.create(periodRecord);
  }

  async updatePeriodRecord(
    serialNum: string,
    periodRecord: PeriodRecordUpdate,
  ): Promise<PeriodRecords> {
    return this.periodRecordMapper.update(serialNum, periodRecord);
  }

  async deletePeriodRecord(serialNum: string): Promise<void> {
    return this.periodRecordMapper.deleteById(serialNum);
  }

  async listPagedPeriodRecord(
    query: PageQuery<PeriodRecordFilter> = {
      currentPage: 1,
      pageSize: 10,
      sortOptions: {},
      filter: {},
    },
  ): Promise<PagedResult<PeriodRecords>> {
    return this.periodRecordMapper.listPaged(query);
  }
  // =================== PeriodRecord ===================

  // =================== PeriodDailyRecord ===================
  async getPeriodDailyRecord(serialNum: string): Promise<PeriodDailyRecords | null> {
    return this.periodDailyRecordMapper.getById(serialNum);
  }

  async createPeriodDailyRecord(
    periodRecord: PeriodDailyRecordCreate,
  ): Promise<PeriodDailyRecords> {
    return this.periodDailyRecordMapper.create(periodRecord);
  }

  async updatePeriodDailyRecord(
    serialNum: string,
    periodRecord: PeriodDailyRecordUpdate,
  ): Promise<PeriodDailyRecords> {
    return this.periodDailyRecordMapper.update(serialNum, periodRecord);
  }

  async deletePeriodDailyRecord(serialNum: string): Promise<void> {
    return this.periodDailyRecordMapper.deleteById(serialNum);
  }

  async listPagedPeriodDailyRecord(
    query: PageQuery<PeriodDailyRecordFilter> = {
      currentPage: 1,
      pageSize: 10,
      sortOptions: {},
      filter: {},
    },
  ): Promise<PagedResult<PeriodDailyRecords>> {
    return this.periodDailyRecordMapper.listPaged(query);
  }

  // =================== PeriodDailyRecord ===================

  // =================== PeriodSettings ===================
  async getPeriodSettings(serialNum: string): Promise<PeriodSettings | null> {
    return this.periodSettingsMapper.getById(serialNum);
  }

  async createPeriodSettings(periodSettings: PeriodSettingsCreate): Promise<PeriodSettings> {
    return this.periodSettingsMapper.create(periodSettings);
  }

  async updatePeriodSettings(
    serialNum: string,
    periodSettings: PeriodSettingsUpdate,
  ): Promise<PeriodSettings> {
    return this.periodSettingsMapper.update(serialNum, periodSettings);
  }

  async deletePeriodSettings(serialNum: string): Promise<void> {
    return this.periodSettingsMapper.deleteById(serialNum);
  }
  // =================== PeriodSettings ===================
}

// 导出单例实例
export const HealthsDb = new HealthsDbService();
