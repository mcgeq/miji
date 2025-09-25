import { isDate, isFunction, isPlainObject, isRegExp } from 'es-toolkit';

// 标记无变化，避免与 undefined 冲突
const UNCHANGED = Symbol('unchanged');

// 自定义 isArray（原生方法）
const isArray = Array.isArray;
// 自定义 isNaN（原生方法，更安全）
const isNaN = Number.isNaN;

type DiffResult = typeof UNCHANGED | Record<string | number | symbol, any> | any[] | any;

interface DiffOptions {
  /** 是否忽略函数变更（默认：true） */
  ignoreFunctions?: boolean;
  /** 是否包含不可枚举属性（默认：false） */
  includeNonEnumerable?: boolean;
}

/**
 * 深度比较两个值，返回**保持原结构**的变更部分（以 n 的键结构为主）
 * @param o 旧值
 * @param n 新值
 * @param options 配置项
 * @returns 变更后的值（无变化返回 UNCHANGED）
 */
export function deepDiff(o: any, n: any, options: DiffOptions = {}): DiffResult {
  // 1. 全等或 NaN（无需变化）
  if (o === n) return UNCHANGED;
  if (typeof o === 'number' && typeof n === 'number' && isNaN(o) && isNaN(n)) return UNCHANGED;

  // 2. 处理 null/undefined（一方有值、另一方无，则返回新值）
  if (o == null || n == null) {
    return (o == null && n != null) || (n == null && o != null) ? n : UNCHANGED;
  }

  // 3. 日期（比较时间戳）
  if (isDate(o) && isDate(n)) return o.getTime() === n.getTime() ? UNCHANGED : n;

  // 4. 正则（比较源码和标志）
  if (isRegExp(o) && isRegExp(n))
    return o.source === n.source && o.flags === n.flags ? UNCHANGED : n;

  // 5. 函数（可选忽略）
  if (isFunction(o) || isFunction(n)) {
    if (options.ignoreFunctions) return UNCHANGED;
    return o !== n ? n : UNCHANGED;
  }

  // 6. 数组（递归比较每个元素，保持数组结构）
  if (isArray(o) && isArray(n)) return diffArray(o, n);

  // 7. Set（返回新增/删除的元素）
  if (o instanceof Set && n instanceof Set) return diffSet(o, n);

  // 8. Map（返回键值对的变更）
  if (o instanceof Map && n instanceof Map) return diffMap(o, n);

  // 9. 普通对象（**仅遍历 n 的键**，确保结果以 n 为主）
  if (isPlainObject(o) && isPlainObject(n)) {
    const diffObj = diffObject(o, n, options);
    return Object.keys(diffObj).length === 0 ? UNCHANGED : diffObj;
  }

  // 10. 其他类型（直接比较）
  return o !== n ? n : UNCHANGED;
}

/** 比较数组差异，返回有变化的数组（或 UNCHANGED） */
function diffArray(oldArr: any[], newArr: any[]): typeof UNCHANGED | any[] {
  const maxLength = Math.max(oldArr.length, newArr.length);
  const result: any[] = [];
  let hasChanges = false;

  for (let i = 0; i < maxLength; i++) {
    const oldVal = oldArr[i];
    const newVal = newArr[i];
    const diff = deepDiff(oldVal, newVal);

    if (diff === UNCHANGED) {
      result[i] = oldVal; // 无变化，保留旧值
    } else {
      result[i] = diff; // 有变化，使用新值
      hasChanges = true;
    }
  }

  return hasChanges ? result : UNCHANGED;
}

/** 比较对象差异，**仅遍历 n 的键**（确保结果以 n 为主） */
function diffObject(
  oldObj: object,
  newObj: object,
  options: DiffOptions,
): Record<string | number | symbol, any> {
  const { includeNonEnumerable = false } = options;
  // 仅获取 newObj 的键（Reflect.ownKeys 包含 Symbol，Object.keys 仅字符串）
  const newKeys = includeNonEnumerable ? Reflect.ownKeys(newObj) : Object.keys(newObj);
  const result: Record<string | number | symbol, any> = {};

  for (const key of newKeys) {
    // 获取 oldObj 中的值（无则为 undefined）
    const oldVal = Object.prototype.hasOwnProperty.call(oldObj, key)
      ? (oldObj as any)[key]
      : undefined;
    // 获取 newObj 中的值
    const newVal = Object.prototype.hasOwnProperty.call(newObj, key)
      ? (newObj as any)[key]
      : undefined;

    const diff = deepDiff(oldVal, newVal);

    if (diff !== UNCHANGED) {
      result[key] = diff; // 仅保留 n 中键的变更
    }
  }

  return result;
}

/** 比较 Set 差异，返回新增/删除的元素（或 UNCHANGED） */
function diffSet(
  oldSet: Set<any>,
  newSet: Set<any>,
): typeof UNCHANGED | { added?: any[]; deleted?: any[] } {
  const added = [...newSet].filter(v => !oldSet.has(v));
  const deleted = [...oldSet].filter(v => !newSet.has(v));

  if (added.length === 0 && deleted.length === 0) return UNCHANGED;

  return {
    added: added.length > 0 ? added : undefined,
    deleted: deleted.length > 0 ? deleted : undefined,
  };
}

/** 比较 Map 差异，返回键值对的变更（或 UNCHANGED） */
function diffMap(
  oldMap: Map<any, any>,
  newMap: Map<any, any>,
): typeof UNCHANGED | Record<string, any> {
  const allKeys = new Set([...oldMap.keys(), ...newMap.keys()]);
  const changes: Record<string, any> = {};

  for (const key of allKeys) {
    const oldVal = oldMap.get(key);
    const newVal = newMap.get(key);
    const diff = deepDiff(oldVal, newVal);

    if (diff !== UNCHANGED) {
      changes[key.toString()] = diff; // 键转为字符串存储
    }
  }

  return Object.keys(changes).length === 0 ? UNCHANGED : changes;
}
