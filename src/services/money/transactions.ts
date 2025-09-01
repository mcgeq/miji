import { invokeCommand } from '@/types/api';
import { DateUtils } from '@/utils/date';
import { Lg } from '@/utils/debugLog';
import { BaseMapper } from './baseManager';
import type { PagedResult } from './baseManager';
import type { IncomeExpense, PageQuery } from '@/schema/common';
import type {
  Transaction,
  TransactionCreate,
  TransactionUpdate,
  TransferCreate,
} from '@/schema/money';

export interface TransactionFilters {
  transactionType?: string;
  transactionStatus?: string;
  dateStart?: string;
  dateEnd?: string;
  amountMin?: number;
  amountMax?: number;
  currency?: string;
  accountSerialNum?: string;
  category?: string;
  subCategory?: string;
  paymentMethod?: string;
  actualPayerAccount?: string;
  isDeleted?: boolean;
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
    query: PageQuery<TransactionFilters>,
  ): Promise<PagedResult<Transaction>> {
    try {
      console.log('listPaged', query);
      const result = await invokeCommand<PagedResult<Transaction>>(
        'transaction_list_paged',
        { query },
      );
      return result;
    } catch (err) {
      this.handleError('listPaged', err);
    }
  }

  async transfer(
    transfer: TransferCreate,
  ): Promise<[Transaction, Transaction]> {
    try {
      const result = await invokeCommand<[Transaction, Transaction]>(
        'transaction_transfer_create',
        { data: transfer },
      );
      return result;
    } catch (err) {
      this.handleError('transfer', err);
    }
  }

  async transferUpdate(
    serialNum: string,
    transfer: TransferCreate,
  ): Promise<[Transaction, Transaction]> {
    try {
      const result = await invokeCommand<[Transaction, Transaction]>(
        'transaction_transfer_update',
        { serialNum, transfer },
      );
      return result;
    } catch (err) {
      this.handleError('transfer', err);
    }
  }

  async transferDelete(serialNum: string): Promise<[Transaction, Transaction]> {
    try {
      const result = await invokeCommand<[Transaction, Transaction]>(
        'transaction_transfer_delete',
        { serialNum },
      );
      return result;
    } catch (err) {
      this.handleError('transfer', err);
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

  private async queryIncomeAndExpense(
    startDate: string,
    endDate: string,
  ): Promise<IncomeExpense> {
    try {
      const result = await invokeCommand<IncomeExpense>(
        'transaction_query_income_and_expense',
        {
          startDate,
          endDate,
        },
      );
      return result;
    } catch (error) {
      this.handleError('queryIncomeAndExpense', error);
    }
  }
}
