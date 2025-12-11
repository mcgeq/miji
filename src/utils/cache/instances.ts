/**
 * 全局缓存实例
 *
 * 替代：
 * - simpleCache.ts 的 globalCache
 * - apiHelper.ts 的 ApiCache
 */

import { TTLCache } from './TTLCache';

// ==================== 全局缓存实例 ====================

/**
 * 全局数据缓存
 *
 * 用途：通用数据缓存，默认 5 分钟 TTL
 *
 * @example
 * // 缓存用户数据
 * globalCache.set('user:123', userData);
 * const user = globalCache.get('user:123');
 */
export const globalCache = new TTLCache({
  defaultTTL: 5 * 60 * 1000, // 5分钟
  maxSize: 100, // 最多 100 个条目
});

/**
 * API 请求缓存
 *
 * 用途：缓存 API 请求结果，默认 5 分钟 TTL
 *
 * @example
 * // 缓存 API 响应
 * const key = apiCache.generateKey('getUser', { id: '123' });
 * apiCache.set(key, responseData);
 * const cached = apiCache.get(key);
 */
export const apiCache = new TTLCache({
  defaultTTL: 5 * 60 * 1000, // 5分钟
  maxSize: 50, // 最多 50 个条目（API 请求通常较大）
});

// ==================== 缓存键生成器 ====================

/**
 * 统一的缓存键生成器
 *
 * 提供标准化的缓存键生成方法
 */
export const cacheKeys = {
  // ========== 家庭账本相关 ==========
  familyLedgers: () => 'family_ledgers',
  familyLedger: (id: string) => `family_ledger:${id}`,
  familyMembers: (ledgerId?: string) =>
    ledgerId ? `family_members:${ledgerId}` : 'family_members',
  familyMember: (id: string) => `family_member:${id}`,

  // ========== 分摊相关 ==========
  splitRules: (ledgerId?: string) => (ledgerId ? `split_rules:${ledgerId}` : 'split_rules'),
  debtRelations: (ledgerId: string) => `debt_relations:${ledgerId}`,
  settlementSuggestions: (ledgerId: string) => `settlement_suggestions:${ledgerId}`,
  settlementRecords: (ledgerId: string) => `settlement_records:${ledgerId}`,

  // ========== 统计数据 ==========
  familyStats: (ledgerId: string) => `family_stats:${ledgerId}`,

  // ========== API 请求 ==========
  /**
   * 生成 API 请求缓存键
   *
   * @param method - API 方法名
   * @param params - 请求参数
   * @returns 缓存键
   *
   * @example
   * const key = cacheKeys.api('getUser', { id: '123' });
   * // 'api:getUser:{"id":"123"}'
   */
  api: (method: string, params?: unknown) => {
    if (params) {
      return `api:${method}:${JSON.stringify(params)}`;
    }
    return `api:${method}`;
  },
};

// ==================== 定期清理 ====================

/**
 * 定期清理过期缓存
 * 每分钟执行一次
 */
const cleanupInterval = setInterval(() => {
  const globalCleaned = globalCache.cleanup();
  const apiCleaned = apiCache.cleanup();

  if (globalCleaned > 0 || apiCleaned > 0) {
    console.debug(`[Cache] Cleaned up ${globalCleaned + apiCleaned} expired entries`);
  }
}, 60000); // 每分钟清理一次

/**
 * 清理定时器（用于测试或应用卸载）
 */
export function stopCacheCleanup() {
  clearInterval(cleanupInterval);
}
