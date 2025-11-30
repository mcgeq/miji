/**
 * 数组工具函数
 * 基于 es-toolkit 提供常用的数组操作
 *
 * @see https://es-toolkit.slash.page/reference/array/chunk.html
 */

import {
  chunk,
  compact,
  difference,
  drop,
  flatten,
  groupBy,
  intersection,
  partition,
  sample,
  shuffle,
  sortBy,
  take,
  uniq,
  uniqBy,
  zip,
} from 'es-toolkit';
import { mean, sum } from 'es-toolkit/math';

// ==================== 数组分块 ====================

/**
 * 将数组分割成指定大小的块
 * @param arr - 源数组
 * @param size - 每块的大小
 * @returns 分块后的二维数组
 *
 * @example
 * chunkArray([1, 2, 3, 4, 5], 2) // [[1, 2], [3, 4], [5]]
 * chunkArray(['a', 'b', 'c', 'd'], 3) // [['a', 'b', 'c'], ['d']]
 */
export function chunkArray<T>(arr: T[], size: number): T[][] {
  return chunk(arr, size);
}

// ==================== 数组去重 ====================

/**
 * 数组去重（基本类型）
 * @param arr - 源数组
 * @returns 去重后的数组
 *
 * @example
 * uniqueArray([1, 2, 2, 3, 3, 3]) // [1, 2, 3]
 * uniqueArray(['a', 'b', 'a', 'c']) // ['a', 'b', 'c']
 */
export function uniqueArray<T>(arr: T[]): T[] {
  return uniq(arr);
}

/**
 * 根据指定属性去重
 * @param arr - 源数组
 * @param iteratee - 提取唯一标识的函数或属性名
 * @returns 去重后的数组
 *
 * @example
 * const users = [
 *   { id: 1, name: 'Alice' },
 *   { id: 2, name: 'Bob' },
 *   { id: 1, name: 'Alice Duplicate' }
 * ];
 * uniqueArrayBy(users, 'id') // [{ id: 1, name: 'Alice' }, { id: 2, name: 'Bob' }]
 * uniqueArrayBy(users, u => u.id) // 同上
 */
export function uniqueArrayBy<T>(arr: T[], iteratee: ((item: T) => any) | keyof T): T[] {
  return uniqBy(arr, iteratee as any);
}

// ==================== 数组分组 ====================

/**
 * 根据指定条件分组
 * @param arr - 源数组
 * @param iteratee - 分组条件函数或属性名
 * @returns 分组后的对象
 *
 * @example
 * const transactions = [
 *   { category: 'food', amount: 100 },
 *   { category: 'transport', amount: 50 },
 *   { category: 'food', amount: 200 }
 * ];
 * groupArrayBy(transactions, 'category')
 * // { food: [...], transport: [...] }
 *
 * groupArrayBy(transactions, t => t.amount > 100 ? 'high' : 'low')
 * // { high: [...], low: [...] }
 */
export function groupArrayBy<T, K extends PropertyKey>(
  arr: T[],
  iteratee: ((item: T) => K) | keyof T,
): Record<K, T[]> {
  return groupBy(arr, iteratee as any);
}

// ==================== 数组排序 ====================

/**
 * 根据多个条件排序
 * @param arr - 源数组
 * @param iteratees - 排序条件数组（函数或属性名）
 * @returns 排序后的新数组
 *
 * @example
 * const users = [
 *   { name: 'Bob', age: 30 },
 *   { name: 'Alice', age: 25 },
 *   { name: 'Charlie', age: 25 }
 * ];
 * sortArray(users, ['age', 'name'])
 * // 先按年龄排序，年龄相同再按名字排序
 *
 * sortArray(users, [u => u.age, u => u.name])
 * // 同上，使用函数形式
 */
export function sortArray<T extends object>(
  arr: T[],
  iteratees: Array<((item: T) => any) | keyof T>,
): T[] {
  return sortBy(arr, iteratees as any);
}

// ==================== 数组分区 ====================

/**
 * 根据条件将数组分为两组
 * @param arr - 源数组
 * @param predicate - 判断条件
 * @returns [满足条件的数组, 不满足条件的数组]
 *
 * @example
 * const numbers = [1, 2, 3, 4, 5, 6];
 * const [evens, odds] = partitionArray(numbers, n => n % 2 === 0);
 * // evens: [2, 4, 6], odds: [1, 3, 5]
 *
 * const users = [
 *   { name: 'Alice', active: true },
 *   { name: 'Bob', active: false },
 *   { name: 'Charlie', active: true }
 * ];
 * const [active, inactive] = partitionArray(users, u => u.active);
 */
export function partitionArray<T>(arr: T[], predicate: (item: T) => boolean): [T[], T[]] {
  return partition(arr, predicate);
}

// ==================== 数组差集/交集 ====================

/**
 * 获取数组差集（在第一个数组但不在第二个数组中的元素）
 * @param arr1 - 第一个数组
 * @param arr2 - 第二个数组
 * @returns 差集数组
 *
 * @example
 * arrayDifference([1, 2, 3, 4], [2, 4]) // [1, 3]
 * arrayDifference(['a', 'b', 'c'], ['b', 'd']) // ['a', 'c']
 */
export function arrayDifference<T>(arr1: T[], arr2: T[]): T[] {
  return difference(arr1, arr2);
}

/**
 * 获取数组交集（同时存在于两个数组中的元素）
 * @param arr1 - 第一个数组
 * @param arr2 - 第二个数组
 * @returns 交集数组
 *
 * @example
 * arrayIntersection([1, 2, 3, 4], [2, 3, 5]) // [2, 3]
 * arrayIntersection(['a', 'b', 'c'], ['b', 'c', 'd']) // ['b', 'c']
 */
export function arrayIntersection<T>(arr1: T[], arr2: T[]): T[] {
  return intersection(arr1, arr2);
}

// ==================== 数组过滤 ====================

/**
 * 移除数组中的假值（false, null, 0, "", undefined, NaN）
 * @param arr - 源数组
 * @returns 过滤后的数组
 *
 * @example
 * compactArray([0, 1, false, 2, '', 3, null, undefined, NaN])
 * // [1, 2, 3]
 */
export function compactArray<T>(arr: T[]): NonNullable<T>[] {
  return compact(arr) as NonNullable<T>[];
}

// ==================== 数组扁平化 ====================

/**
 * 扁平化嵌套数组（一层）
 * @param arr - 嵌套数组
 * @returns 扁平化后的数组
 *
 * @example
 * flattenArray([[1, 2], [3, 4], [5]]) // [1, 2, 3, 4, 5]
 * flattenArray([['a', 'b'], ['c'], ['d', 'e']]) // ['a', 'b', 'c', 'd', 'e']
 */
export function flattenArray<T>(arr: T[][]): T[] {
  return flatten(arr);
}

// ==================== 数组随机 ====================

/**
 * 随机打乱数组顺序
 * @param arr - 源数组
 * @returns 打乱后的新数组
 *
 * @example
 * shuffleArray([1, 2, 3, 4, 5]) // [3, 1, 5, 2, 4] (随机顺序)
 */
export function shuffleArray<T>(arr: T[]): T[] {
  return shuffle(arr);
}

/**
 * 随机选取一个元素
 * @param arr - 源数组
 * @returns 随机元素
 *
 * @example
 * randomElement([1, 2, 3, 4, 5]) // 3 (随机)
 */
export function randomElement<T>(arr: T[]): T | undefined {
  return sample(arr);
}

// ==================== 数组截取 ====================

/**
 * 获取数组前 n 个元素
 * @param arr - 源数组
 * @param n - 数量
 * @returns 前 n 个元素
 *
 * @example
 * takeFirst([1, 2, 3, 4, 5], 3) // [1, 2, 3]
 */
export function takeFirst<T>(arr: T[], n: number): T[] {
  return take(arr, n);
}

/**
 * 跳过前 n 个元素，返回剩余元素
 * @param arr - 源数组
 * @param n - 跳过数量
 * @returns 剩余元素
 *
 * @example
 * skipFirst([1, 2, 3, 4, 5], 2) // [3, 4, 5]
 */
export function skipFirst<T>(arr: T[], n: number): T[] {
  return drop(arr, n);
}

// ==================== 数组合并 ====================

/**
 * 将多个数组对应位置的元素组合成新数组
 * @param arrays - 要合并的数组列表
 * @returns 合并后的数组
 *
 * @example
 * zipArrays([1, 2], ['a', 'b'], [true, false])
 * // [[1, 'a', true], [2, 'b', false]]
 */
export function zipArrays<T>(...arrays: T[][]): T[][] {
  return zip(...arrays);
}

// ==================== 数组统计 ====================

/**
 * 计算数字数组的总和
 * @param arr - 数字数组
 * @returns 总和
 *
 * @example
 * sumArray([1, 2, 3, 4, 5]) // 15
 * sumArray([10, 20, 30]) // 60
 */
export function sumArray(arr: number[]): number {
  return sum(arr);
}

/**
 * 计算数字数组的平均值
 * @param arr - 数字数组
 * @returns 平均值
 *
 * @example
 * averageArray([1, 2, 3, 4, 5]) // 3
 * averageArray([10, 20, 30]) // 20
 */
export function averageArray(arr: number[]): number {
  return mean(arr);
}

/**
 * 根据属性计算对象数组的总和
 * @param arr - 对象数组
 * @param key - 属性名
 * @returns 总和
 *
 * @example
 * const transactions = [
 *   { amount: 100 },
 *   { amount: 200 },
 *   { amount: 150 }
 * ];
 * sumBy(transactions, 'amount') // 450
 */
export function sumBy<T>(arr: T[], key: keyof T): number {
  const values = arr.map(item => Number(item[key]) || 0);
  return sum(values);
}

/**
 * 根据属性计算对象数组的平均值
 * @param arr - 对象数组
 * @param key - 属性名
 * @returns 平均值
 *
 * @example
 * const users = [
 *   { age: 25 },
 *   { age: 30 },
 *   { age: 35 }
 * ];
 * averageBy(users, 'age') // 30
 */
export function averageBy<T>(arr: T[], key: keyof T): number {
  const values = arr.map(item => Number(item[key]) || 0);
  return mean(values);
}

// ==================== 数组查找 ====================

/**
 * 查找数组中的最大值
 * @param arr - 数字数组
 * @returns 最大值
 *
 * @example
 * maxValue([1, 5, 3, 9, 2]) // 9
 */
export function maxValue(arr: number[]): number {
  return Math.max(...arr);
}

/**
 * 查找数组中的最小值
 * @param arr - 数字数组
 * @returns 最小值
 *
 * @example
 * minValue([1, 5, 3, 9, 2]) // 1
 */
export function minValue(arr: number[]): number {
  return Math.min(...arr);
}

/**
 * 根据属性查找对象数组中的最大值项
 * @param arr - 对象数组
 * @param key - 属性名
 * @returns 最大值项
 *
 * @example
 * const users = [
 *   { name: 'Alice', age: 25 },
 *   { name: 'Bob', age: 35 },
 *   { name: 'Charlie', age: 30 }
 * ];
 * maxBy(users, 'age') // { name: 'Bob', age: 35 }
 */
export function maxBy<T>(arr: T[], key: keyof T): T | undefined {
  if (arr.length === 0) return undefined;
  return arr.reduce((max, item) => ((item[key] as any) > (max[key] as any) ? item : max));
}

/**
 * 根据属性查找对象数组中的最小值项
 * @param arr - 对象数组
 * @param key - 属性名
 * @returns 最小值项
 *
 * @example
 * const users = [
 *   { name: 'Alice', age: 25 },
 *   { name: 'Bob', age: 35 },
 *   { name: 'Charlie', age: 30 }
 * ];
 * minBy(users, 'age') // { name: 'Alice', age: 25 }
 */
export function minBy<T>(arr: T[], key: keyof T): T | undefined {
  if (arr.length === 0) return undefined;
  return arr.reduce((min, item) => ((item[key] as any) < (min[key] as any) ? item : min));
}

// ==================== 数组分页 ====================

/**
 * 数组分页
 * @param arr - 源数组
 * @param page - 页码（从 1 开始）
 * @param pageSize - 每页大小
 * @returns 当前页的数据
 *
 * @example
 * const data = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10];
 * paginateArray(data, 1, 3) // [1, 2, 3]
 * paginateArray(data, 2, 3) // [4, 5, 6]
 * paginateArray(data, 4, 3) // [10]
 */
export function paginateArray<T>(arr: T[], page: number, pageSize: number): T[] {
  const start = (page - 1) * pageSize;
  const end = start + pageSize;
  return arr.slice(start, end);
}

/**
 * 获取分页信息
 * @param totalItems - 总数
 * @param page - 当前页
 * @param pageSize - 每页大小
 * @returns 分页信息
 *
 * @example
 * getPaginationInfo(100, 3, 10)
 * // {
 * //   totalPages: 10,
 * //   currentPage: 3,
 * //   pageSize: 10,
 * //   totalItems: 100,
 * //   hasNextPage: true,
 * //   hasPrevPage: true,
 * //   startIndex: 20,
 * //   endIndex: 30
 * // }
 */
export function getPaginationInfo(totalItems: number, page: number, pageSize: number) {
  const totalPages = Math.ceil(totalItems / pageSize);
  const startIndex = (page - 1) * pageSize;
  const endIndex = Math.min(startIndex + pageSize, totalItems);

  return {
    totalPages,
    currentPage: page,
    pageSize,
    totalItems,
    hasNextPage: page < totalPages,
    hasPrevPage: page > 1,
    startIndex,
    endIndex,
  };
}

// ==================== 导出所有 es-toolkit 数组工具 ====================

export {
  // es-toolkit 原生导出
  chunk,
  compact,
  difference,
  flatten,
  groupBy,
  intersection,
  partition,
  shuffle,
  sortBy,
  uniq,
  uniqBy,
  zip,
  take,
  drop,
  sample,
  sum,
  mean,
};
