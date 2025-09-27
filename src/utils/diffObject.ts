import { isDate, isFunction, isPlainObject, isRegExp } from 'es-toolkit';

const UNCHANGED = Symbol('unchanged');

const isArray = Array.isArray;
const isNaN = Number.isNaN;

type DiffResult = typeof UNCHANGED | Record<string | number | symbol, any> | any[] | any;

interface DiffOptions {
  ignoreFunctions?: boolean;
  includeNonEnumerable?: boolean;
  /** 支持深层路径，如 ['a.b.c', 'x.y']，忽略整个子树 */
  ignoreKeys?: string[];
}

/** 判断当前路径是否被忽略（支持子树） */
function isIgnored(path: (string | number | symbol)[], ignoreKeys: string[]): boolean {
  const pathStr = path.map(p => (typeof p === 'symbol' ? p.toString() : p.toString())).join('.');
  return ignoreKeys.some(key => key === pathStr || pathStr.startsWith(`${key}.`));
}

export function deepDiff(
  o: any,
  n: any,
  options: DiffOptions = {},
  path: (string | number | symbol)[] = [],
): DiffResult {
  const { ignoreKeys = [] } = options;

  // 当前路径被忽略，直接返回新值 n（包括整个子树）
  if (isIgnored(path, ignoreKeys)) return n;

  if (o === n) return UNCHANGED;
  if (typeof o === 'number' && typeof n === 'number' && isNaN(o) && isNaN(n)) return UNCHANGED;
  if (o == null || n == null)
    return (o == null && n != null) || (n == null && o != null) ? n : UNCHANGED;
  if (isDate(o) && isDate(n)) return o.getTime() === n.getTime() ? UNCHANGED : n;
  if (isRegExp(o) && isRegExp(n))
    return o.source === n.source && o.flags === n.flags ? UNCHANGED : n;
  if (isFunction(o) || isFunction(n))
    return options.ignoreFunctions ? UNCHANGED : o !== n ? n : UNCHANGED;
  if (isArray(o) && isArray(n)) return diffArray(o, n, options, path);
  if (o instanceof Set && n instanceof Set) return diffSet(o, n);
  if (o instanceof Map && n instanceof Map) return diffMap(o, n);
  if (isPlainObject(o) && isPlainObject(n)) return diffObject(o, n, options, path);

  return o !== n ? n : UNCHANGED;
}

function diffArray(
  oldArr: any[],
  newArr: any[],
  options: DiffOptions,
  path: (string | number | symbol)[],
): typeof UNCHANGED | any[] {
  const maxLength = Math.max(oldArr.length, newArr.length);
  const result: any[] = [];
  let hasChanges = false;

  for (let i = 0; i < maxLength; i++) {
    const oldVal = oldArr[i];
    const newVal = newArr[i];

    if (i >= newArr.length) {
      hasChanges = true;
      continue;
    }
    if (i >= oldArr.length) {
      result[i] = newVal;
      hasChanges = true;
      continue;
    }

    const diff = deepDiff(oldVal, newVal, options, [...path, i]);
    if (diff === UNCHANGED) {
      result[i] = oldVal;
    } else {
      result[i] = diff;
      hasChanges = true;
    }
  }

  return hasChanges ? result : UNCHANGED;
}

function diffObject(
  oldObj: object,
  newObj: object,
  options: DiffOptions,
  path: (string | number | symbol)[],
): Record<string | number | symbol, any> | typeof UNCHANGED {
  const { includeNonEnumerable = false } = options;
  const newKeys = includeNonEnumerable ? Reflect.ownKeys(newObj) : Object.keys(newObj);
  const result: Record<string | number | symbol, any> = {};

  for (const key of newKeys) {
    const oldVal = Object.prototype.hasOwnProperty.call(oldObj, key)
      ? (oldObj as any)[key]
      : undefined;
    const newVal = Object.prototype.hasOwnProperty.call(newObj, key)
      ? (newObj as any)[key]
      : undefined;

    const diff = deepDiff(oldVal, newVal, options, [...path, key]);
    if (diff !== UNCHANGED) result[key] = diff;
  }

  return Object.keys(result).length === 0 ? UNCHANGED : result;
}

function diffSet(oldSet: Set<any>, newSet: Set<any>) {
  const added = [...newSet].filter(v => !oldSet.has(v));
  const deleted = [...oldSet].filter(v => !newSet.has(v));
  if (added.length === 0 && deleted.length === 0) return UNCHANGED;
  return {
    added: added.length > 0 ? added : undefined,
    deleted: deleted.length > 0 ? deleted : undefined,
  };
}

function diffMap(oldMap: Map<any, any>, newMap: Map<any, any>) {
  const allKeys = new Set([...oldMap.keys(), ...newMap.keys()]);
  const changes: Record<string, any> = {};

  for (const key of allKeys) {
    const oldVal = oldMap.get(key);
    const newVal = newMap.get(key);
    const diff = deepDiff(oldVal, newVal);
    if (diff !== UNCHANGED) changes[key.toString()] = diff;
  }

  return Object.keys(changes).length === 0 ? UNCHANGED : changes;
}
