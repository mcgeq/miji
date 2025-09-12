import { invokeCommand } from '@/types/api';
import { BaseMapper } from '../money/baseManager';
import type { PagedResult } from '../money/baseManager';
import type { DateRange, PageQuery } from '@/schema/common';
import type { PeriodRecordCreate, PeriodRecords, PeriodRecordUpdate } from '@/schema/health/period';

export interface PeriodRecordFilter {
  notes?: string;
  startDate?: DateRange;
  endDate?: DateRange;
}

/**
 * 账户数据映射器
 */
export class PeriodRecordMapper extends BaseMapper<
  PeriodRecordCreate,
  PeriodRecordUpdate,
  PeriodRecords
> {
  protected entityName = 'periodRecord';

  async create(periodRecord: PeriodRecordCreate): Promise<PeriodRecords> {
    try {
      return await invokeCommand<PeriodRecords>('period_record_create', { data: periodRecord });
    } catch (error) {
      this.handleError('period_record_create', error);
    }
  }

  async getById(serialNum: string): Promise<PeriodRecords | null> {
    try {
      const account = await invokeCommand<PeriodRecords>('period_record_get', {
        serialNum,
      });
      return account;
    } catch (error) {
      this.handleError('period_record_get', error);
    }
  }

  async listPaged(
    query: PageQuery<PeriodRecordFilter> = {
      currentPage: 1,
      pageSize: 10,
      sortOptions: {},
      filter: {},
    },
  ): Promise<PagedResult<PeriodRecords>> {
    try {
      const result = await invokeCommand<PagedResult<PeriodRecords>>('period_record_list_paged', {
        query,
      });
      return result;
    } catch (error) {
      this.handleError('period_record_list_paged', error);
    }
  }

  async list(): Promise<PeriodRecords[]> {
    try {
      return await invokeCommand<PeriodRecords[]>('period_record_list', { filter: {} });
    } catch (error) {
      this.handleError('period_record_list_paged', error);
    }
  }

  async update(serialNum: string, periodRecord: PeriodRecordUpdate): Promise<PeriodRecords> {
    try {
      const result = await invokeCommand<PeriodRecords>('period_record_update', {
        serialNum,
        data: periodRecord,
      });
      return result;
    } catch (error) {
      this.handleError('period_record_update', error);
    }
  }

  async deleteById(serialNum: string): Promise<void> {
    try {
      await invokeCommand('period_record_delete', { serialNum });
    } catch (error) {
      this.handleError('period_record_delete', error);
    }
  }
}
