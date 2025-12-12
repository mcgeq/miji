/**
 * 货币工具（向后兼容）
 *
 * @deprecated 请使用 ./currency 中的函数
 * 实际功能已迁移到 currency.ts
 */

export {
  type CurrencyFormatOptions,
  formatCNY,
  formatCurrency,
  formatLocalCurrency,
  formatUSD,
  getLocalCurrencyInfo,
} from './currency';

/**
 * @deprecated 使用 formatLocalCurrency 替代
 *
 * 为了向后兼容，formatCurrency 现在默认使用 locale 格式
 * 如果需要符号格式，请使用 formatCNY 或 formatCurrency({ style: 'symbol' })
 */
