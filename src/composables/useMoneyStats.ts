import { computed, toValue } from 'vue';
import { createComparisonCard } from '@/features/money/common/moneyCommon';
import { formatCurrency } from '@/features/money/utils/money';
import { useCurrencyStore } from '@/stores/money';
import type { CardData } from '@/features/money/common/moneyCommon';
import type { MaybeRefOrGetter } from 'vue';

interface MoneyStatsData {
  totalAssets: number;
  monthlyIncome: number;
  prevMonthlyIncome: number;
  yearlyIncome: number;
  prevYearlyIncome: number;
  monthlyExpense: number;
  prevMonthlyExpense: number;
  yearlyExpense: number;
  prevYearlyExpense: number;
  baseCurrency: string;
}

/**
 * 资金统计卡片 Composable
 * 用于生成资产、收入、支出等统计卡片数据
 * @param statsData 统计数据（支持 Ref、ComputedRef 或普通对象）
 */
export function useMoneyStats(statsData: MaybeRefOrGetter<MoneyStatsData>) {
  const currencyStore = useCurrencyStore();

  /**
   * 获取货币符号
   */
  const getCurrencySymbol = (currencyCode: string): string => {
    const currency = currencyStore.getCurrencyByCode(currencyCode);
    return currency?.symbol || currencyCode;
  };

  /**
   * 统计卡片数据
   */
  const statCards = computed<CardData[]>(() => {
    // 解包响应式数据
    const data = toValue(statsData);
    const symbol = getCurrencySymbol(data.baseCurrency);

    return [
      // 总资产卡片
      {
        id: 'total-assets',
        title: '总资产',
        value: formatCurrency(data.totalAssets),
        currency: symbol,
        icon: 'wallet',
        color: 'primary' as const,
      },

      // 月度收入对比卡片
      createComparisonCard(
        'monthly-income-comparison',
        '月度收入',
        formatCurrency(data.monthlyIncome),
        formatCurrency(data.prevMonthlyIncome),
        '上月',
        symbol,
        'trending-up',
        'success',
      ),

      // 年度收入对比卡片
      createComparisonCard(
        'yearly-income-comparison',
        '年度收入',
        formatCurrency(data.yearlyIncome),
        formatCurrency(data.prevYearlyIncome),
        '去年',
        symbol,
        'trending-up',
        'primary',
      ),

      // 月度支出对比卡片
      createComparisonCard(
        'monthly-expense-comparison',
        '月度支出',
        formatCurrency(data.monthlyExpense),
        formatCurrency(data.prevMonthlyExpense),
        '上月',
        symbol,
        'trending-up',
        'success',
      ),

      // 年度支出对比卡片
      createComparisonCard(
        'yearly-expense-comparison',
        '年度支出',
        formatCurrency(data.yearlyExpense),
        formatCurrency(data.prevYearlyExpense),
        '去年',
        symbol,
        'trending-up',
        'primary',
      ),
    ];
  });

  return {
    statCards,
    getCurrencySymbol,
  };
}
