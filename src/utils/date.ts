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
    let now = new Date();
    if (options) {
      const {
        days = 0,
        hours = 0,
        minutes = 0,
        seconds = 0,
        milliseconds = 0,
      } = options;

      const totalMs =
        days * 24 * 60 * 60 * 1000 +
        hours * 60 * 60 * 1000 +
        minutes * 60 * 1000 +
        seconds * 1000 +
        milliseconds;
      now = new Date(now.getTime() + totalMs);
    }

    // 获取本地时间各部分
    const yyyy = now.getFullYear();
    const mm = String(now.getMonth() + 1).padStart(2, '0');
    const dd = String(now.getDate()).padStart(2, '0');
    const hh = String(now.getHours()).padStart(2, '0');
    const min = String(now.getMinutes()).padStart(2, '0');
    const ss = String(now.getSeconds()).padStart(2, '0');

    // 毫秒转微秒，补0到6位
    const ms = String(now.getMilliseconds()).padStart(3, '0');
    const micro = `${ms}000`.slice(0, 6);

    // 计算时区偏移
    const offsetMinutes = now.getTimezoneOffset();
    const sign = offsetMinutes <= 0 ? '+' : '-';
    const absOffset = Math.abs(offsetMinutes);
    const offsetHours = String(Math.floor(absOffset / 60)).padStart(2, '0');
    const offsetMins = String(absOffset % 60).padStart(2, '0');
    const offsetStr = `${sign}${offsetHours}:${offsetMins}`;

    return `${yyyy}-${mm}-${dd}T${hh}:${min}:${ss}.${micro}${offsetStr}`;
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
    const l = this.getLocalISODateTimeWithOffset();
    const n = new Date(l);
    return n;
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
    let now = new Date();
    if (options) {
      const {
        days = 0,
        hours = 0,
        minutes = 0,
        seconds = 0,
        milliseconds = 0,
      } = options;

      const totalMs =
        days * 24 * 60 * 60 * 1000 +
        hours * 60 * 60 * 1000 +
        minutes * 60 * 1000 +
        seconds * 1000 +
        milliseconds;
      now = new Date(now.getTime() + totalMs);
    }
    // 设置时间为 23:59:59.999（本地时间）
    now.setHours(23, 59, 59, 999);

    // 构建日期部分
    const yyyy = now.getFullYear();
    const mm = String(now.getMonth() + 1).padStart(2, '0');
    const dd = String(now.getDate()).padStart(2, '0');
    const hh = String(now.getHours()).padStart(2, '0');
    const min = String(now.getMinutes()).padStart(2, '0');
    const ss = String(now.getSeconds()).padStart(2, '0');

    // 毫秒转微秒格式，补足 6 位
    const ms = String(now.getMilliseconds()).padStart(3, '0');
    const micro = `${ms}000`.slice(0, 6);

    // 计算本地时区偏移
    const offsetMinutes = now.getTimezoneOffset();
    const sign = offsetMinutes <= 0 ? '+' : '-';
    const absOffset = Math.abs(offsetMinutes);
    const offsetHours = String(Math.floor(absOffset / 60)).padStart(2, '0');
    const offsetMins = String(absOffset % 60).padStart(2, '0');
    const offsetStr = `${sign}${offsetHours}:${offsetMins}`;

    // 拼接最终字符串
    return `${yyyy}-${mm}-${dd}T${hh}:${min}:${ss}.${micro}${offsetStr}`;
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
    let now = new Date();
    if (options) {
      const {
        days = 0,
        hours = 0,
        minutes = 0,
        seconds = 0,
        milliseconds = 0,
      } = options;

      const totalMs =
        days * 24 * 60 * 60 * 1000 +
        hours * 60 * 60 * 1000 +
        minutes * 60 * 1000 +
        seconds * 1000 +
        milliseconds;
      now = new Date(now.getTime() + totalMs);
    }
    // 设置时间为 23:59:59.999（本地时间）
    now.setHours(0, 0, 0, 0);

    // 构建日期部分
    const yyyy = now.getFullYear();
    const mm = String(now.getMonth() + 1).padStart(2, '0');
    const dd = String(now.getDate()).padStart(2, '0');
    const hh = String(now.getHours()).padStart(2, '0');
    const min = String(now.getMinutes()).padStart(2, '0');
    const ss = String(now.getSeconds()).padStart(2, '0');

    // 毫秒转微秒格式，补足 6 位
    const ms = String(now.getMilliseconds()).padStart(3, '0');
    const micro = `${ms}000`.slice(0, 6);

    // 计算本地时区偏移
    const offsetMinutes = now.getTimezoneOffset();
    const sign = offsetMinutes <= 0 ? '+' : '-';
    const absOffset = Math.abs(offsetMinutes);
    const offsetHours = String(Math.floor(absOffset / 60)).padStart(2, '0');
    const offsetMins = String(absOffset % 60).padStart(2, '0');
    const offsetStr = `${sign}${offsetHours}:${offsetMins}`;

    // 拼接最终字符串
    return `${yyyy}-${mm}-${dd}T${hh}:${min}:${ss}.${micro}${offsetStr}`;
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
    const date = new Date(dateStr);
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0'); // 月份从0开始
    const day = String(date.getDate()).padStart(2, '0');
    return `${year}-${month}-${day}`;
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
  static addDays(dateStr: string, days: number): string {
    const date = new Date(dateStr);
    date.setDate(date.getDate() + days);
    return date.toISOString().split('T')[0]; // 返回 YYYY-MM-DD 格式
  }
}

export function getLocalISODateTimeWithOffset(options?: {
  days?: number;
  hours?: number;
  minutes?: number;
  seconds?: number;
  milliseconds?: number;
}): string {
  let now = new Date();
  if (options) {
    const {
      days = 0,
      hours = 0,
      minutes = 0,
      seconds = 0,
      milliseconds = 0,
    } = options;

    const totalMs =
      days * 24 * 60 * 60 * 1000 +
      hours * 60 * 60 * 1000 +
      minutes * 60 * 1000 +
      seconds * 1000 +
      milliseconds;
    now = new Date(now.getTime() + totalMs);
  }

  // 获取本地时间各部分
  const yyyy = now.getFullYear();
  const mm = String(now.getMonth() + 1).padStart(2, '0');
  const dd = String(now.getDate()).padStart(2, '0');
  const hh = String(now.getHours()).padStart(2, '0');
  const min = String(now.getMinutes()).padStart(2, '0');
  const ss = String(now.getSeconds()).padStart(2, '0');

  // 毫秒转微秒，补0到6位
  const ms = String(now.getMilliseconds()).padStart(3, '0');
  const micro = `${ms}000`.slice(0, 6);

  // 计算时区偏移
  const offsetMinutes = now.getTimezoneOffset();
  const sign = offsetMinutes <= 0 ? '+' : '-';
  const absOffset = Math.abs(offsetMinutes);
  const offsetHours = String(Math.floor(absOffset / 60)).padStart(2, '0');
  const offsetMins = String(absOffset % 60).padStart(2, '0');
  const offsetStr = `${sign}${offsetHours}:${offsetMins}`;

  return `${yyyy}-${mm}-${dd}T${hh}:${min}:${ss}.${micro}${offsetStr}`;
}

export function getCurrentDate() {
  const l = getLocalISODateTimeWithOffset();
  const n = new Date(l);
  return n;
}

export function formatDate(dateStr: string) {
  const date = new Date(dateStr);
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0'); // 月份从0开始
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

/**
 * 验证给定字符串是否为合法日期
 * @param dateString - 日期字符串（推荐 ISO 格式，如 "YYYY-MM-DD"）
 * @returns 是否为合法日期
 */
export function isValidDate(dateString: string): boolean {
  const date = new Date(dateString);
  return !Number.isNaN(date.getTime());
}

/**
 * 在给定日期上增加指定天数
 * @param dateStr - 初始日期（ISO 格式）
 * @param days - 要增加的天数（负值表示减少）
 * @returns 新日期（ISO 格式）
 */
export function addDays(dateStr: string, days: number): string {
  const date = new Date(dateStr);
  date.setDate(date.getDate() + days);
  return date.toISOString().split('T')[0]; // 返回 YYYY-MM-DD 格式
}
