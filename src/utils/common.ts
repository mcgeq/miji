// -----------------------------------------------------------------------------
//    Copyright (C) 2025 mcge. All rights reserved.
// Author:         mcge
// Email:          <mcgeq@outlook.com>
// File:           common.ts
// Description:    Common utilities (legacy exports)
// Create   Date:  2025-06-22 20:39:52
// Last Modified:  2025-11-30 21:57:00
// Modified   By:  mcgeq <mcgeq@outlook.com>
// -----------------------------------------------------------------------------

/**
 * 通用工具函数（向后兼容）
 *
 * 注意：大部分功能已重构到专门的模块：
 * - 字符串转换 → @/utils/string
 * - 重复周期 → @/utils/business/repeat
 *
 * 这个文件保留向后兼容的导出
 */

import { nth } from 'es-toolkit/compat';

// ==================== 重新导出（向后兼容） ====================

/**
 * @deprecated 请使用 @/utils/business/repeat 中的 buildRepeatPeriod
 */
/**
 * @deprecated 请使用 @/utils/business/repeat 中的 getRepeatTypeName
 */
export { buildRepeatPeriod, getRepeatTypeName } from './business/repeat';
/**
 * @deprecated 请使用 @/utils/string 中的 toCamelCase
 */
/**
 * @deprecated 请使用 @/utils/string 中的 toSnakeCase
 */
/**
 * @deprecated 请使用 @/utils/string 中的 lowercaseFirstLetter
 */
export { lowercaseFirstLetter, toCamelCase, toSnakeCase } from './string';

// ==================== 通用工具函数 ====================

/**
 * 安全地获取数组元素（支持负索引）
 *
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
