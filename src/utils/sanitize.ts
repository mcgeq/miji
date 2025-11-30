/**
 * 字符串清理和转义工具
 *
 * 使用 es-toolkit 优化实现
 */

import { escape as escapeString, unescape as unescapeString } from 'es-toolkit';

/**
 * HTML 转义（使用 es-toolkit 优化）
 * @param str - 要转义的字符串
 * @returns 转义后的字符串
 */
export function escapeHTML(str: string): string {
  return escapeString(str);
}

/**
 * HTML 反转义
 * @param str - 要反转义的字符串
 * @returns 反转义后的字符串
 */
export function unescapeHTML(str: string): string {
  return unescapeString(str);
}

/**
 * 清理用户输入（转义 + 去除首尾空格）
 * @param str - 用户输入
 * @returns 清理后的字符串
 */
export function sanitizeInput(str: string): string {
  return escapeString(str.trim());
}
