// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           common.ts
// Description:    About Common
// Create   Date:  2025-06-22 20:39:52
// Last Modified:  2025-07-16 20:21:48
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

import type { RepeatPeriod } from '@/schema/common';

export function toCamelCase<T = any>(obj: any): T {
  if (Array.isArray(obj)) {
    return obj.map(toCamelCase) as any;
  } else if (obj !== null && typeof obj === 'object') {
    const newObj: Record<string, any> = {};
    for (const [key, value] of Object.entries(obj)) {
      const camelKey = key.replace(/_([a-z])/g, (_, char) =>
        char.toUpperCase());
      newObj[camelKey] = toCamelCase(value);
    }
    return newObj as T;
  }
  return obj;
}

export function toSnakeCase(str: string): string {
  return str.replace(/[A-Z]/g, letter => `_${letter.toLowerCase()}`);
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

// 类型重载版本
export function safeGet<T>(arr: T[], index: number): T | undefined;
export function safeGet<T>(arr: T[], index: number, fallback: T): T;
export function safeGet<T>(
  arr: T[],
  index: number,
  fallback?: T,
): T | undefined {
  return arr[index] ?? fallback;
}

export function getRepeatTypeName(period: RepeatPeriod): string {
  switch (period.type) {
    case 'None':
      return '无周期';
    case 'Daily':
      return period.interval > 1 ? `每${period.interval}天` : '每日';
    case 'Weekly':
      return period.interval > 1
        ? `每${period.interval}周 (${period.daysOfWeek.join(',')})`
        : `每周 (${period.daysOfWeek.join(',')})`;
    case 'Monthly': {
      const day = period.day === 'Last' ? '最后一天' : `第${period.day}天`;
      return period.interval > 1
        ? `每${period.interval}月，${day}`
        : `每月，${day}`;
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
 */
export function lowercaseFirstLetter(word: string): string {
  if (word.length === 0) return word; // 空字符串直接返回
  // 首字母转小写，其余字符保持原样
  return word[0].toLowerCase() + word.slice(1);
}
