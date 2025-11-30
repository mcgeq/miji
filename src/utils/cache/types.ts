/**
 * 缓存系统类型定义
 */

/**
 * 缓存条目接口
 */
export interface CacheEntry<T> {
  /** 缓存的数据 */
  data: T;
  /** 过期时间戳 */
  expiry: number;
}

/**
 * TTL 缓存配置选项
 */
export interface TTLCacheOptions {
  /** 默认 TTL（毫秒），默认 5 分钟 */
  defaultTTL?: number;
  /** 最大缓存条目数，默认无限制 */
  maxSize?: number;
  /** 缓存条目过期时的回调 */
  onExpire?: (key: string, value: any) => void;
}

/**
 * 缓存键生成器类型
 */
export type CacheKeyGenerator<T extends any[] = any[]> = (...args: T) => string;
