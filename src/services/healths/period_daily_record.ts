import type { PageQuery } from '@/schema/common';
import { SortDirection } from '@/schema/common';
import type {
  PeriodDailyRecordCreate,
  PeriodDailyRecords,
  PeriodDailyRecordUpdate,
} from '@/schema/health/period';
import { invokeCommand } from '@/types/api';
import type { PagedResult } from '../money/baseManager';
import { BaseMapper } from '../money/baseManager';

export interface PeriodDailyRecordFilter {
  date?: string;
  flowLevel?: number;
  sexualActivity?: boolean;
  contraceptionMethod?: string;
  exerciseIntensity?: string;
  diet?: string;
  mood?: string;
  waterIntake?: number;
  sleepHours?: number;
  notes?: string;
}

/**
 * 账户数据映射器
 */
export class PeriodDailyRecordMapper extends BaseMapper<
  PeriodDailyRecordCreate,
  PeriodDailyRecordUpdate,
  PeriodDailyRecords
> {
  protected entityName = 'periodRecord';

  async create(periodDailyRecord: PeriodDailyRecordCreate): Promise<PeriodDailyRecords> {
    try {
      return await invokeCommand<PeriodDailyRecords>('period_daily_record_create', {
        data: periodDailyRecord,
      });
    } catch (error) {
      this.handleError('period_daily_record_create', error);
    }
  }

  async getById(serialNum: string): Promise<PeriodDailyRecords | null> {
    try {
      const account = await invokeCommand<PeriodDailyRecords>('period_daily_record_get', {
        serialNum,
      });
      return account;
    } catch (error) {
      this.handleError('period_daily_record_get', error);
    }
  }

  async list(): Promise<PeriodDailyRecords[]> {
    try {
      // Use listPaged with a large page size to get all records
      const result = await this.listPaged({
        currentPage: 1,
        pageSize: 1000, // Large enough to get all records
        sortOptions: {
          desc: true,
          sortDir: SortDirection.Desc,
        },
        filter: {},
      });
      return result.rows;
    } catch (error) {
      this.handleError('period_daily_record_list', error);
    }
  }

  async update(
    serialNum: string,
    periodDailyRecord: PeriodDailyRecordUpdate,
  ): Promise<PeriodDailyRecords> {
    try {
      const result = await invokeCommand<PeriodDailyRecords>('period_daily_record_update', {
        serialNum,
        data: periodDailyRecord,
      });
      return result;
    } catch (error) {
      this.handleError('period_daily_record_update', error);
    }
  }

  async deleteById(serialNum: string): Promise<void> {
    try {
      await invokeCommand('period_daily_record_delete', { serialNum });
    } catch (error) {
      this.handleError('period_daily_record_delete', error);
    }
  }

  async listPaged(
    query: PageQuery<PeriodDailyRecordFilter> = {
      currentPage: 1,
      pageSize: 10,
      sortOptions: {},
      filter: {},
    },
  ): Promise<PagedResult<PeriodDailyRecords>> {
    try {
      const result = await invokeCommand<PagedResult<PeriodDailyRecords>>(
        'period_daily_record_list_paged',
        {
          query,
        },
      );
      return result;
    } catch (error) {
      this.handleError('period_record_list_paged', error);
    }
  }
}
