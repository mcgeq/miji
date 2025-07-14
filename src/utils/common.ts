// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           common.ts
// Description:    About Common
// Create   Date:  2025-06-22 20:39:52
// Last Modified:  2025-07-15 00:08:27
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

import { RepeatPeriod } from '@/schema/common';

export function toCamelCase<T = any>(obj: any): T {
  if (Array.isArray(obj)) {
    return obj.map(toCamelCase) as any;
  } else if (obj !== null && typeof obj === 'object') {
    const newObj: Record<string, any> = {};
    for (const [key, value] of Object.entries(obj)) {
      const camelKey = key.replace(/_([a-z])/g, (_, char) =>
        char.toUpperCase(),
      );
      newObj[camelKey] = toCamelCase(value);
    }
    return newObj as T;
  }
  return obj;
}

export const toSnakeCase = (str: string): string =>
  str.replace(/[A-Z]/g, (letter) => `_${letter.toLowerCase()}`);

export const buildRepeatPeriod = (
  input: Partial<RepeatPeriod>,
): RepeatPeriod => {
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
};

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
