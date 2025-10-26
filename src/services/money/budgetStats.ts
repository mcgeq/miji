import { invokeCommand } from '@/types/api';

// 预算总览统计响应
export interface BudgetOverviewSummary {
  totalBudgetAmount: number;
  usedAmount: number;
  remainingAmount: number;
  completionRate: number;
  overBudgetAmount: number;
  budgetCount: number;
  overBudgetCount: number;
  currency: string;
  calculatedAt: string;
}

// 预算总览请求参数
export interface BudgetOverviewRequest {
  baseCurrency: string;
  calculationDate?: string;
  includeInactive?: boolean;
}

// 预算类型统计
export interface BudgetTypeStats {
  [budgetType: string]: BudgetOverviewSummary;
}

// 预算范围统计
export interface BudgetScopeStats {
  [scopeType: string]: BudgetOverviewSummary;
}

// 预算趋势数据
export interface BudgetTrendData {
  period: string;
  totalBudget: number;
  usedAmount: number;
  remainingAmount: number;
  completionRate: number;
}

// 预算分类统计
export interface BudgetCategoryStats {
  category: string;
  budgetCount: number;
  totalBudget: number;
  usedAmount: number;
  averageCompletionRate: number;
}

/**
 * 预算统计分析服务
 */
export class BudgetStatsService {
  /**
   * 获取预算总览统计
   */
  async getBudgetOverview(request: BudgetOverviewRequest): Promise<BudgetOverviewSummary> {
    try {
      const result = await invokeCommand<BudgetOverviewSummary>('budget_overview_calculate', {
        request,
      });
      return result;
    } catch (error) {
      console.error('获取预算总览统计失败:', error);
      throw error;
    }
  }

  /**
   * 按预算类型获取统计
   */
  async getBudgetStatsByType(request: BudgetOverviewRequest): Promise<BudgetTypeStats> {
    try {
      const result = await invokeCommand<BudgetTypeStats>('budget_overview_by_type', {
        request,
      });
      return result;
    } catch (error) {
      console.error('按预算类型获取统计失败:', error);
      throw error;
    }
  }

  /**
   * 按预算范围获取统计
   */
  async getBudgetStatsByScope(request: BudgetOverviewRequest): Promise<BudgetScopeStats> {
    try {
      const result = await invokeCommand<BudgetScopeStats>('budget_overview_by_scope', {
        request,
      });
      return result;
    } catch (error) {
      console.error('按预算范围获取统计失败:', error);
      throw error;
    }
  }

  /**
   * 获取预算趋势数据
   */
  async getBudgetTrends(
    startDate: string,
    endDate: string,
    period: 'month' | 'week' = 'month',
  ): Promise<BudgetTrendData[]> {
    try {
      const request = {
        startDate: new Date(startDate).toISOString(),
        endDate: new Date(endDate).toISOString(),
        periodType: period,
        baseCurrency: 'CNY',
        includeInactive: false,
      };
      const result = await invokeCommand<BudgetTrendData[]>('budget_trends_get', {
        request,
      });
      return result;
    } catch (error) {
      console.error('获取预算趋势数据失败:', error);
      throw error;
    }
  }

  /**
   * 获取预算分类统计
   */
  async getBudgetCategoryStats(): Promise<BudgetCategoryStats[]> {
    try {
      const result = await invokeCommand<BudgetCategoryStats[]>('budget_category_stats_get', {
        baseCurrency: 'CNY',
        includeInactive: false,
      });

      return result;
    } catch (error) {
      console.error('获取预算分类统计失败:', error);
      throw error;
    }
  }
}

// 导出单例实例
export const budgetStatsService = new BudgetStatsService();
