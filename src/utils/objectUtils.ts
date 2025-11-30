/**
 * 对象工具函数
 * 基于 es-toolkit 提供常用的对象操作
 *
 * @see https://es-toolkit.slash.page/
 */

import { cloneDeep, isEqual, mapKeys, mapValues, merge, omit, pick } from 'es-toolkit';
import { isEmpty } from 'es-toolkit/compat';

// ==================== 深拷贝 ====================

/**
 * 深拷贝对象或数组
 * @param value - 要拷贝的值
 * @returns 深拷贝后的新对象
 *
 * @example
 * const original = { a: 1, b: { c: 2 } };
 * const copied = deepClone(original);
 * copied.b.c = 3;
 * console.log(original.b.c); // 2
 */
export function deepClone<T>(value: T): T {
  return cloneDeep(value);
}

// ==================== 对象合并 ====================

/**
 * 深度合并多个对象
 * @param target - 目标对象
 * @param sources - 源对象数组
 * @returns 合并后的对象
 *
 * @example
 * const defaults = { a: 1, b: { c: 2 } };
 * const config = { b: { d: 3 } };
 * const result = deepMerge(defaults, config);
 * // { a: 1, b: { c: 2, d: 3 } }
 */
export function deepMerge<T extends object>(...sources: Partial<T>[]): T {
  if (sources.length === 0) return {} as T;
  if (sources.length === 1) return sources[0] as T;

  return sources.reduce((acc, source) => merge(acc, source), {} as T) as T;
}

// ==================== 字段选择 ====================

/**
 * 从对象中选择指定字段
 * @param obj - 源对象
 * @param keys - 要选择的键数组
 * @returns 只包含指定字段的新对象
 *
 * @example
 * const user = { id: 1, name: 'Alice', password: '123', email: 'alice@example.com' };
 * const publicUser = pickFields(user, ['id', 'name', 'email']);
 * // { id: 1, name: 'Alice', email: 'alice@example.com' }
 */
export function pickFields<T extends object, K extends keyof T>(obj: T, keys: K[]): Pick<T, K> {
  return pick(obj, keys);
}

/**
 * 从对象中排除指定字段
 * @param obj - 源对象
 * @param keys - 要排除的键数组
 * @returns 不包含指定字段的新对象
 *
 * @example
 * const user = { id: 1, name: 'Alice', password: '123', email: 'alice@example.com' };
 * const publicUser = omitFields(user, ['password']);
 * // { id: 1, name: 'Alice', email: 'alice@example.com' }
 */
export function omitFields<T extends object, K extends keyof T>(obj: T, keys: K[]): Omit<T, K> {
  return omit(obj, keys);
}

// ==================== 键值转换 ====================

/**
 * 转换对象的所有键
 * @param obj - 源对象
 * @param transformer - 键转换函数
 * @returns 键被转换后的新对象
 *
 * @example
 * const obj = { first_name: 'John', last_name: 'Doe' };
 * const camelObj = transformKeys(obj, (key) => camelCase(key));
 * // { firstName: 'John', lastName: 'Doe' }
 */
export function transformKeys<T extends object>(
  obj: T,
  transformer: (key: string) => string,
): Record<string, any> {
  return mapKeys(obj, (_, key) => transformer(String(key)));
}

/**
 * 转换对象的所有值
 * @param obj - 源对象
 * @param transformer - 值转换函数
 * @returns 值被转换后的新对象
 *
 * @example
 * const obj = { a: 1, b: 2, c: 3 };
 * const doubled = transformValues(obj, (val) => val * 2);
 * // { a: 2, b: 4, c: 6 }
 */
export function transformValues<T extends object, R>(
  obj: T,
  transformer: (value: any, key: string) => R,
): Record<keyof T, R> {
  return mapValues(obj, transformer as any) as Record<keyof T, R>;
}

// ==================== 对象比较 ====================

/**
 * 深度比较两个值是否相等
 * @param a - 第一个值
 * @param b - 第二个值
 * @returns 是否相等
 *
 * @example
 * deepEqual({ a: 1, b: { c: 2 } }, { a: 1, b: { c: 2 } }); // true
 * deepEqual([1, 2, 3], [1, 2, 3]); // true
 */
export function deepEqual(a: any, b: any): boolean {
  return isEqual(a, b);
}

/**
 * 检查值是否为空
 * @param value - 要检查的值
 * @returns 是否为空
 *
 * @example
 * isEmptyValue({}); // true
 * isEmptyValue([]); // true
 * isEmptyValue(''); // true
 * isEmptyValue(null); // true
 * isEmptyValue(undefined); // true
 * isEmptyValue({ a: 1 }); // false
 */
export function isEmptyValue(value: any): boolean {
  return isEmpty(value);
}

// ==================== 对象差异 ====================

/**
 * 获取两个对象之间的差异字段
 * @param oldObj - 旧对象
 * @param newObj - 新对象
 * @returns 包含差异字段的对象
 *
 * @example
 * const old = { a: 1, b: 2, c: 3 };
 * const updated = { a: 1, b: 5, d: 4 };
 * const changes = getObjectDiff(old, updated);
 * // { b: 5, d: 4 }
 */
export function getObjectDiff<T extends object>(oldObj: T, newObj: Partial<T>): Partial<T> {
  const diff: Partial<T> = {};

  for (const key in newObj) {
    if (Object.hasOwn(newObj, key)) {
      const oldValue = oldObj[key];
      const newValue = newObj[key];

      if (!isEqual(oldValue, newValue)) {
        diff[key] = newValue;
      }
    }
  }

  return diff;
}

// ==================== 对象扁平化 ====================

/**
 * 扁平化嵌套对象
 * @param obj - 嵌套对象
 * @param prefix - 键前缀
 * @returns 扁平化后的对象
 *
 * @example
 * const nested = { a: 1, b: { c: 2, d: { e: 3 } } };
 * const flat = flattenObject(nested);
 * // { a: 1, 'b.c': 2, 'b.d.e': 3 }
 */
export function flattenObject(obj: Record<string, any>, prefix = ''): Record<string, any> {
  const result: Record<string, any> = {};

  for (const key in obj) {
    if (Object.hasOwn(obj, key)) {
      const value = obj[key];
      const newKey = prefix ? `${prefix}.${key}` : key;

      if (value && typeof value === 'object' && !Array.isArray(value)) {
        Object.assign(result, flattenObject(value, newKey));
      } else {
        result[newKey] = value;
      }
    }
  }

  return result;
}

/**
 * 反扁平化对象
 * @param obj - 扁平化的对象
 * @returns 嵌套对象
 *
 * @example
 * const flat = { a: 1, 'b.c': 2, 'b.d.e': 3 };
 * const nested = unflattenObject(flat);
 * // { a: 1, b: { c: 2, d: { e: 3 } } }
 */
export function unflattenObject(obj: Record<string, any>): Record<string, any> {
  const result: Record<string, any> = {};

  for (const key in obj) {
    if (Object.hasOwn(obj, key)) {
      const keys = key.split('.');
      let current = result;

      for (let i = 0; i < keys.length - 1; i++) {
        const k = keys[i];
        if (!current[k]) {
          current[k] = {};
        }
        current = current[k];
      }

      current[keys[keys.length - 1]] = obj[key];
    }
  }

  return result;
}

// ==================== 类型安全的更新 ====================

/**
 * 安全地更新对象，只允许更新已存在的键
 * @param target - 目标对象
 * @param updates - 更新内容
 * @returns 更新后的新对象
 *
 * @example
 * const user = { id: 1, name: 'Alice', email: 'alice@example.com' };
 * const updated = safeUpdate(user, { name: 'Bob' });
 * // { id: 1, name: 'Bob', email: 'alice@example.com' }
 */
export function safeUpdate<T extends object>(target: T, updates: Partial<T>): T {
  const result = cloneDeep(target);

  for (const key in updates) {
    if (Object.hasOwn(target, key)) {
      result[key] = updates[key]!;
    }
  }

  return result;
}

// ==================== 导出所有 es-toolkit 对象工具 ====================

export {
  // es-toolkit 原生导出
  cloneDeep,
  merge,
  omit,
  pick,
  mapKeys,
  mapValues,
  isEqual,
  isEmpty,
};
