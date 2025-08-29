import { invokeCommand } from '@/types/api';
import { BaseMapper } from './baseManager';
import type { PagedResult } from './baseManager';
import type { DateRange, PageQuery } from '@/schema/common';
import type {
  BilReminder,
  BilReminderCreate,
  BilReminderUpdate,
} from '@/schema/money';

export interface BilReminderFilters {
  type?: string;
  enabled?: boolean;
  category?: string;
  isPaid?: boolean;
  priority?: string;
  dueDateRange?: DateRange;
  createdAtRange?: DateRange;
}

/**
 * 账单提醒数据映射器
 */
export class BilReminderMapper extends BaseMapper<
  BilReminderCreate,
  BilReminderUpdate,
  BilReminder
> {
  protected entityName = 'bil_reminder';

  async create(reminder: BilReminderCreate): Promise<BilReminder> {
    try {
      const result = await invokeCommand<BilReminder>('bil_reminder_create', {
        data: reminder,
      });
      return result;
    } catch (error) {
      this.handleError('create', error);
    }
  }

  async getById(serialNum: string): Promise<BilReminder | null> {
    try {
      const result = await invokeCommand<BilReminder>('bil_reminder_get', {
        serialNum,
      });
      return result;
    } catch (error) {
      this.handleError('getById', error);
    }
  }

  async update(
    serialNum: string,
    reminder: BilReminderUpdate,
  ): Promise<BilReminder> {
    try {
      const result = await invokeCommand<BilReminder>('bil_reminder_update', {
        serialNum,
        data: reminder,
      });
      return result;
    } catch (error) {
      this.handleError('update', error);
    }
  }

  async updateActive(
    serialNum: string,
    isActive: boolean,
  ): Promise<BilReminder> {
    try {
      return await invokeCommand<BilReminder>('bil_reminder_update_active', {
        serialNum,
        isActive,
      });
    } catch (error) {
      this.handleError('updateBudgetActive', error);
    }
  }

  async deleteById(serialNum: string): Promise<void> {
    try {
      await invokeCommand('bil_reminder_delete', { serialNum });
    } catch (error) {
      this.handleError('deleteById', error);
    }
  }
  async list(): Promise<BilReminder[]> {
    try {
      const result = await invokeCommand<BilReminder[]>('bil_reminder_list', {
        filter: {},
      });
      return result;
    } catch (error) {
      this.handleError('list', error);
    }
  }

  async listPaged(
    query: PageQuery<BilReminderFilters> = {
      currentPage: 1,
      pageSize: 10,
      sortOptions: {},
      filter: {},
    },
  ): Promise<PagedResult<BilReminder>> {
    try {
      const result = await invokeCommand<PagedResult<BilReminder>>(
        'bil_reminder_list_paged',
        { query },
      );
      return result;
    } catch (error) {
      this.handleError('listPaged', error);
    }
  }
}
