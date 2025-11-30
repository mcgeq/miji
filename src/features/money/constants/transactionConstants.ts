/**
 * 交易相关常量定义
 */

// 分期相关常量
export const INSTALLMENT_CONSTANTS = {
  DEFAULT_PERIODS: 12,
  MIN_PERIODS: 2,
  MAX_PERIODS: 60,
  DEFAULT_FIRST_DUE_OFFSET_DAYS: 30,
} as const;

// 金额相关常量
export const AMOUNT_CONSTANTS = {
  MIN_AMOUNT: 0.01,
  MAX_AMOUNT: 999999999.99,
  DECIMAL_PLACES: 2,
} as const;

// 百分比相关常量
export const PERCENTAGE_CONSTANTS = {
  MIN: 0,
  MAX: 100,
  DEFAULT_EQUAL_SPLIT: (memberCount: number) => Number((100 / memberCount).toFixed(2)),
} as const;

// 分期状态
export enum InstallmentStatus {
  PENDING = 'PENDING',
  PAID = 'PAID',
  OVERDUE = 'OVERDUE',
}

// 收入类别白名单
export const INCOME_ALLOWED_CATEGORIES = ['Salary', 'Investment', 'Savings', 'Gift'] as const;

// 收入类别类型
export type IncomeAllowedCategory = (typeof INCOME_ALLOWED_CATEGORIES)[number];

// 转账类别
export const TRANSFER_CATEGORY = 'Transfer' as const;
