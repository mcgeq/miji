import { isArray, isDate, isFunction, isNaN, isObject, isRegExp } from 'es-toolkit/compat';

type DiffResult = Record<string, any>;

interface DiffOptions {
  ignoreFunctions?: boolean;
  includeNonEnumerable?: boolean;
}

function buildPath(parent: string, key: string | number): string {
  if (typeof key === 'number') {
    return parent ? `${parent}[${key}]` : `[${key}]`;
  }
  return parent ? `${parent}.${key}` : String(key);
}

function diffArray(o: any[], n: any[], parent: string, options: DiffOptions): DiffResult {
  const maxLen = Math.max(o.length, n.length);
  const diff: DiffResult = {};
  for (let i = 0; i < maxLen; i++) {
    Object.assign(diff, deepDiff(o[i], n[i], buildPath(parent, i), options));
  }
  return diff;
}

function diffObject(o: object, n: object, parent: string, options: DiffOptions): DiffResult {
  const { includeNonEnumerable = false } = options;
  const keys = new Set([
    ...(includeNonEnumerable ? Reflect.ownKeys(o) : Object.keys(o)),
    ...(includeNonEnumerable ? Reflect.ownKeys(n) : Object.keys(n)),
  ]);

  const diff: DiffResult = {};
  for (const key of keys) {
    const oldVal = Object.prototype.hasOwnProperty.call(o, key) ? (o as any)[key] : undefined;
    const newVal = Object.prototype.hasOwnProperty.call(n, key) ? (n as any)[key] : undefined;
    Object.assign(diff, deepDiff(oldVal, newVal, buildPath(parent, key.toString()), options));
  }
  return diff;
}

function diffSet(o: Set<any>, n: Set<any>, parent: string): DiffResult {
  const added = [...n].filter(v => !o.has(v));
  const removed = [...o].filter(v => !n.has(v));

  if (added.length === 0 && removed.length === 0) {
    return {};
  }
  return {
    [parent || '']: {
      added,
      removed,
    },
  };
}

function diffMap(
  o: Map<any, any>,
  n: Map<any, any>,
  parent: string,
  options: DiffOptions,
): DiffResult {
  const diff: DiffResult = {};

  const keys = new Set([...o.keys(), ...n.keys()]);
  for (const key of keys) {
    const oldVal = o.has(key) ? o.get(key) : undefined;
    const newVal = n.has(key) ? n.get(key) : undefined;
    Object.assign(
      diff,
      deepDiff(oldVal, newVal, buildPath(parent, `MapKey(${String(key)})`), options),
    );
  }
  return diff;
}

export function deepDiff(
  o: any,
  n: any,
  parentPath: string = '',
  options: DiffOptions = {},
): DiffResult {
  const { ignoreFunctions = true } = options;

  // 全等
  if (o === n) return {};

  // NaN 特殊处理
  if (typeof o === 'number' && typeof n === 'number' && isNaN(o) && isNaN(n)) {
    return {};
  }

  // null
  if (o === null || n === null) return { [parentPath]: n };

  // 日期
  if (isDate(o) && isDate(n)) {
    return o.getTime() === n.getTime() ? {} : { [parentPath]: n };
  }

  // 正则
  if (isRegExp(o) && isRegExp(n)) {
    return o.source === n.source && o.flags === n.flags ? {} : { [parentPath]: n };
  }

  // 函数
  if (isFunction(o) || isFunction(n)) {
    if (ignoreFunctions) return {};
    return o !== n ? { [parentPath]: n } : {};
  }

  // 数组
  if (isArray(o) && isArray(n)) {
    return diffArray(o, n, parentPath, options);
  }

  // Set
  if (o instanceof Set && n instanceof Set) {
    return diffSet(o, n, parentPath);
  }

  // Map
  if (o instanceof Map && n instanceof Map) {
    return diffMap(o, n, parentPath, options);
  }

  // 对象
  if (isObject(o) && isObject(n)) {
    return diffObject(o, n, parentPath, options);
  }

  // 其他类型（string, number, bigint, symbol...）
  return o !== n ? { [parentPath]: n } : {};
}
