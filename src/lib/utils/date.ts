export function getLocalISODateTimeWithOffset(): string {
  const now = new Date();

  // 获取本地时间各部分
  const yyyy = now.getFullYear();
  const mm = String(now.getMonth() + 1).padStart(2, '0');
  const dd = String(now.getDate()).padStart(2, '0');
  const hh = String(now.getHours()).padStart(2, '0');
  const min = String(now.getMinutes()).padStart(2, '0');
  const ss = String(now.getSeconds()).padStart(2, '0');

  // 毫秒转微秒，补0到6位
  const ms = String(now.getMilliseconds()).padStart(3, '0');
  const micro = (ms + '000').slice(0, 6);

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

export function getEndOfTodayISOWithOffset(): string {
  const now = new Date();

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
  const micro = (ms + '000').slice(0, 6);

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
