/**
 * 数字处理工具函数
 */

import { AMOUNT_CONSTANTS } from '../constants/transactionConstants';

/**
 * 解析金额（字符串或数字转为数字）
 * @param value - 输入值
 * @returns 解析后的数字，失败返回0
 */
export function parseAmount(value: string | number | null | undefined): number {
  if (value === null || value === undefined) return 0;

  const num = typeof value === 'string' ? Number.parseFloat(value) : value;
  return Number.isNaN(num) ? 0 : num;
}

/**
 * 安全的数字格式化
 * @param value - 要格式化的值
 * @param decimals - 小数位数，默认2位
 * @returns 格式化后的字符串
 */
export function safeToFixed(value: string | number | null | undefined, decimals: number = AMOUNT_CONSTANTS.DECIMAL_PLACES): string {
  const numValue = parseAmount(value);
  return numValue.toFixed(decimals);
}

/**
 * 验证金额是否有效
 * @param amount - 金额
 * @returns 是否有效
 */
export function isValidAmount(amount: number): boolean {
  return !Number.isNaN(amount)
    && amount >= AMOUNT_CONSTANTS.MIN_AMOUNT
    && amount <= AMOUNT_CONSTANTS.MAX_AMOUNT;
}

/**
 * 验证金额范围
 * @param amount - 金额
 * @param min - 最小值（可选）
 * @param max - 最大值（可选）
 * @returns 是否在范围内
 */
export function isAmountInRange(amount: number, min?: number, max?: number): boolean {
  if (Number.isNaN(amount)) return false;

  if (min !== undefined && amount < min) return false;
  if (max !== undefined && amount > max) return false;

  return true;
}

/**
 * 验证百分比是否有效
 * @param percentage - 百分比
 * @returns 是否有效
 */
export function isValidPercentage(percentage: number): boolean {
  return !Number.isNaN(percentage) && percentage >= 0 && percentage <= 100;
}

/**
 * 格式化货币显示
 * @param amount - 金额
 * @param currency - 货币符号，默认¥
 * @returns 格式化的货币字符串
 */
export function formatCurrencyAmount(amount: number, currency: string = '¥'): string {
  return `${currency}${safeToFixed(amount)}`;
}
