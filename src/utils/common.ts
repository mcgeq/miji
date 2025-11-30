// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           common.ts
// Description:    About Common
// Create   Date:  2025-06-22 20:39:52
// Last Modified:  2025-11-30 20:56:00
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

import { camelCase, lowerFirst, snakeCase } from 'es-toolkit';
import { nth } from 'es-toolkit/compat';
import type { RepeatPeriod } from '@/schema/common';

/**
 * 递归地将对象的键从 snake_case 转换为 camelCase
 * @param obj - 要转换的对象、数组或值
 * @returns 转换后的对象
 *
 * @example
 * toCamelCase({ user_name: 'Alice', created_at: '2025-01-01' })
 * // { userName: 'Alice', createdAt: '2025-01-01' }
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export function toCamelCase<T = any>(obj: any): T {
  if (Array.isArray(obj)) {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    return obj.map(toCamelCase) as any;
  }
  if (obj !== null && typeof obj === 'object') {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const newObj: Record<string, any> = {};
    for (const [key, value] of Object.entries(obj)) {
      // 使用 es-toolkit 的 camelCase 进行转换
      const camelKey = camelCase(key);
      newObj[camelKey] = toCamelCase(value);
    }
    return newObj as T;
  }
  return obj;
}

/**
 * 将字符串从 camelCase 转换为 snake_case
 * @param str - 要转换的字符串
 * @returns snake_case 格式的字符串
 *
 * @example
 * toSnakeCase('userName') // 'user_name'
 * toSnakeCase('createdAt') // 'created_at'
 */
export function toSnakeCase(str: string): string {
  // 使用 es-toolkit 的 snakeCase
  return snakeCase(str);
}

export function buildRepeatPeriod(input: Partial<RepeatPeriod>): RepeatPeriod {
  switch (input.type) {
    case 'Daily':
      return {
        type: 'Daily',
        interval: input.interval ?? 1,
      };
    case 'Weekly':
      return {
        type: 'Weekly',
        interval: input.interval ?? 1,
        daysOfWeek: (input.daysOfWeek ?? []) as (
          | 'Mon'
          | 'Tue'
          | 'Wed'
          | 'Thu'
          | 'Fri'
          | 'Sat'
          | 'Sun'
        )[],
      };
    case 'Monthly':
      return {
        type: 'Monthly',
        interval: input.interval ?? 1,
        day: input.day ?? 1,
      };
    case 'Yearly':
      return {
        type: 'Yearly',
        interval: input.interval ?? 1,
        month: input.month ?? 1,
        day: input.day ?? 1,
      };
    case 'Custom':
      return {
        type: 'Custom',
        description: input.description ?? '',
      };
    default:
      return { type: 'None' };
  }
}

/**
 * 安全地获取数组元素（支持负索引）
 * @param arr - 数组
 * @param index - 索引（支持负数，-1 表示最后一个元素）
 * @param fallback - 默认值
 * @returns 数组元素或默认值
 *
 * @example
 * safeGet([1, 2, 3], 1) // 2
 * safeGet([1, 2, 3], -1) // 3 (最后一个)
 * safeGet([1, 2, 3], 10, 0) // 0 (超出范围返回默认值)
 */
export function safeGet<T>(arr: T[], index: number): T | undefined;
export function safeGet<T>(arr: T[], index: number, fallback: T): T;
export function safeGet<T>(arr: T[], index: number, fallback?: T): T | undefined {
  // 使用 es-toolkit 的 nth，支持负索引
  const value = nth(arr, index);
  return value !== undefined ? value : fallback;
}

const weeklyEmun = {
  Mon: '一',
  Tue: '二',
  Wed: '三',
  Thu: '四',
  Fri: '五',
  Sat: '六',
  Sun: '日',
} as const;
type DayOfWeek = keyof typeof weeklyEmun;

function mapDaysToChinese(days: DayOfWeek[]): string {
  return days.map(day => weeklyEmun[day] || day).join(',');
}

export function getRepeatTypeName(period: RepeatPeriod): string {
  switch (period.type) {
    case 'None':
      return '无周期';
    case 'Daily':
      return period.interval > 1 ? `每${period.interval}天` : '每日';
    case 'Weekly': {
      const daysInChinese = mapDaysToChinese(period.daysOfWeek);
      return period.interval > 1
        ? `每${period.interval}周 (${daysInChinese})`
        : `每周 (${daysInChinese})`;
    }
    case 'Monthly': {
      const day = period.day === 'Last' ? '最后一天' : `第${period.day}天`;
      return period.interval > 1 ? `每${period.interval}月，${day}` : `每月，${day}`;
    }
    case 'Yearly':
      return period.interval > 1
        ? `每${period.interval}年，${period.month}月${period.day}日`
        : `${period.month}月${period.day}日`;
    case 'Custom':
      return period.description;
    default:
      return '无周期';
  }
}

/**
 * 将单词首字母转为小写（其余字符保持原样）
 * @param word 原始单词（如 "CookingIngredients"）
 * @returns 首字母小写后的单词（如 "cookingIngredients"）
 *
 * @example
 * lowercaseFirstLetter('HelloWorld') // 'helloWorld'
 * lowercaseFirstLetter('API') // 'aPI'
 */
export function lowercaseFirstLetter(word: string): string {
  if (word.length === 0) return word;
  // 使用 es-toolkit 的 lowerFirst
  return lowerFirst(word);
}
