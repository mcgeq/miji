/**
 * 重复周期业务逻辑
 *
 * 处理账单、提醒等功能的重复周期
 * 从 common.ts 中提取的业务相关功能
 */

import type { RepeatPeriod } from '@/schema/common';

/**
 * 构建完整的重复周期对象
 *
 * @param input - 部分重复周期数据
 * @returns 完整的重复周期对象
 *
 * @example
 * buildRepeatPeriod({ type: 'Daily', interval: 2 })
 * // { type: 'Daily', interval: 2 }
 *
 * @example
 * buildRepeatPeriod({ type: 'Weekly', daysOfWeek: ['Mon', 'Wed'] })
 * // { type: 'Weekly', interval: 1, daysOfWeek: ['Mon', 'Wed'] }
 */
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
 * 星期映射（英文 -> 中文）
 */
const weeklyEnum = {
  Mon: '一',
  Tue: '二',
  Wed: '三',
  Thu: '四',
  Fri: '五',
  Sat: '六',
  Sun: '日',
} as const;

type DayOfWeek = keyof typeof weeklyEnum;

/**
 * 将星期数组转换为中文
 *
 * @param days - 星期数组
 * @returns 中文星期字符串（逗号分隔）
 *
 * @example
 * mapDaysToChinese(['Mon', 'Wed', 'Fri'])
 * // '一,三,五'
 */
function mapDaysToChinese(days: DayOfWeek[]): string {
  return days.map(day => weeklyEnum[day] || day).join(',');
}

/**
 * 获取重复周期的中文描述
 *
 * @param period - 重复周期对象
 * @returns 中文描述字符串
 *
 * @example
 * getRepeatTypeName({ type: 'Daily', interval: 1 })
 * // '每日'
 *
 * @example
 * getRepeatTypeName({ type: 'Weekly', interval: 2, daysOfWeek: ['Mon', 'Wed'] })
 * // '每2周 (一,三)'
 *
 * @example
 * getRepeatTypeName({ type: 'Monthly', interval: 1, day: 15 })
 * // '每月，第15天'
 */
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
