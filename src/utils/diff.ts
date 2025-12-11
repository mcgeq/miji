/**
 * 深度差异比较工具
 *
 * 基于 es-toolkit 优化的深度对象比较实现
 * 主要用于 API 部分更新场景
 *
 * @example
 * // 基本使用
 * const diff = deepDiff({ a: 1 }, { a: 2 });
 * // { a: 2 }
 *
 * @example
 * // 忽略字段
 * const diff = deepDiff(
 *   { a: 1, createdAt: '2024-01-01' },
 *   { a: 2, createdAt: '2024-01-02' },
 *   { ignoreKeys: ['createdAt'] }
 * );
 * // { a: 2 }
 *
 * @example
 * // 检查是否有变化
 * const diff = deepDiff(obj1, obj2);
 * if (diff === UNCHANGED) {
 *   console.log('No changes');
 * }
 */

import { difference, isDate, isEqual, isFunction, isPlainObject, isRegExp } from 'es-toolkit';

/**
 * 未改变标记符号
 */
export const UNCHANGED = Symbol('unchanged');

const isArray = Array.isArray;

/**
 * 差异结果类型
 */
export type DiffResult =
  | typeof UNCHANGED
  | Record<string | number | symbol, unknown>
  | unknown[]
  | unknown;

/**
 * 差异比较选项
 */
export interface DiffOptions {
  /** 是否忽略函数（默认 false） */
  ignoreFunctions?: boolean;
  /** 是否包含不可枚举属性（默认 false） */
  includeNonEnumerable?: boolean;
  /** 忽略特定路径，如 ['createdAt', 'updatedAt', 'a.b.c'] */
  ignoreKeys?: string[];
}

/**
 * 判断当前路径是否被忽略
 */
function isIgnored(path: (string | number | symbol)[], ignoreKeys: string[]): boolean {
  const pathStr = path.map(p => String(p)).join('.');
  return ignoreKeys.some(key => key === pathStr || pathStr.startsWith(`${key}.`));
}

/**
 * 比较 null/undefined
 */
function diffNullable(oldValue: unknown, newValue: unknown): DiffResult | null {
  if (oldValue == null || newValue == null) {
    return (oldValue == null && newValue != null) || (newValue == null && oldValue != null)
      ? newValue
      : UNCHANGED;
  }
  return null;
}

/**
 * 比较 Date 对象
 */
function diffDates(oldValue: unknown, newValue: unknown): DiffResult | null {
  if (isDate(oldValue) && isDate(newValue)) {
    return oldValue.getTime() === newValue.getTime() ? UNCHANGED : newValue;
  }
  return null;
}

/**
 * 比较 RegExp 对象
 */
function diffRegExps(oldValue: unknown, newValue: unknown): DiffResult | null {
  if (isRegExp(oldValue) && isRegExp(newValue)) {
    return oldValue.source === newValue.source && oldValue.flags === newValue.flags
      ? UNCHANGED
      : newValue;
  }
  return null;
}

/**
 * 比较 Function
 */
function diffFunctions(
  oldValue: unknown,
  newValue: unknown,
  options: DiffOptions,
): DiffResult | null {
  if (isFunction(oldValue) || isFunction(newValue)) {
    return options.ignoreFunctions ? UNCHANGED : oldValue !== newValue ? newValue : UNCHANGED;
  }
  return null;
}

/**
 * 检查并处理基本类型差异
 */
function diffPrimitives(
  oldValue: unknown,
  newValue: unknown,
  options: DiffOptions,
): DiffResult | null {
  // 使用 es-toolkit 的 isEqual 快速判断相等
  if (isEqual(oldValue, newValue)) {
    return UNCHANGED;
  }

  // 依次检查各种特殊类型
  return (
    diffNullable(oldValue, newValue) ??
    diffDates(oldValue, newValue) ??
    diffRegExps(oldValue, newValue) ??
    diffFunctions(oldValue, newValue, options) ??
    null
  );
}

/**
 * 检查并处理复杂类型差异
 */
function diffComplexTypes(
  oldValue: unknown,
  newValue: unknown,
  options: DiffOptions,
  path: (string | number | symbol)[],
): DiffResult | null {
  // 数组比较
  if (isArray(oldValue) && isArray(newValue)) {
    return diffArray(oldValue, newValue, options, path);
  }

  // Set 比较
  if (oldValue instanceof Set && newValue instanceof Set) {
    return diffSet(oldValue, newValue);
  }

  // Map 比较
  if (oldValue instanceof Map && newValue instanceof Map) {
    return diffMap(oldValue, newValue, options, path);
  }

  // 对象比较
  if (isPlainObject(oldValue) && isPlainObject(newValue)) {
    return diffObject(oldValue, newValue, options, path);
  }

  return null;
}

/**
 * 深度比较两个值，返回差异
 *
 * 只返回新对象中存在且值不同的字段，适合 API 部分更新
 *
 * @param oldValue - 旧值
 * @param newValue - 新值
 * @param options - 配置选项
 * @param path - 当前路径（内部使用）
 * @returns 差异对象，如果无变化返回 UNCHANGED
 */
export function deepDiff(
  oldValue: unknown,
  newValue: unknown,
  options: DiffOptions = {},
  path: (string | number | symbol)[] = [],
): DiffResult {
  const { ignoreKeys = [] } = options;

  // 当前路径被忽略，直接返回新值
  if (isIgnored(path, ignoreKeys)) {
    return newValue;
  }

  // 检查基本类型
  const primitiveResult = diffPrimitives(oldValue, newValue, options);
  if (primitiveResult !== null) {
    return primitiveResult;
  }

  // 检查复杂类型
  const complexResult = diffComplexTypes(oldValue, newValue, options, path);
  if (complexResult !== null) {
    return complexResult;
  }

  // 其他类型直接比较
  return oldValue !== newValue ? newValue : UNCHANGED;
}

/**
 * 比较数组差异
 */
function diffArray(
  oldArr: unknown[],
  newArr: unknown[],
  options: DiffOptions,
  path: (string | number | symbol)[],
): typeof UNCHANGED | unknown[] {
  const maxLength = Math.max(oldArr.length, newArr.length);
  const result: unknown[] = [];
  let hasChanges = false;

  for (let i = 0; i < maxLength; i++) {
    // 新数组更短，元素被删除
    if (i >= newArr.length) {
      hasChanges = true;
      continue;
    }

    // 旧数组更短，元素被添加
    if (i >= oldArr.length) {
      result[i] = newArr[i];
      hasChanges = true;
      continue;
    }

    // 递归比较数组元素
    const diff = deepDiff(oldArr[i], newArr[i], options, [...path, i]);
    if (diff === UNCHANGED) {
      result[i] = oldArr[i];
    } else {
      result[i] = diff;
      hasChanges = true;
    }
  }

  return hasChanges ? result : UNCHANGED;
}

/**
 * 比较对象差异
 *
 * 只遍历新对象的键，适合 API 部分更新
 */
function diffObject(
  oldObj: object,
  newObj: object,
  options: DiffOptions,
  path: (string | number | symbol)[],
): Record<string | number | symbol, unknown> | typeof UNCHANGED {
  const { includeNonEnumerable = false } = options;
  const newKeys = includeNonEnumerable ? Reflect.ownKeys(newObj) : Object.keys(newObj);
  const result: Record<string | number | symbol, unknown> = {};

  for (const key of newKeys) {
    const oldVal = Object.hasOwn(oldObj, key)
      ? (oldObj as Record<string | number | symbol, unknown>)[key]
      : undefined;
    const newVal = Object.hasOwn(newObj, key)
      ? (newObj as Record<string | number | symbol, unknown>)[key]
      : undefined;

    const diff = deepDiff(oldVal, newVal, options, [...path, key]);
    if (diff !== UNCHANGED) {
      result[key] = diff;
    }
  }

  return Object.keys(result).length === 0 ? UNCHANGED : result;
}

/**
 * 比较 Set 差异
 *
 * 使用 es-toolkit 的 difference 优化性能
 */
function diffSet(oldSet: Set<unknown>, newSet: Set<unknown>): typeof UNCHANGED | object {
  const oldArr = [...oldSet];
  const newArr = [...newSet];

  // 使用 es-toolkit 的 difference 计算差集
  const added = difference(newArr, oldArr);
  const deleted = difference(oldArr, newArr);

  if (added.length === 0 && deleted.length === 0) {
    return UNCHANGED;
  }

  return {
    added: added.length > 0 ? added : undefined,
    deleted: deleted.length > 0 ? deleted : undefined,
  };
}

/**
 * 比较 Map 差异
 */
function diffMap(
  oldMap: Map<unknown, unknown>,
  newMap: Map<unknown, unknown>,
  options: DiffOptions = {},
  path: (string | number | symbol)[] = [],
): typeof UNCHANGED | Record<string, unknown> {
  const allKeys = new Set([...oldMap.keys(), ...newMap.keys()]);
  const changes: Record<string, unknown> = {};

  for (const key of allKeys) {
    const oldVal = oldMap.get(key);
    const newVal = newMap.get(key);
    const diff = deepDiff(oldVal, newVal, options, [...path, `Map(${String(key)})`]);
    if (diff !== UNCHANGED) {
      changes[String(key)] = diff;
    }
  }

  return Object.keys(changes).length === 0 ? UNCHANGED : changes;
}
