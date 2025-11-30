// 类型定义
export interface CardData {
  id: string;
  title: string;
  value: string;
  currency?: string;
  icon?: string;
  color?: 'primary' | 'success' | 'danger' | 'warning' | 'info';
  loading?: boolean;
  subtitle?: string;
  trend?: string;
  trendType?: 'up' | 'down' | 'neutral';
  /** 比较值，用于显示对比数据（如上月、去年数据） */
  compareValue?: string;
  /** 比较值的标签（如"上月"、"去年"） */
  compareLabel?: string;
  /** 变化金额 */
  changeAmount?: string;
  /** 变化百分比 */
  changePercentage?: string;
  /** 变化方向，自动根据数值计算或手动设置 */
  changeType?: 'increase' | 'decrease' | 'unchanged';
  /** 是否显示对比模式 */
  showComparison?: boolean;
  /** 额外的统计信息 */
  extraStats?: Array<{
    label: string;
    value: string;
    color?: 'primary' | 'success' | 'danger' | 'warning' | 'info';
  }>;
}

export function createComparisonCard(
  id: string,
  title: string,
  currentValue: string,
  compareValue: string,
  compareLabel: string,
  currency?: string,
  icon?: string,
  color?: CardData['color'],
): CardData {
  const current = Number.parseFloat(currentValue.replace(/[^\d.-]/g, ''));
  const compare = Number.parseFloat(compareValue.replace(/[^\d.-]/g, ''));
  const change = current - compare;
  const changePercentage = compare !== 0 ? ((change / compare) * 100).toFixed(1) : '0';

  return {
    id,
    title,
    value: currentValue,
    currency,
    icon,
    color,
    compareValue,
    compareLabel,
    changeAmount: Math.abs(change).toLocaleString(),
    changePercentage: `${changePercentage}%`,
    changeType: change > 0 ? 'increase' : change < 0 ? 'decrease' : 'unchanged',
    showComparison: true,
  };
}
