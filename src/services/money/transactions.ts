import { invokeCommand } from '@/types/api';
import { DateUtils } from '@/utils/date';
import { db } from '@/utils/dbUtils';
import { Lg } from '@/utils/debugLog';
import { BaseMapper } from './baseManager';
import type { PagedResult } from './baseManager';
import type { DateRange, IncomeExpense, PageQuery } from '@/schema/common';
import type {
  Transaction,
  TransactionCreate,
  TransactionUpdate,
} from '@/schema/money';

export interface TransactionFilters {
  transactionType?: string;
  transactionStatus?: string;
  accountSerialNum?: string;
  category?: string;
  subCategory?: string;
  paymentMethod?: string;
  dateRange?: DateRange;
  amountRange?: { min?: number; max?: number };
  createdAtRange?: DateRange;
}

/**
 * 交易数据映射器
 */
export class TransactionMapper extends BaseMapper<
  TransactionCreate,
  TransactionUpdate,
  Transaction
> {
  protected entityName = 'transactions';
  async create(transaction: TransactionCreate): Promise<Transaction> {
    try {
      const result = await invokeCommand<Transaction>('transaction_create', {
        data: transaction,
      });
      Lg.d('MoneyDb', `Transaction created:, ${result.serialNum}`);
      return result;
    } catch (error) {
      this.handleError('create', error);
    }
  }

  async getById(serialNum: string): Promise<Transaction | null> {
    try {
      const result = await invokeCommand<Transaction>('transaction_get', {
        serialNum,
      });
      return result;
    } catch (error) {
      this.handleError('getById', error);
    }
  }

  async getTransferRelatedTransaction(
    serialNum: string,
  ): Promise<Transaction | null> {
    try {
      const result = await invokeCommand<Transaction>('transaction_get', {
        serialNum,
      });
      return result;
    } catch (error) {
      this.handleError('getTransferRelatedTransaction', error);
    }
  }

  async list(): Promise<Transaction[]> {
    try {
      const result = await invokeCommand<Transaction[]>('transaction_list', {
        filter: {},
      });
      return result;
    } catch (error) {
      this.handleError('list', error);
    }
  }

  async update(
    serialNum: string,
    transaction: TransactionUpdate,
  ): Promise<Transaction> {
    try {
      const result = await invokeCommand<Transaction>('transaction_update', {
        serialNum,
        data: transaction,
      });
      Lg.d('MoneyDb', 'Transaction updated:', { serialNum });
      return result;
    } catch (error) {
      this.handleError('update', error);
    }
  }

  async deleteById(serialNum: string): Promise<void> {
    try {
      await invokeCommand('transaction_delete', { serialNum });
      Lg.d('MoneyDb', 'Transaction deleted:', { serialNum });
    } catch (error) {
      this.handleError('deleteById', error);
    }
  }

  async listPaged(
    query: PageQuery<TransactionFilters> = {
      currentPage: 1,
      pageSize: 10,
      sortOptions: {},
      filter: {},
    },
  ): Promise<PagedResult<Transaction>> {
    try {
      const result = await invokeCommand<PagedResult<Transaction>>(
        'transaction_list_paged',
        { query },
      );
      return result;
    } catch (err) {
      this.handleError('listPaged', err);
    }
  }

  /**
   * 本月收入、支出与转账
   */
  async monthlyIncomeAndExpense(): Promise<IncomeExpense> {
    const [startDate, endDate] = DateUtils.getCurrentMonthRange();
    return this.queryIncomeAndExpense(startDate, endDate);
  }

  /**
   * 上个月收入、支出与转账
   */
  async lastMonthIncomeAndExpense(): Promise<IncomeExpense> {
    const [startDate, endDate] = DateUtils.getLastMonthRange();
    return this.queryIncomeAndExpense(startDate, endDate);
  }

  /**
   * 本年度收入、支出与转账
   */
  async yearlyIncomeAndExpense(): Promise<IncomeExpense> {
    const [startDate, endDate] = DateUtils.getCurrentYearRange();
    return this.queryIncomeAndExpense(startDate, endDate);
  }

  /**
   * 去年整年收入、支出与转账
   */
  async lastYearIncomeAndExpense(): Promise<IncomeExpense> {
    const [startDate, endDate] = DateUtils.getLastYearRange();
    return this.queryIncomeAndExpense(startDate, endDate);
  }

  /**
   * 构建删除交易的 SQL 操作
   * @param serialNum 交易序列号
   */
  buildDeleteOperation(serialNum: string): { sql: string; params: any[] } {
    return {
      sql: 'DELETE FROM transactions WHERE serial_num = ?',
      params: [serialNum],
    };
  }

  private async queryIncomeAndExpense(
    startDate: string,
    endDate: string,
  ): Promise<IncomeExpense> {
    const query = `
    SELECT
      SUM(CASE WHEN transaction_type = 'Income' THEN amount ELSE 0 END) AS totalIncome,
      SUM(CASE WHEN transaction_type = 'Expense' THEN amount ELSE 0 END) AS totalExpense,
      SUM(CASE
            WHEN category = 'Transfer' AND transaction_type = 'Income' THEN amount ELSE 0 END) AS transferIncome,
      SUM(CASE
            WHEN category = 'Transfer' AND transaction_type = 'Expense' THEN amount ELSE 0 END) AS transferExpense
    FROM transactions
    WHERE date >= ? AND date < ? and is_deleted = 0;
  `;
    try {
      const result = await db.select(query, [startDate, endDate], false);
      const row = result[0];
      return {
        income: {
          total: row?.totalIncome || 0,
          transfer: row?.transferIncome || 0,
        },
        expense: {
          total: row?.totalExpense || 0,
          transfer: row?.transferExpense || 0,
        },
        transfer: {
          income: 0,
          expense: 0,
        },
      };
    } catch (error) {
      this.handleError('queryIncomeAndExpense', error);
    }
  }
}
