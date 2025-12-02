// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           date.ts
// Description:    About Date and Time
// Create   Date:  2025-06-28 13:52:19
// Last Modified:  2025-07-18 10:37:51
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

import { format } from 'date-fns';
import { isNaN } from 'es-toolkit/compat';
import type { DateRange } from '@/schema/common';

export class DateUtils {
  /**
   * 获取当前本地时间的ISO格式字符串，可选偏移时间。
   * @param options - 偏移参数（天数、小时、分钟、秒、毫秒
   * @param options.days - 增加的天数（负值表示减少）
   * @param options.hours - 增加的小时数（负值表示减少）
   * @param options.minutes - 增加的分钟数（负值表示减少）
   * @param options.seconds - 增加的秒数（负值表示减少）
   * @param options.milliseconds - 增加的毫秒数（负值表示减少）
   * @returns 格式为 "YYYY-MM-DDTHH:MM:SS.ffffff±HH:MM" 的ISO字符串
   */
  static getLocalISODateTimeWithOffset(options?: {
    days?: number;
    hours?: number;
    minutes?: number;
    seconds?: number;
    milliseconds?: number;
  }): string {
    return DateUtils.generateISOWithOffset(options, () => {});
  }

  /**
   * 获取今天的日期（YYYY-MM-DD 格式）
   * @returns 例如 "2025-04-05"
   */
  static getTodayDate(): string {
    const now = new Date();
    const yyyy = now.getFullYear();
    const mm = String(now.getMonth() + 1).padStart(2, '0');
    const dd = String(now.getDate()).padStart(2, '0');
    return `${yyyy}-${mm}-${dd}`;
  }

  /**
   * 获取当前时间的ISO时间部分（包含微秒）
   * @returns 格式为 "HH:MM:SS.ffffff" 的时间字符串
   */
  static getIsoTime(): string {
    const now = new Date();

    const pad = (n: number, width = 2) => String(n).padStart(width, '0');

    const hours = pad(now.getHours());
    const minutes = pad(now.getMinutes());
    const seconds = pad(now.getSeconds());

    // 精度为微秒（最多 6 位）
    const milliseconds = now.getMilliseconds(); // 0~999
    const micro = String(milliseconds * 1000).padStart(6, '0'); // 转换成微秒字符串

    return `${hours}:${minutes}:${seconds}.${micro}`;
  }

  /**
   * 获取当前日期的Date对象
   * @returns 当前时间的Date实例
   */
  static getCurrentDate(): Date {
    return new Date(this.getLocalISODateTimeWithOffset());
  }

  /**
   * 计算两个日期之间的天数（不包含首尾）
   * 
   * @param startDate - 开始日期（YYYY-MM-DD）
   * @param endDate - 结束日期（YYYY-MM-DD）
   * @returns 天数差（不包含首尾两天）
   * 
   * @example
   * DateUtils.daysBetween('2025-01-01', '2025-01-05'); // 4
   */
  static daysBetween(startDate: string, endDate: string): number {
    const start = new Date(startDate);
    const end = new Date(endDate);
    const diffTime = end.getTime() - start.getTime();
    return Math.ceil(diffTime / 86400000); // 86400000 = 1000 * 60 * 60 * 24
  }

  /**
   * 计算两个日期之间的天数（包含首尾两天）
   * 
   * @param startDate - 开始日期（YYYY-MM-DD 或 ISO 格式）
   * @param endDate - 结束日期（YYYY-MM-DD 或 ISO 格式）
   * @returns 天数差（包含首尾两天），如果日期无效则返回 0
   * 
   * @example
   * // 计算经期持续天数
   * DateUtils.daysBetweenInclusive('2025-01-01', '2025-01-05'); // 5 天
   * DateUtils.daysBetweenInclusive('2025-11-22', '2025-11-28'); // 7 天
   * 
   * @example
   * // 处理无效日期
   * DateUtils.daysBetweenInclusive('', '2025-01-05'); // 0
   * DateUtils.daysBetweenInclusive('2025-01-01', ''); // 0
   * 
   * @performance
   * 优化后的实现，避免重复计算和函数调用
   */
  static daysBetweenInclusive(startDate: string, endDate: string): number {
    // 提前验证，避免无效的 Date 对象创建
    if (!startDate || !endDate) {
      return 0;
    }
    
    // 直接计算，避免调用 daysBetween（减少一次函数调用）
    const start = new Date(startDate);
    const end = new Date(endDate);
    const diffTime = end.getTime() - start.getTime();
    return Math.ceil(diffTime / 86400000) + 1; // 86400000 = 1000 * 60 * 60 * 24
  }

  /**
   * 获取某天的结束时间（23:59:59.999）的ISO格式
   * @param options - 时间偏移参数
   * @param options.days - 增加的天数（负值表示减少）
   * @param options.hours - 增加的小时数（负值表示减少）
   * @param options.minutes - 增加的分钟数（负值表示减少）
   * @param options.seconds - 增加的秒数（负值表示减少）
   * @param options.milliseconds - 增加的毫秒数（负值表示减少）
   * @returns 包含时区偏移的ISO字符串
   */
  static getEndOfTodayISOWithOffset(options?: {
    days?: number;
    hours?: number;
    minutes?: number;
    seconds?: number;
    milliseconds?: number;
  }): string {
    return DateUtils.generateISOWithOffset(options, date => {
      date.setHours(23, 59, 59, 999);
    });
  }

  /**
   * 获取某天的开始时间（00:00:00.000）的ISO格式
   * @param options - 时间偏移配置
   * @param options.days - 增加的天数（负值表示减少）
   * @param options.hours - 增加的小时数（负值表示减少）
   * @param options.minutes - 增加的分钟数（负值表示减少）
   * @param options.seconds - 增加的秒数（负值表示减少）
   * @param options.milliseconds - 增加的毫秒数（负值表示减少）
   * @returns 包含时区偏移的ISO字符串
   */
  static getStartOfTodayISOWithOffset(options?: {
    days?: number;
    hours?: number;
    minutes?: number;
    seconds?: number;
    milliseconds?: number;
  }): string {
    return DateUtils.generateISOWithOffset(options, date => {
      date.setHours(0, 0, 0);
    });
  }

  static toLocalISOFromDateInput(
    dateStr: string,
    endOfDay = false,
    offsetOptions?: {
      days?: number;
      hours?: number;
      minutes?: number;
      seconds?: number;
      milliseconds?: number;
    },
  ): string {
    const [year, month, day] = dateStr.split('-').map(Number);
    const date = new Date(
      year,
      month - 1,
      day,
      endOfDay ? 23 : 0,
      endOfDay ? 59 : 0,
      endOfDay ? 59 : 0,
      endOfDay ? 999 : 0,
    );
    return DateUtils.generateISOWithOffset(offsetOptions, d => {
      d.setTime(date.getTime());
    });
  }

  /**
   * 将日期字符串解析为标准ISO格式
   * @param dt - 日期时间字符串（如 "2025-04-05 22:30"）
   * @returns 标准ISO格式字符串
   */
  static parseToISO(dt: string) {
    // Check if dt is undefined or empty
    if (!dt || typeof dt !== 'string') {
      return this.getLocalISODateTimeWithOffset(); // Fallback to current time if invalid
    }

    // Split ISO-like string into date and time parts
    const [datePart, timePart] = dt.split('T');

    // Parse date parts (yyyy-mm-dd)
    const [yyyy, mm, dd] = datePart.split('-').map(Number);

    // Parse time parts (HH:mm, handle missing seconds)
    const timeComponents = timePart.split(':').map(Number);
    const hh = timeComponents[0] || 0;
    const min = timeComponents[1] || 0;
    const ss = timeComponents[2] || 0; // Default to 0 if seconds are missing

    // Validate parsed numbers
    if (
      Number.isNaN(yyyy) ||
      Number.isNaN(mm) ||
      Number.isNaN(dd) ||
      Number.isNaN(hh) ||
      Number.isNaN(min) ||
      Number.isNaN(ss)
    ) {
      return this.getLocalISODateTimeWithOffset(); // Fallback if any part is invalid
    }

    // 创建 Date 对象基于用户选择的时间
    const date = new Date(Date.UTC(yyyy, mm - 1, dd, hh, min, ss));

    // 毫秒转微秒，补0到6位（默认0，因为用户输入无微秒）
    const micro = '000000';

    // 计算时区偏移，与 getLocalISODateTimeWithOffset 一致
    const offsetMinutes = date.getTimezoneOffset();
    const sign = offsetMinutes <= 0 ? '+' : '-';
    const absOffset = Math.abs(offsetMinutes);
    const offsetHours = String(Math.floor(absOffset / 60)).padStart(2, '0');
    const offsetMins = String(absOffset % 60).padStart(2, '0');
    const offsetStr = `${sign}${offsetHours}:${offsetMins}`;

    return `${yyyy}-${String(mm).padStart(2, '0')}-${String(dd).padStart(2, '0')}T${String(hh).padStart(2, '0')}:${String(min).padStart(2, '0')}:${String(ss).padStart(2, '0')}.${micro}${offsetStr}`;
  }

  /**
   * 格式化ISO时间字符串为可读格式（YYYY-MM-DD HH:mm）
   * @param isoString - ISO格式时间字符串
   * @returns 可读格式时间字符串
   */
  static formatForDisplay(isoString: string) {
    const date = new Date(isoString);
    const yyyy = date.getFullYear();
    const mm = String(date.getMonth() + 1).padStart(2, '0');
    const dd = String(date.getDate()).padStart(2, '0');
    const hh = String(date.getHours()).padStart(2, '0');
    const min = String(date.getMinutes()).padStart(2, '0');
    return `${yyyy}-${mm}-${dd} ${hh}:${min}`;
  }

  /**
   * 验证时间字符串是否包含指定日期和时间
   * @param fullDateTime - 完整ISO时间字符串
   * @param partialDateTime - 部分时间字符串（如 "2025-04-05 22:30"）
   * @returns 是否匹配
   */
  static isDateTimeContaining(
    fullDateTime: string, // 完整 ISO 字符串，比如 2025-06-23T22:30:00.000000+08:00
    partialDateTime: string,
  ): boolean {
    // 解析完整时间，new Date 自动识别 ISO 格式和时区
    const fullDate = new Date(fullDateTime);
    if (Number.isNaN(fullDate.getTime())) return false;

    // 解析简化时间，需要先把空格替换成T并补充秒和时区才能用Date解析
    // 这里先解析年月日和小时分钟，忽略秒和时区
    const [datePart, timePart] = partialDateTime.split(' ');
    if (!datePart || !timePart) return false;

    const [year, month, day] = datePart.split('-').map(Number);
    const [hour, minute] = timePart.split(':').map(Number);

    // 比较两个时间的年月日和时分
    return (
      fullDate.getFullYear() === year &&
      fullDate.getMonth() + 1 === month && // 注意getMonth()从0开始
      fullDate.getDate() === day &&
      fullDate.getHours() === hour &&
      fullDate.getMinutes() === minute
    );
  }

  /**
   * 格式化日期字符串为 YYYY-MM-DD
   * @param dateStr - 日期字符串
   * @returns 格式化后的日期字符串
   */
  static formatDate(dateStr: string) {
    return DateUtils.formatDatePart(new Date(dateStr));
  }

  /**
   * 格式化Date对象为 YYYY-MM-DD
   * @param date - Date对象
   * @returns 格式化后的日期字符串
   */
  static formatDateFromDate(date: Date): string {
    return DateUtils.formatDatePart(date);
  }

  /**
   * 格式化ISO字符串为 "YYYY-MM-DD HH:mm:ss"
   * @param dateStr - ISO格式字符串
   * @returns 格式化后的字符串
   */
  static formatDateTime(dateStr: string) {
    const dt = dateStr.split('T');
    const t = dt[1].split('\.')[0];
    return `${dt[0]} ${t}`;
  }

  static formatTime(dateStr: string) {
    return new Date(dateStr).toLocaleTimeString('zh-CN', {
      hour: '2-digit',
      minute: '2-digit',
      second: '2-digit',
    });
  }

  /**
   * 验证给定字符串是否为合法日期
   * @param dateString - 日期字符串（推荐 ISO 格式，如 "YYYY-MM-DD"）
   * @returns 是否为合法日期
   */
  static isValidDate(dateString: string): boolean {
    const date = new Date(dateString);
    return !Number.isNaN(date.getTime());
  }

  /**
   * 在给定日期上增加指定天数
   * @param dateStr - 初始日期（ISO 格式）
   * @param days - 要增加的天数（负值表示减少）
   * @returns 新日期（ISO 格式）
   */
  static addDays(dateStr: string | null | undefined, days: number): string {
    let baseDate: Date;

    if (dateStr == null) {
      baseDate = new Date();
    } else {
      if (dateStr === '' || isNaN(new Date(dateStr).getTime())) {
        baseDate = new Date();
      } else {
        baseDate = new Date(dateStr);
        if (isNaN(baseDate.getTime())) {
          baseDate = new Date();
        }
      }
    }
    baseDate.setDate(baseDate.getDate() + days);
    return baseDate.toISOString().split('T')[0];
  }

  static getCurrentYearRange(): [string, string] {
    const now = new Date();
    const start = new Date(now.getFullYear(), 0, 1);
    const end = new Date(now.getFullYear() + 1, 0, 1);
    return [DateUtils.formatDatePart(start), DateUtils.formatDatePart(end)];
  }

  static getLastYearRange(): [string, string] {
    const now = new Date();
    const start = new Date(now.getFullYear() - 1, 0, 1);
    const end = new Date(now.getFullYear(), 0, 1);
    return [DateUtils.formatDatePart(start), DateUtils.formatDatePart(end)];
  }

  /**
   * 获取当前月份的日期范围
   */
  static getCurrentMonthRange(): [string, string] {
    const now = new Date();
    const start = new Date(now.getFullYear(), now.getMonth(), 1);
    const end = new Date(now.getFullYear(), now.getMonth() + 1, 1);
    return [DateUtils.formatDatePart(start), DateUtils.formatDatePart(end)];
  }

  /**
   * 获取上个月的日期范围
   */
  static getLastMonthRange(): [string, string] {
    const now = new Date();
    const start = new Date(now.getFullYear(), now.getMonth() - 1, 1);
    const end = new Date(now.getFullYear(), now.getMonth(), 1);
    return [DateUtils.formatDatePart(start), DateUtils.formatDatePart(end)];
  }

  static toBackendDateTimeFromDateOnly(dateStr: string): string {
    // 拼接当前时间
    const now = new Date();
    const hh = String(now.getHours()).padStart(2, '0');
    const mm = String(now.getMinutes()).padStart(2, '0');
    const ss = String(now.getSeconds()).padStart(2, '0');
    const ms = String(now.getMilliseconds()).padStart(3, '0');

    const combined = new Date(`${dateStr}T${hh}:${mm}:${ss}.${ms}`);
    return DateUtils.formatDateToBackend(combined);
  }

  /**
   * 通用方法，用于生成带偏移的 ISO 日期时间字符串
   * @param options - 偏移配置
   * @param options.days - 增加的天数（负值表示减少）
   * @param options.hours - 增加的小时数（负值表示减少）
   * @param options.minutes - 增加的分钟数（负值表示减少）
   * @param options.seconds - 增加的秒数（负值表示减少）
   * @param options.milliseconds - 增加的毫秒数（负值表示减少）
   * @param setTimeFn - 时间设置回调函数
   */
  private static generateISOWithOffset(
    options: {
      days?: number;
      hours?: number;
      minutes?: number;
      seconds?: number;
      milliseconds?: number;
    } = {},
    setTimeFn: (date: Date) => void = () => {},
  ): string {
    let now = new Date();

    // 1. 处理偏移
    if (options) {
      const { days = 0, hours = 0, minutes = 0, seconds = 0, milliseconds = 0 } = options;

      const totalMs =
        days * 24 * 60 * 60 * 1000 +
        hours * 60 * 60 * 1000 +
        minutes * 60 * 1000 +
        seconds * 1000 +
        milliseconds;

      now = new Date(now.getTime() + totalMs);
    }

    // 2. 设置时间（如设置为当天的 00:00:00 或 23:59:59.999）
    if (setTimeFn) {
      setTimeFn(now);
    }

    // 3. 格式化日期、时间、时区偏移
    const datePart = this.formatDatePart(now);
    const timePart = this.formatTimePart(now);
    const timeZone = this.formatTimeZone(now);

    return `${datePart}T${timePart}${timeZone}`;
  }

  /**
   * 格式化日期部分：YYYY-MM-DD
   */
  private static formatDatePart(date: Date): string {
    const yyyy = date.getFullYear();
    const mm = String(date.getMonth() + 1).padStart(2, '0');
    const dd = String(date.getDate()).padStart(2, '0');
    return `${yyyy}-${mm}-${dd}`;
  }

  /**
   * 格式化时间部分：HH:MM:SS.ffffff
   */
  private static formatTimePart(date: Date): string {
    const hh = String(date.getHours()).padStart(2, '0');
    const min = String(date.getMinutes()).padStart(2, '0');
    const ss = String(date.getSeconds()).padStart(2, '0');
    const ms = String(date.getMilliseconds()).padStart(3, '0');
    return `${hh}:${min}:${ss}.${ms}`;
  }

  /**
   * 格式化时区偏移：±HH:MM
   */
  private static formatTimeZone(date: Date): string {
    const offsetMinutes = date.getTimezoneOffset();
    const sign = offsetMinutes <= 0 ? '+' : '-';
    const absOffset = Math.abs(offsetMinutes);
    const offsetHours = String(Math.floor(absOffset / 60)).padStart(2, '0');
    const offsetMins = String(absOffset % 60).padStart(2, '0');
    return `${sign}${offsetHours}:${offsetMins}`;
  }

  static formatDateToBackend(date: Date): string {
    // 格式化到毫秒
    const formatted = format(date, "yyyy-MM-dd'T'HH:mm:ss.SSSxxx");
    // 把 .SSS 变成 .SSSSSS（微秒），补 3 个 0
    return formatted.replace(/(\.\d{3})/, m => `${m}000`);
  }

  /**
   * 格式化日期为 YYYY-MM-DD 格式（仅日期，不包含时间）
   * @param date - 日期对象
   * @returns YYYY-MM-DD 格式的日期字符串
   */
  static formatDateOnly(date: Date): string {
    return format(date, 'yyyy-MM-dd');
  }

  /**
   * 获取指定日期所在月份的第一天
   * @param date - 日期对象
   * @returns 月份第一天的Date对象
   */
  static getStartOfMonth(date: Date): Date {
    return new Date(date.getFullYear(), date.getMonth(), 1);
  }

  /**
   * 获取指定日期所在月份的最后一天
   * @param date - 日期对象
   * @returns 月份最后一天的Date对象
   */
  static getEndOfMonth(date: Date): Date {
    return new Date(date.getFullYear(), date.getMonth() + 1, 0);
  }

  /**
   * 获取指定日期所在周的第一天（周一）
   * @param date - 日期对象
   * @returns 周第一天的Date对象
   */
  static getStartOfWeek(date: Date): Date {
    const day = date.getDay();
    const diff = date.getDate() - day + (day === 0 ? -6 : 1); // 调整到周一
    return new Date(date.setDate(diff));
  }

  /**
   * 获取指定日期所在周的最后一天（周日）
   * @param date - 日期对象
   * @returns 周最后一天的Date对象
   */
  static getEndOfWeek(date: Date): Date {
    const startOfWeek = this.getStartOfWeek(new Date(date));
    return new Date(startOfWeek.getTime() + 6 * 24 * 60 * 60 * 1000);
  }

  /**
   * 获取指定日期所在年份的第一天
   * @param date - 日期对象
   * @returns 年份第一天的Date对象
   */
  static getStartOfYear(date: Date): Date {
    return new Date(date.getFullYear(), 0, 1);
  }

  /**
   * 获取指定日期所在年份的最后一天
   * @param date - 日期对象
   * @returns 年份最后一天的Date对象
   */
  static getEndOfYear(date: Date): Date {
    return new Date(date.getFullYear() + 1, 0, 0);
  }

  /**
   * 获取指定日期所在年份的第几周
   * @param date - 日期对象
   * @returns 周数
   */
  static getWeekOfYear(date: Date): number {
    const startOfYear = new Date(date.getFullYear(), 0, 1);
    const days = Math.floor((date.getTime() - startOfYear.getTime()) / (24 * 60 * 60 * 1000));
    return Math.ceil((days + startOfYear.getDay() + 1) / 7);
  }

  static getCurrentDateRange(): DateRange {
    return {
      start: DateUtils.getStartOfTodayISOWithOffset({ days: -2 }),
      end: DateUtils.getEndOfTodayISOWithOffset(),
    };
  }
}
