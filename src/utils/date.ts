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

    const totalMs
      = days * 24 * 60 * 60 * 1000
        + hours * 60 * 60 * 1000
        + minutes * 60 * 1000
        + seconds * 1000
        + milliseconds;
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

export function getTodayDate(): string {
  const now = new Date();
  const yyyy = now.getFullYear();
  const mm = String(now.getMonth() + 1).padStart(2, '0');
  const dd = String(now.getDate()).padStart(2, '0');
  return `${yyyy}-${mm}-${dd}`;
}

export function getIsoTime(): string {
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

export function getCurrentDate() {
  const l = getLocalISODateTimeWithOffset();
  const n = new Date(l);
  return n;
}

export function getEndOfTodayISOWithOffset(options?: {
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

    const totalMs
      = days * 24 * 60 * 60 * 1000
        + hours * 60 * 60 * 1000
        + minutes * 60 * 1000
        + seconds * 1000
        + milliseconds;
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

export function getStartOfTodayISOWithOffset(options?: {
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

    const totalMs
      = days * 24 * 60 * 60 * 1000
        + hours * 60 * 60 * 1000
        + minutes * 60 * 1000
        + seconds * 1000
        + milliseconds;
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

export function parseToISO(dt: string) {
  // Check if dt is undefined or empty
  if (!dt || typeof dt !== 'string') {
    return getLocalISODateTimeWithOffset(); // Fallback to current time if invalid
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
    Number.isNaN(yyyy)
    || Number.isNaN(mm)
    || Number.isNaN(dd)
    || Number.isNaN(hh)
    || Number.isNaN(min)
    || Number.isNaN(ss)
  ) {
    return getLocalISODateTimeWithOffset(); // Fallback if any part is invalid
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

/// 解析todo.dueAt为yyyy-MM-dd HH:mm
export function formatForDisplay(isoString: string) {
  const date = new Date(isoString);
  const yyyy = date.getFullYear();
  const mm = String(date.getMonth() + 1).padStart(2, '0');
  const dd = String(date.getDate()).padStart(2, '0');
  const hh = String(date.getHours()).padStart(2, '0');
  const min = String(date.getMinutes()).padStart(2, '0');
  return `${yyyy}-${mm}-${dd} ${hh}:${min}`;
}

export function isDateTimeContaining(
  fullDateTime: string, // 完整 ISO 字符串，比如 2025-06-23T22:30:00.000000+08:00
  partialDateTime: string,
): boolean {
  // 解析完整时间，new Date 自动识别 ISO 格式和时区
  const fullDate = new Date(fullDateTime);
  if (Number.isNaN(fullDate.getTime()))
    return false;

  // 解析简化时间，需要先把空格替换成T并补充秒和时区才能用Date解析
  // 这里先解析年月日和小时分钟，忽略秒和时区
  const [datePart, timePart] = partialDateTime.split(' ');
  if (!datePart || !timePart)
    return false;

  const [year, month, day] = datePart.split('-').map(Number);
  const [hour, minute] = timePart.split(':').map(Number);

  // 比较两个时间的年月日和时分
  return (
    fullDate.getFullYear() === year
    && fullDate.getMonth() + 1 === month // 注意getMonth()从0开始
    && fullDate.getDate() === day
    && fullDate.getHours() === hour
    && fullDate.getMinutes() === minute
  );
}

export function formatDate(dateStr: string) {
  const date = new Date(dateStr);
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0'); // 月份从0开始
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

export function formatDateTime(dateStr: string) {
  const dt = dateStr.split('T');
  const t = dt[1].split('\.')[0];
  return `${dt[0]} ${t}`;
}
