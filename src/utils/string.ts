/**
 * 字符串转换工具
 *
 * 基于 es-toolkit 的字符串操作函数
 * 从 common.ts 中提取的字符串相关功能
 */

import { camelCase, lowerFirst, snakeCase } from 'es-toolkit';

/**
 * 递归地将对象的键从 snake_case 转换为 camelCase
 *
 * @param obj - 要转换的对象、数组或值
 * @returns 转换后的对象
 *
 * @example
 * toCamelCase({ user_name: 'Alice', created_at: '2025-01-01' })
 * // { userName: 'Alice', createdAt: '2025-01-01' }
 *
 * @example
 * // 支持嵌套对象
 * toCamelCase({ user_info: { first_name: 'John' } })
 * // { userInfo: { firstName: 'John' } }
 *
 * @example
 * // 支持数组
 * toCamelCase([{ user_name: 'Alice' }, { user_name: 'Bob' }])
 * // [{ userName: 'Alice' }, { userName: 'Bob' }]
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export function toCamelCase<T = any>(obj: any): T {
  if (Array.isArray(obj)) {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    return obj.map(toCamelCase) as any;
  }
  if (obj !== null && typeof obj === 'object') {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const newObj: Record<string, any> = {};
    for (const [key, value] of Object.entries(obj)) {
      // 使用 es-toolkit 的 camelCase 进行转换
      const camelKey = camelCase(key);
      newObj[camelKey] = toCamelCase(value);
    }
    return newObj as T;
  }
  return obj;
}

/**
 * 将字符串从 camelCase 转换为 snake_case
 *
 * @param str - 要转换的字符串
 * @returns snake_case 格式的字符串
 *
 * @example
 * toSnakeCase('userName') // 'user_name'
 * toSnakeCase('createdAt') // 'created_at'
 * toSnakeCase('HTTPRequest') // 'http_request'
 */
export function toSnakeCase(str: string): string {
  return snakeCase(str);
}

/**
 * 将单词首字母转为小写（其余字符保持原样）
 *
 * @param word - 原始单词（如 "CookingIngredients"）
 * @returns 首字母小写后的单词（如 "cookingIngredients"）
 *
 * @example
 * lowercaseFirstLetter('HelloWorld') // 'helloWorld'
 * lowercaseFirstLetter('API') // 'aPI'
 * lowercaseFirstLetter('') // ''
 */
export function lowercaseFirstLetter(word: string): string {
  if (word.length === 0) return word;
  return lowerFirst(word);
}

/**
 * 递归地将对象的键从 camelCase 转换为 snake_case
 *
 * @param obj - 要转换的对象、数组或值
 * @returns 转换后的对象
 *
 * @example
 * toSnakeCaseObject({ userName: 'Alice', createdAt: '2025-01-01' })
 * // { user_name: 'Alice', created_at: '2025-01-01' }
 */
// eslint-disable-next-line @typescript-eslint/no-explicit-any
export function toSnakeCaseObject<T = any>(obj: any): T {
  if (Array.isArray(obj)) {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    return obj.map(toSnakeCaseObject) as any;
  }
  if (obj !== null && typeof obj === 'object') {
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    const newObj: Record<string, any> = {};
    for (const [key, value] of Object.entries(obj)) {
      const snakeKey = snakeCase(key);
      newObj[snakeKey] = toSnakeCaseObject(value);
    }
    return newObj as T;
  }
  return obj;
}
