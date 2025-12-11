import type { IncomeExpense, PageQuery } from '@/schema/common';
import type {
  Transaction,
  TransactionCreate,
  TransactionUpdate,
  TransferCreate,
} from '@/schema/money';
import { invokeCommand } from '@/types/api';
import { DateUtils } from '@/utils/date';
import { Lg } from '@/utils/debugLog';
import type { PagedResult } from './baseManager';
import { BaseMapper } from './baseManager';

// 分期付款相关类型定义
export interface InstallmentPlanResponse {
  serial_num: string;
  transaction_serial_num: string;
  total_amount: number;
  total_periods: number;
  installment_amount: number;
  first_due_date: string;
  status: string;
  created_at: string;
  updated_at?: string;
  details: InstallmentDetailResponse[];
}

export interface InstallmentDetailResponse {
  serial_num: string;
  plan_serial_num: string;
  period_number: number;
  due_date: string;
  amount: number;
  status: string;
  paid_date?: string;
  paid_amount?: number;
  created_at: string;
  updated_at?: string;
}

// 统计相关的类型定义
export interface TransactionStatsRequest {
  startDate: string;
  endDate: string;
  timeDimension?: string;
  category?: string;
  subCategory?: string;
  accountSerialNum?: string;
  transactionType?: string;
  currency?: string;
}

export interface TransactionStatsSummary {
  totalIncome: number;
  totalExpense: number;
  netIncome: number;
  transactionCount: number;
  averageTransaction: number;
}

export interface CategoryStats {
  category: string;
  amount: number;
  count: number;
  percentage: number;
}

export interface PaymentMethodStats {
  paymentMethod: string;
  amount: number;
  count: number;
  percentage: number;
}

export interface TimeTrendStats {
  period: string;
  income: number;
  expense: number;
  netIncome: number;
}

export interface TransactionStatsResponse {
  summary: TransactionStatsSummary;
  topCategories: CategoryStats[];
  topIncomeCategories: CategoryStats[];
  topTransferCategories: CategoryStats[];
  topPaymentMethods: PaymentMethodStats[];
  topIncomePaymentMethods: PaymentMethodStats[];
  topTransferPaymentMethods: PaymentMethodStats[];
  monthlyTrends: TimeTrendStats[];
  weeklyTrends: TimeTrendStats[];
}

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

  async getStats(request: TransactionStatsRequest): Promise<TransactionStatsResponse> {
    try {
      const result = await invokeCommand<TransactionStatsResponse>('transaction_get_stats', {
        request,
      });
      return result;
    } catch (error) {
      this.handleError('getStats', error);
    }
  }

  async update(serialNum: string, transaction: TransactionUpdate): Promise<Transaction> {
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

  async listPaged(query: PageQuery<TransactionFilters>): Promise<PagedResult<Transaction>> {
    try {
      const result = await invokeCommand<PagedResult<Transaction>>('transaction_list_paged', {
        query,
      });
      return result;
    } catch (err) {
      this.handleError('listPaged', err);
    }
  }

  async transfer(transfer: TransferCreate): Promise<[Transaction, Transaction]> {
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

  private async queryIncomeAndExpense(startDate: string, endDate: string): Promise<IncomeExpense> {
    try {
      const result = await invokeCommand<IncomeExpense>('transaction_query_income_and_expense', {
        startDate,
        endDate,
      });
      return result;
    } catch (error) {
      this.handleError('queryIncomeAndExpense', error);
    }
  }

  // ==================== 分期付款相关方法 ====================

  /**
   * 获取分期付款计划
   */
  async getInstallmentPlan(planSerialNum: string): Promise<InstallmentPlanResponse> {
    try {
      const result = await invokeCommand<InstallmentPlanResponse>('installment_plan_get', {
        planSerialNum,
      });
      return result;
    } catch (err) {
      this.handleError('getInstallmentPlan', err);
    }
  }

  /**
   * 获取待还款的分期明细
   */
  async getPendingInstallments(): Promise<InstallmentPlanResponse[]> {
    try {
      const result = await invokeCommand<InstallmentPlanResponse[]>('installment_pending_list', {});
      return result;
    } catch (err) {
      this.handleError('getPendingInstallments', err);
    }
  }
}
