import { invokeCommand } from '@/types/api';
import { BaseMapper } from './baseManager';
import type { PagedResult } from './baseManager';
import type { DateRange, PageQuery } from '@/schema/common';
import type { Budget, BudgetCreate, BudgetUpdate } from '@/schema/money';

export interface BudgetFilters {
  // status?: string;
  accountSerialNum?: string;
  name?: string;
  amount?: number;
  repeatPeriod?: string;
  startDate?: DateRange;
  endDate?: DateRange;
  usedAmount?: number;
  alertThreshold?: string;
  category?: string;
  isActive?: boolean;
  alertEnabled?: boolean;
  // completion?: string; // ✅ 对应 filters.completion
  // period?: string;
}

/**
 * 预算数据映射器
 */
export class BudgetMapper extends BaseMapper<
  BudgetCreate,
  BudgetUpdate,
  Budget
> {
  protected entityName = 'budget';
  async create(budget: BudgetCreate): Promise<Budget> {
    try {
      const result = await invokeCommand<Budget>('budget_create', {
        data: budget,
      });
      return result;
    } catch (error) {
      this.handleError('create', error);
    }
  }

  async getById(serialNum: string): Promise<Budget | null> {
    try {
      const result = await invokeCommand<Budget>('budget_get', { serialNum });
      return result;
    } catch (error) {
      this.handleError('getById', error);
    }
  }

  async update(serialNum: string, budget: BudgetUpdate): Promise<Budget> {
    try {
      const result = await invokeCommand<Budget>('budget_update', {
        serialNum,
        data: budget,
      });
      return result;
    } catch (error) {
      this.handleError('update', error);
    }
  }

  async updateActive(serialNum: string, isActive: boolean): Promise<Budget> {
    try {
      return await invokeCommand<Budget>('budget_update_active', {
        serialNum,
        isActive,
      });
    } catch (error) {
      this.handleError('updateBudgetActive', error);
    }
  }

  async deleteById(serialNum: string): Promise<void> {
    try {
      await invokeCommand('budget_delete', { serialNum });
    } catch (error) {
      this.handleError('deleteById', error);
    }
  }

  async list(): Promise<Budget[]> {
    try {
      const result = await invokeCommand<Budget[]>('budget_list', {
        filter: {},
      });
      return result;
    } catch (error) {
      this.handleError('list', error);
    }
  }

  async listPaged(
    query: PageQuery<BudgetFilters>,
  ): Promise<PagedResult<Budget>> {
    try {
      const result = await invokeCommand<PagedResult<Budget>>(
        'budget_list_paged',
        { query },
      );
      return result;
    } catch (err) {
      this.handleError('listPaged', err);
    }
  }
}
