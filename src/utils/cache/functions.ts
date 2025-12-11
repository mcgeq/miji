/**
 * 函数缓存工具
 *
 * 提供基于 es-toolkit 的函数结果缓存
 *
 * @note 与 TTLCache 的区别：
 * - TTLCache: 全局数据缓存，手动 set/get
 * - functions: 函数结果缓存，自动缓存函数返回值
 */

import { memoize, once } from 'es-toolkit';

// ==================== 基础函数缓存 ====================

/**
 * 缓存函数结果（基于参数）
 *
 * @param fn - 要缓存的函数
 * @returns 缓存版本的函数
 *
 * @example
 * const expensiveCalc = memoizeFunction((n: number) => n * 2);
 * expensiveCalc(5); // 计算并缓存
 * expensiveCalc(5); // 从缓存返回
 */
export function memoizeFunction<T extends (...args: unknown[]) => unknown>(fn: T): T {
  return memoize(fn);
}

/**
 * 确保函数只执行一次
 *
 * @param fn - 要包装的函数
 * @returns 只执行一次的函数
 *
 * @example
 * const initialize = onceFunction(() => console.log('Init'));
 * initialize(); // 输出 "Init"
 * initialize(); // 什么都不做
 */
export function onceFunction<T extends (...args: unknown[]) => unknown>(fn: T): T {
  return once(fn);
}

// ==================== 缓存装饰器 ====================

/**
 * 缓存方法结果的装饰器
 *
 * @example
 * class DataService {
 *   @CacheResult
 *   fetchData(id: string) {
 *     return fetch(`/api/data/${id}`);
 *   }
 * }
 */
export function CacheResult(
  _target: unknown,
  _propertyKey: string,
  descriptor: PropertyDescriptor,
) {
  const originalMethod = descriptor.value;
  descriptor.value = memoize(originalMethod);
  return descriptor;
}

// ==================== TTL 缓存包装器 ====================

interface TTLCacheEntry<T> {
  value: T;
  expiry: number;
}

/**
 * 创建带 TTL 的函数缓存
 *
 * @param fn - 要缓存的函数
 * @param ttl - 过期时间（毫秒）
 * @returns 带 TTL 的缓存函数
 *
 * @example
 * const fetchUser = createTTLCache(
 *   async (id: string) => api.getUser(id),
 *   5 * 60 * 1000 // 5分钟缓存
 * );
 */
export function createTTLCache<T extends (...args: unknown[]) => unknown>(
  fn: T,
  ttl: number,
): T & { clear: () => void } {
  const cache = new Map<string, TTLCacheEntry<unknown>>();

  const cachedFn = ((...args: unknown[]) => {
    const key = JSON.stringify(args);
    const now = Date.now();
    const entry = cache.get(key);

    if (entry && now < entry.expiry) {
      return entry.value;
    }

    const result = fn(...args);

    // 如果是 Promise，缓存 resolved 值
    if (result instanceof Promise) {
      return result.then((value: unknown) => {
        cache.set(key, { value, expiry: now + ttl });
        return value;
      });
    }

    cache.set(key, { value: result, expiry: now + ttl });
    return result;
  }) as T & { clear: () => void };

  cachedFn.clear = () => cache.clear();

  return cachedFn;
}

// ==================== LRU 缓存包装器 ====================

/**
 * 创建 LRU（最近最少使用）缓存函数
 *
 * @param fn - 要缓存的函数
 * @param maxSize - 最大缓存数量
 * @returns LRU 缓存函数
 *
 * @example
 * const fetchData = createLRUCache(
 *   async (id: string) => api.getData(id),
 *   100 // 最多缓存 100 个结果
 * );
 */
export function createLRUCache<T extends (...args: unknown[]) => unknown>(
  fn: T,
  maxSize: number,
): T & { clear: () => void; size: () => number } {
  const cache = new Map<string, unknown>();

  const cachedFn = ((...args: unknown[]) => {
    const key = JSON.stringify(args);

    if (cache.has(key)) {
      // 移到最后（表示最近使用）
      const value = cache.get(key);
      cache.delete(key);
      cache.set(key, value);
      return value;
    }

    const result = fn(...args);

    // 如果是 Promise，缓存 resolved 值
    if (result instanceof Promise) {
      return result.then((value: unknown) => {
        // 如果超过最大大小，删除最旧的（第一个）
        if (cache.size >= maxSize) {
          const firstKey = cache.keys().next().value as string;
          if (firstKey) {
            cache.delete(firstKey);
          }
        }
        cache.set(key, value);
        return value;
      });
    }

    // 如果超过最大大小，删除最旧的
    if (cache.size >= maxSize) {
      const firstKey = cache.keys().next().value as string;
      if (firstKey) {
        cache.delete(firstKey);
      }
    }

    cache.set(key, result);
    return result;
  }) as T & { clear: () => void; size: () => number };

  cachedFn.clear = () => cache.clear();
  cachedFn.size = () => cache.size;

  return cachedFn;
}

// ==================== 缓存工具 ====================

/**
 * 创建缓存键生成器
 *
 * @param prefix - 键前缀
 * @returns 键生成函数
 *
 * @example
 * const userCacheKey = createCacheKey('user');
 * userCacheKey('123'); // 'user:123'
 * userCacheKey('456', 'profile'); // 'user:456:profile'
 */
export function createCacheKey(prefix: string) {
  return (...parts: (string | number)[]): string => {
    return [prefix, ...parts].join(':');
  };
}

/**
 * 批量使缓存失效
 *
 * @param caches - 缓存函数数组
 *
 * @example
 * const cache1 = createTTLCache(fn1, 1000);
 * const cache2 = createTTLCache(fn2, 1000);
 * invalidateCaches([cache1, cache2]);
 */
export function invalidateCaches(caches: Array<{ clear: () => void }>) {
  for (const cache of caches) {
    cache.clear();
  }
}

// ==================== 异步缓存工具 ====================

/**
 * 创建带刷新功能的缓存
 *
 * @param fn - 异步函数
 * @param ttl - 过期时间
 * @param refreshInterval - 自动刷新间隔（可选）
 * @returns 缓存函数和控制方法
 *
 * @example
 * const { execute, clear, refresh } = createRefreshableCache(
 *   async () => fetch('/api/config').then(r => r.json()),
 *   10 * 60 * 1000, // 10分钟缓存
 *   5 * 60 * 1000   // 5分钟自动刷新
 * );
 */
export function createRefreshableCache<T>(
  fn: () => Promise<T>,
  ttl: number,
  refreshInterval?: number,
) {
  let cache: { value: T; expiry: number } | null = null;
  let refreshTimer: NodeJS.Timeout | null = null;

  const execute = async (): Promise<T> => {
    const now = Date.now();

    if (cache && now < cache.expiry) {
      return cache.value;
    }

    const value = await fn();
    cache = { value, expiry: now + ttl };
    return value;
  };

  const refresh = async (): Promise<void> => {
    const value = await fn();
    cache = { value, expiry: Date.now() + ttl };
  };

  const clear = () => {
    cache = null;
    if (refreshTimer) {
      clearInterval(refreshTimer);
      refreshTimer = null;
    }
  };

  // 设置自动刷新
  if (refreshInterval) {
    refreshTimer = setInterval(() => {
      refresh().catch(console.error);
    }, refreshInterval);
  }

  return {
    execute,
    refresh,
    clear,
    get cached() {
      return cache;
    },
  };
}

// ==================== 导出 es-toolkit 函数 ====================

export { memoize, once };
