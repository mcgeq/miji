/**
 * 统一的 TTL (Time-To-Live) 缓存实现
 *
 * 支持：
 * - 过期时间控制
 * - LRU 驱逐策略
 * - 自动清理
 * - 过期回调
 *
 * 替代：
 * - simpleCache.ts 的 SimpleCache
 * - apiHelper.ts 的 ApiCache
 */

import type { CacheEntry, TTLCacheOptions } from './types';

/**
 * TTL 缓存类
 *
 * @template T - 缓存数据类型
 *
 * @example
 * // 创建缓存实例
 * const cache = new TTLCache<User>({
 *   defaultTTL: 5 * 60 * 1000, // 5分钟
 *   maxSize: 100,
 * });
 *
 * // 设置和获取
 * cache.set('user:123', userData);
 * const user = cache.get('user:123');
 *
 * // 自定义 TTL
 * cache.set('temp', tempData, 1000); // 1秒后过期
 */
export class TTLCache<T = unknown> {
  private cache = new Map<string, CacheEntry<T>>();
  private readonly options: Required<TTLCacheOptions>;

  constructor(options: TTLCacheOptions = {}) {
    this.options = {
      defaultTTL: options.defaultTTL ?? 5 * 60 * 1000, // 默认 5 分钟
      maxSize: options.maxSize ?? Number.POSITIVE_INFINITY,
      onExpire: options.onExpire ?? (() => {}),
    };
  }

  /**
   * 设置缓存
   *
   * @param key - 缓存键
   * @param data - 缓存数据
   * @param ttl - 可选的自定义 TTL（毫秒）
   */
  set(key: string, data: T, ttl?: number): void {
    // LRU 驱逐策略：如果达到最大大小，删除最旧的条目
    if (this.cache.size >= this.options.maxSize) {
      const firstKey = this.cache.keys().next().value;
      if (firstKey !== undefined) {
        this.delete(firstKey);
      }
    }

    const expiry = Date.now() + (ttl ?? this.options.defaultTTL);
    this.cache.set(key, { data, expiry });
  }

  /**
   * 获取缓存
   *
   * @param key - 缓存键
   * @returns 缓存的数据，如果不存在或已过期返回 null
   */
  get(key: string): T | null {
    const entry = this.cache.get(key);
    if (!entry) {
      return null;
    }

    // 检查是否过期
    if (Date.now() > entry.expiry) {
      this.options.onExpire(key, entry.data);
      this.cache.delete(key);
      return null;
    }

    return entry.data;
  }

  /**
   * 检查缓存是否存在且未过期
   *
   * @param key - 缓存键
   * @returns 是否存在
   */
  has(key: string): boolean {
    return this.get(key) !== null;
  }

  /**
   * 删除缓存
   *
   * @param key - 缓存键
   * @returns 是否成功删除
   */
  delete(key: string): boolean {
    return this.cache.delete(key);
  }

  /**
   * 清空所有缓存
   */
  clear(): void {
    this.cache.clear();
  }

  /**
   * 清理所有过期的缓存条目
   *
   * @returns 清理的条目数
   */
  cleanup(): number {
    const now = Date.now();
    let cleanedCount = 0;

    for (const [key, entry] of this.cache.entries()) {
      if (now > entry.expiry) {
        this.options.onExpire(key, entry.data);
        this.cache.delete(key);
        cleanedCount++;
      }
    }

    return cleanedCount;
  }

  /**
   * 获取当前缓存条目数
   *
   * @returns 条目数
   */
  size(): number {
    return this.cache.size;
  }

  /**
   * 获取所有缓存键
   *
   * @returns 键数组
   */
  keys(): string[] {
    return Array.from(this.cache.keys());
  }

  /**
   * 获取所有未过期的缓存条目
   *
   * @returns 键值对数组
   */
  entries(): Array<[string, T]> {
    const now = Date.now();
    const result: Array<[string, T]> = [];

    for (const [key, entry] of this.cache.entries()) {
      if (now <= entry.expiry) {
        result.push([key, entry.data]);
      }
    }

    return result;
  }

  /**
   * 获取所有未过期的缓存值
   *
   * @returns 值数组
   */
  values(): T[] {
    return this.entries().map(([_, value]) => value);
  }
}
