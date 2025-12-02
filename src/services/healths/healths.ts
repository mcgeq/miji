import { PeriodDailyRecordMapper } from './period_daily_record';
import { PeriodRecordMapper } from './period_record';
import { PeriodSettingsMapper } from './period_settings';
import type { PagedResult } from '../money/baseManager';
import type { PeriodDailyRecordFilter } from './period_daily_record';
import type { PeriodRecordFilter } from './period_record';
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

export class HealthsDb {
  private static periodRecordMapper = new PeriodRecordMapper();
  private static periodDailyRecordMapper = new PeriodDailyRecordMapper();
  private static periodSettingsMapper = new PeriodSettingsMapper();

  // =================== PeriodRecord ===================
  static async getPeriodRecord(serialNum: string): Promise<PeriodRecords | null> {
    return this.periodRecordMapper.getById(serialNum);
  }

  static async createPeriodRecord(periodRecord: PeriodRecordCreate): Promise<PeriodRecords> {
    return this.periodRecordMapper.create(periodRecord);
  }

  static async updatePeriodRecord(
    serialNum: string,
    periodRecord: PeriodRecordUpdate,
  ): Promise<PeriodRecords> {
    return this.periodRecordMapper.update(serialNum, periodRecord);
  }

  static async deletePeriodRecord(serialNum: string): Promise<void> {
    return this.periodRecordMapper.deleteById(serialNum);
  }

  static async listPagedPeriodRecord(
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
  static async getPeriodDailyRecord(serialNum: string): Promise<PeriodDailyRecords | null> {
    return this.periodDailyRecordMapper.getById(serialNum);
  }

  static async createPeriodDailyRecord(
    periodRecord: PeriodDailyRecordCreate,
  ): Promise<PeriodDailyRecords> {
    return this.periodDailyRecordMapper.create(periodRecord);
  }

  static async updatePeriodDailyRecord(
    serialNum: string,
    periodRecord: PeriodDailyRecordUpdate,
  ): Promise<PeriodDailyRecords> {
    return this.periodDailyRecordMapper.update(serialNum, periodRecord);
  }

  static async deletePeriodDailyRecord(serialNum: string): Promise<void> {
    return this.periodDailyRecordMapper.deleteById(serialNum);
  }

  static async listPagedPeriodDailyRecord(
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
  static async getPeriodSettings(serialNum: string): Promise<PeriodSettings | null> {
    return this.periodSettingsMapper.getById(serialNum);
  }

  static async createPeriodSettings(periodSettings: PeriodSettingsCreate): Promise<PeriodSettings> {
    return this.periodSettingsMapper.create(periodSettings);
  }

  static async updatePeriodSettings(
    serialNum: string,
    periodSettings: PeriodSettingsUpdate,
  ): Promise<PeriodSettings> {
    return this.periodSettingsMapper.update(serialNum, periodSettings);
  }

  static async deletePeriodSettings(serialNum: string): Promise<void> {
    return this.periodSettingsMapper.deleteById(serialNum);
  }
  // =================== PeriodSettings ===================
}
