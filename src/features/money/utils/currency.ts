/**
 * 货币格式化工具
 * 
 * 统一的货币格式化函数，合并了：
 * - money.ts::formatCurrency
 * - numberUtils.ts::formatCurrencyAmount
 */

import { CURRENCY_CNY } from '@/constants/moneyConst';
import { MoneyDb } from '@/services/money/money';
import { useLocaleStore } from '@/stores/locales';
import { parseAmount } from './numberUtils';
import type { Currency } from '@/schema/common';

/**
 * 获取当前地区代码
 */
function getLocale(): string {
  return useLocaleStore().getCurrentLocale();
}

/**
 * 货币格式化选项
 */
export interface CurrencyFormatOptions {
  /** 货币符号（如 ¥, $, €） */
  symbol?: string;
  /** 地区代码（如 zh-CN, en-US） */
  locale?: string;
  /** 小数位数，默认 2 */
  decimals?: number;
  /** 是否显示货币符号，默认 true */
  showSymbol?: boolean;
  /** 格式化风格：'symbol' | 'locale' */
  style?: 'symbol' | 'locale';
}

/**
 * 统一的货币格式化函数
 * 
 * @param amount - 金额（数字或字符串）
 * @param options - 格式化选项
 * @returns 格式化后的货币字符串
 * 
 * @example
 * // 简单格式：¥123.45
 * formatCurrency(123.45, { symbol: '¥' });
 * 
 * @example
 * // 国际化格式：123.45
 * formatCurrency(123.45, { style: 'locale', locale: 'zh-CN' });
 * 
 * @example
 * // 无符号：123.45
 * formatCurrency(123.45, { showSymbol: false });
 */
export function formatCurrency(
  amount: string | number,
  options: CurrencyFormatOptions = {}
): string {
  const {
    symbol = '¥',
    locale = getLocale(),
    decimals = 2,
    showSymbol = true,
    style = 'locale', // 默认使用 locale 格式以保持向后兼容
  } = options;

  const num = parseAmount(amount);

  // 样式 1：简单符号格式 ¥123.45
  if (style === 'symbol') {
    const formatted = num.toFixed(decimals);
    return showSymbol ? `${symbol}${formatted}` : formatted;
  }

  // 样式 2：国际化格式 123.45
  return num.toLocaleString(locale, {
    minimumFractionDigits: decimals,
    maximumFractionDigits: decimals,
  });
}

/**
 * 格式化为本地货币（使用 toLocaleString）
 * 
 * @param amount - 金额
 * @param locale - 可选的地区代码
 * @returns 格式化的字符串
 * 
 * @example
 * formatLocalCurrency(123.45); // "123.45"（使用当前地区格式）
 * formatLocalCurrency(123.45, 'en-US'); // "123.45"（美式格式）
 */
export function formatLocalCurrency(amount: string | number, locale?: string): string {
  return formatCurrency(amount, {
    style: 'locale',
    locale: locale || getLocale(),
    showSymbol: false,
  });
}

/**
 * 快捷方法：格式化为人民币
 * 
 * @param amount - 金额
 * @returns ¥xxx.xx 格式
 * 
 * @example
 * formatCNY(123.45); // "¥123.45"
 */
export function formatCNY(amount: string | number): string {
  return formatCurrency(amount, {
    symbol: '¥',
    decimals: 2,
    style: 'symbol',
  });
}

/**
 * 快捷方法：格式化为美元
 * 
 * @param amount - 金额
 * @returns $xxx.xx 格式
 * 
 * @example
 * formatUSD(123.45); // "$123.45"
 */
export function formatUSD(amount: string | number): string {
  return formatCurrency(amount, {
    symbol: '$',
    decimals: 2,
    style: 'symbol',
  });
}

/**
 * 获取本地货币信息
 * 
 * @returns 当前地区的货币信息
 */
export async function getLocalCurrencyInfo(): Promise<Currency> {
  const locale = getLocale();
  const currencies: Currency[] = await MoneyDb.listCurrencies();
  const localCurrency = currencies.find(v => v.locale === locale);
  return localCurrency ?? CURRENCY_CNY;
}
