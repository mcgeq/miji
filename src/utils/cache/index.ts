/**
 * 统一的缓存系统
 *
 * 整合：
 * - simpleCache.ts (全局数据缓存)
 * - apiHelper.ts 的 ApiCache (API 请求缓存)
 * - cacheUtils.ts (函数缓存工具)
 *
 * 使用示例：
 * ```typescript
 * // 1. 全局数据缓存
 * import { globalCache, cacheKeys } from '@/utils/cache';
 * globalCache.set(cacheKeys.familyLedger('123'), ledgerData);
 *
 * // 2. API 请求缓存
 * import { apiCache } from '@/utils/cache';
 * apiCache.set('api:getUser:123', userData);
 *
 * // 3. 函数缓存
 * import { memoizeFunction, createTTLCache } from '@/utils/cache';
 * const cachedFn = memoizeFunction(expensiveFunction);
 * ```
 */

// ==================== 函数缓存工具 ====================
export {
  CacheResult,
  // 缓存工具
  createCacheKey,
  createLRUCache,
  // 异步缓存
  createRefreshableCache,
  // TTL 和 LRU 缓存
  createTTLCache,
  invalidateCaches,
  // es-toolkit 原始函数
  memoize,
  // 基础函数缓存
  memoizeFunction,
  once,
  onceFunction,
} from './functions';
// ==================== 全局实例 ====================
export { apiCache, cacheKeys, globalCache, stopCacheCleanup } from './instances';
// ==================== TTL 缓存类 ====================
export { TTLCache } from './TTLCache';
export type { CacheEntry, CacheKeyGenerator, TTLCacheOptions } from './types';
