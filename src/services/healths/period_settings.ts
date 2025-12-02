import { invokeCommand } from '@/types/api';
import { BaseMapper } from '../money/baseManager';
import type {
  PeriodSettings,
  PeriodSettingsCreate,
  PeriodSettingsUpdate,
} from '@/schema/health/period';

export interface PeriodSettingsFilter {}

/**
 * 账户数据映射器
 */
export class PeriodSettingsMapper extends BaseMapper<
  PeriodSettingsCreate,
  PeriodSettingsUpdate,
  PeriodSettings
> {
  protected entityName = 'periodRecord';

  async create(periodRecord: PeriodSettingsCreate): Promise<PeriodSettings> {
    try {
      return await invokeCommand<PeriodSettings>('period_settings_create', { data: periodRecord });
    } catch (error) {
      this.handleError('period_record_create', error);
    }
  }

  async getById(serialNum: string): Promise<PeriodSettings | null> {
    try {
      const account = await invokeCommand<PeriodSettings>('period_settings_get', {
        serialNum,
      });
      return account;
    } catch (error) {
      this.handleError('period_record_get', error);
    }
  }

  async list(): Promise<PeriodSettings[]> {
    try {
      return [];
    } catch (error) {
      this.handleError('period_record_list_paged', error);
    }
  }

  async update(serialNum: string, periodRecord: PeriodSettingsUpdate): Promise<PeriodSettings> {
    try {
      const result = await invokeCommand<PeriodSettings>('period_record_update', {
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
