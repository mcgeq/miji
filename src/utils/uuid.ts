export function uuid(len: number): string {
  const now = new Date();

  // 拼接时间字符串 yyyyMMddHHmmss + 毫秒 + 6位伪纳秒随机数
  const y = now.getFullYear().toString();
  const M = pad(now.getMonth() + 1);
  const d = pad(now.getDate());
  const H = pad(now.getHours());
  const m = pad(now.getMinutes());
  const s = pad(now.getSeconds());
  const ms = now.getMilliseconds().toString().padStart(3, '0');

  // 伪纳秒随机6位数字
  const nano = Math.floor(Math.random() * 1_000_000)
    .toString()
    .padStart(6, '0');

  let fmt = y + M + d + H + m + s + ms + nano;

  // 长度不够用随机数字补齐
  while (fmt.length < len) {
    fmt += Math.floor(Math.random() * 10).toString();
  }

  return fmt.substring(0, len);
}

function pad(n: number) {
  return n < 10 ? '0' + n : n.toString();
}
