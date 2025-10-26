import { budgetStatsService } from '@/services/money/budgetStats';
import type {
  BudgetCategoryStats,
  BudgetOverviewRequest,
  BudgetOverviewSummary,
  BudgetScopeStats,
  BudgetTrendData,
  BudgetTypeStats,
} from '@/services/money/budgetStats';

// 预算统计状态
export interface BudgetStatsState {
  loading: boolean;
  overview: BudgetOverviewSummary | null;
  typeStats: BudgetTypeStats | null;
  scopeStats: BudgetScopeStats | null;
  trends: BudgetTrendData[];
  categoryStats: BudgetCategoryStats[];
  error: string | null;
}

// 预算统计筛选条件
export interface BudgetStatsFilters {
  baseCurrency: string;
  calculationDate?: string;
  includeInactive: boolean;
  timeRange: {
    startDate: string;
    endDate: string;
  };
  period: 'month' | 'week';
}

// 全局状态实例
let globalStatsState: ReturnType<typeof createStatsState> | null = null;

// 创建状态
function createStatsState() {
  // 响应式状态
  const state = ref<BudgetStatsState>({
    loading: false,
    overview: null,
    typeStats: null,
    scopeStats: null,
    trends: [],
    categoryStats: [],
    error: null,
  });

  // 筛选条件
  const filters = ref<BudgetStatsFilters>({
    baseCurrency: 'CNY',
    includeInactive: false,
    timeRange: {
      startDate: new Date(new Date().getFullYear(), new Date().getMonth(), 1)
        .toISOString()
        .split('T')[0],
      endDate: new Date().toISOString().split('T')[0],
    },
    period: 'month',
  });

  // 计算属性
  const hasData = computed(() => {
    // 如果有概览数据且预算数量大于0，则认为有数据
    if (state.value.overview && state.value.overview.budgetCount > 0) {
      return true;
    }

    // 如果有其他类型的数据
    if (state.value.typeStats && Object.keys(state.value.typeStats).length > 0) {
      return true;
    }

    if (state.value.scopeStats && Object.keys(state.value.scopeStats).length > 0) {
      return true;
    }

    if (state.value.trends.length > 0) {
      return true;
    }

    if (state.value.categoryStats.length > 0) {
      return true;
    }

    return false;
  });

  const isHealthy = computed(() => {
    if (!state.value.overview) return true;
    return state.value.overview.completionRate <= 80 && state.value.overview.overBudgetCount === 0;
  });

  const needsAttention = computed(() => {
    if (!state.value.overview) return false;
    return state.value.overview.completionRate > 80 || state.value.overview.overBudgetCount > 0;
  });

  // 方法
  const setLoading = (loading: boolean) => {
    state.value.loading = loading;
  };

  const setError = (error: string | null) => {
    state.value.error = error;
  };

  const clearError = () => {
    state.value.error = null;
  };

  /**
   * 加载预算总览统计
   */
  const loadOverview = async () => {
    try {
      setLoading(true);
      clearError();
      const request: BudgetOverviewRequest = {
        baseCurrency: filters.value.baseCurrency,
        calculationDate: filters.value.calculationDate,
        includeInactive: filters.value.includeInactive,
      };

      const overview = await budgetStatsService.getBudgetOverview(request);
      // 确保数据类型正确
      const processedOverview: BudgetOverviewSummary = {
        totalBudgetAmount: Number(overview.totalBudgetAmount),
        usedAmount: Number(overview.usedAmount),
        remainingAmount: Number(overview.remainingAmount),
        completionRate: Number(overview.completionRate),
        overBudgetAmount: Number(overview.overBudgetAmount),
        budgetCount: Number(overview.budgetCount),
        overBudgetCount: Number(overview.overBudgetCount),
        currency: overview.currency,
        calculatedAt: overview.calculatedAt,
      };
      state.value.overview = processedOverview;
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : '加载预算总览失败';
      console.error('加载预算总览失败:', error);
      setError(errorMessage);
    } finally {
      setLoading(false);
    }
  };

  /**
   * 加载按类型统计
   */
  const loadTypeStats = async () => {
    try {
      setLoading(true);
      clearError();

      const request: BudgetOverviewRequest = {
        baseCurrency: filters.value.baseCurrency,
        calculationDate: filters.value.calculationDate,
        includeInactive: filters.value.includeInactive,
      };

      const typeStats = await budgetStatsService.getBudgetStatsByType(request);
      state.value.typeStats = typeStats;
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : '加载预算类型统计失败';
      setError(errorMessage);
      console.error('加载预算类型统计失败:', error);
    } finally {
      setLoading(false);
    }
  };

  /**
   * 加载按范围统计
   */
  const loadScopeStats = async () => {
    try {
      setLoading(true);
      clearError();

      const request: BudgetOverviewRequest = {
        baseCurrency: filters.value.baseCurrency,
        calculationDate: filters.value.calculationDate,
        includeInactive: filters.value.includeInactive,
      };

      const scopeStats = await budgetStatsService.getBudgetStatsByScope(request);
      state.value.scopeStats = scopeStats;
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : '加载预算范围统计失败';
      setError(errorMessage);
      console.error('加载预算范围统计失败:', error);
    } finally {
      setLoading(false);
    }
  };

  /**
   * 加载趋势数据
   */
  const loadTrends = async () => {
    try {
      setLoading(true);
      clearError();

      const trends = await budgetStatsService.getBudgetTrends(
        filters.value.timeRange.startDate,
        filters.value.timeRange.endDate,
        filters.value.period,
      );

      // 转换数据类型
      const processedTrends = trends.map(trend => ({
        period: trend.period,
        totalBudget: Number(trend.totalBudget),
        usedAmount: Number(trend.usedAmount),
        remainingAmount: Number(trend.remainingAmount),
        completionRate: Number(trend.completionRate),
      }));

      state.value.trends = processedTrends;
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : '加载预算趋势数据失败';
      setError(errorMessage);
      console.error('加载预算趋势数据失败:', error);
    } finally {
      setLoading(false);
    }
  };

  /**
   * 加载分类统计
   */
  const loadCategoryStats = async () => {
    try {
      setLoading(true);
      clearError();

      const categoryStats = await budgetStatsService.getBudgetCategoryStats();

      // 转换数据类型
      const processedCategoryStats = categoryStats.map(stat => ({
        category: stat.category,
        budgetCount: Number(stat.budgetCount),
        totalBudget: Number(stat.totalBudget),
        usedAmount: Number(stat.usedAmount),
        averageCompletionRate: Number(stat.averageCompletionRate),
      }));

      state.value.categoryStats = processedCategoryStats;
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : '加载预算分类统计失败';
      setError(errorMessage);
      console.error('加载预算分类统计失败:', error);
    } finally {
      setLoading(false);
    }
  };

  /**
   * 加载所有统计数据
   */
  const loadAllStats = async () => {
    try {
      setLoading(true);
      clearError();

      await Promise.all([
        loadOverview(),
        loadTypeStats(),
        loadScopeStats(),
        loadTrends(),
        loadCategoryStats(),
      ]);
    } catch (error) {
      const errorMessage = error instanceof Error ? error.message : '加载统计数据失败';
      setError(errorMessage);
      console.error('加载统计数据失败:', error);
    } finally {
      setLoading(false);
    }
  };

  /**
   * 刷新数据
   */
  const refresh = async () => {
    await loadAllStats();
  };

  /**
   * 重置筛选条件
   */
  const resetFilters = () => {
    filters.value = {
      baseCurrency: 'CNY',
      includeInactive: false,
      timeRange: {
        startDate: new Date(new Date().getFullYear(), new Date().getMonth(), 1)
          .toISOString()
          .split('T')[0],
        endDate: new Date().toISOString().split('T')[0],
      },
      period: 'month',
    };
  };

  /**
   * 更新筛选条件
   */
  const updateFilters = (newFilters: Partial<BudgetStatsFilters>) => {
    filters.value = { ...filters.value, ...newFilters };
  };

  return {
    // 状态
    state: readonly(state),
    filters: readonly(filters),

    // 计算属性
    hasData,
    isHealthy,
    needsAttention,

    // 方法
    loadOverview,
    loadTypeStats,
    loadScopeStats,
    loadTrends,
    loadCategoryStats,
    loadAllStats,
    refresh,
    resetFilters,
    updateFilters,
    setLoading,
    setError,
    clearError,
  };
}

/**
 * 预算统计分析 Composable
 */
export function useBudgetStats() {
  // 使用单例模式，确保全局状态一致
  if (!globalStatsState) {
    globalStatsState = createStatsState();
  }
  return globalStatsState;
}
