/**
 * 表单处理工具函数
 */

import { parseAmount } from './numberUtils';

/**
 * 处理金额输入事件
 * @param event - 输入事件
 * @returns 解析后的金额
 */
export function handleAmountInput(event: Event): number {
  const input = event.target as HTMLInputElement;
  const value = input.value;

  if (value === '') {
    return 0;
  }

  const numValue = parseAmount(value);
  return numValue;
}

/**
 * 格式化输入框的数字显示
 * @param value - 输入值
 * @returns 格式化后的字符串
 */
export function formatInputNumber(value: number | string | null | undefined): string {
  if (value === null || value === undefined || value === '') {
    return '';
  }

  const num = parseAmount(value);
  return num.toString();
}
