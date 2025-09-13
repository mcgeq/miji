import { isArray, isDate, isFunction, isNaN, isRegExp } from 'es-toolkit/compat';

type DiffResult = Record<string, any>;

export function deepDiff(
  o: any,
  n: any,
  parentPath: string = '',
  options: {
    ignoreFunctions?: boolean;
    includeNonEnumerable?: boolean;
  },
) {
  const { ignoreFunctions = true } = options;

  if (o === n) return {};
  if (typeof o === 'number' && typeof n === 'number' && isNaN(o) && isNaN(n)) {
    return {};
  }

  if (o === null || n === null) {
    return { [parentPath]: n };
  }

  if (isDate(o) && isDate(n)) {
    return o.getTime() !== n.getTime() ? { [parentPath]: n } : {};
  }

  if (isRegExp(o) && isRegExp(n)) {
    return o.source !== n.source || o.flags !== n.flags ? { [parentPath]: n } : {};
  }

  if (isFunction(o) || isFunction(n)) {
    if (ignoreFunctions) return {};
    return o !== n ? { [parentPath]: n } : {};
  }

  if (isArray(o) && isArray(n)) {
    const maxLen = Math.max(o.length, n.length);
    const diff: DiffResult = {};
    for (let i = 0; i < maxLen; i++) {
      const currentPath = parentPath ? `${parentPath}[${i}]` : `[${i}]`;
      const oldVal = o[i];
      const newVal = n[i];
      Object.assign(diff, deepDiff(oldVal, newVal, currentPath, options));
    }
    return diff;
  }

  // 处理普通对象：遍历所有键（含原型链？不，仅自身属性）
  // if (isObject(o) && isObject(n)) {
  //   const diff: DiffResult = {};
  //   // 收集所有键（旧对象的键 + 新对象的键）
  //   const allKeys = new Set([
  //     ...(includeNonEnumerable ? Reflect.ownKeys(o) : Object.keys(o)),
  //     ...(includeNonEnumerable ? Reflect.ownKeys(n) : Object.keys(n)),
  //   ]);
  //
  //   for (const key of allKeys) {
  //     const currentPath = parentPath ? `${parentPath}.${key.toString()}` : key.toString();
  //     const oldVal = o.hasOwnProperty.call(o, key) ? o[key] : undefined;
  //     const newVal = n.hasOwnProperty.call(n, key) ? n[key] : undefined;
  //
  //     // 递归比对子属性
  //     const childDiff = deepDiff(oldVal, newVal, currentPath, options);
  //     Object.assign(diff, childDiff);
  //   }
  //   return diff;
  // }

  // 其他类型（如 Symbol、BigInt 等）直接比较值
  return o !== n ? { [parentPath]: n } : {};
}
