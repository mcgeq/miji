// utils/simpleCache.ts
/**
 * 简单的内存缓存实现
 */

interface CacheEntry {
  data: any;
  expiry: number;
}

class SimpleCache {
  private cache = new Map<string, CacheEntry>();
  private defaultTTL = 5 * 60 * 1000; // 5分钟

  set(key: string, data: any, ttl?: number): void {
    const expiry = Date.now() + (ttl || this.defaultTTL);
    this.cache.set(key, { data, expiry });
  }

  get(key: string): any | null {
    const entry = this.cache.get(key);

    if (!entry) {
      return null;
    }

    if (Date.now() > entry.expiry) {
      this.cache.delete(key);
      return null;
    }

    return entry.data;
  }

  has(key: string): boolean {
    return this.get(key) !== null;
  }

  delete(key: string): boolean {
    return this.cache.delete(key);
  }

  clear(): void {
    this.cache.clear();
  }

  cleanup(): void {
    const now = Date.now();
    for (const [key, entry] of this.cache.entries()) {
      if (now > entry.expiry) {
        this.cache.delete(key);
      }
    }
  }

  size(): number {
    return this.cache.size;
  }
}

// 全局缓存实例
export const globalCache = new SimpleCache();

// 缓存键生成器
export const cacheKeys = {
  familyLedgers: () => 'family_ledgers',
  familyLedger: (id: string) => `family_ledger:${id}`,
  familyMembers: (ledgerId?: string) =>
    ledgerId ? `family_members:${ledgerId}` : 'family_members',
  familyMember: (id: string) => `family_member:${id}`,
  splitRules: (ledgerId?: string) => (ledgerId ? `split_rules:${ledgerId}` : 'split_rules'),
  debtRelations: (ledgerId: string) => `debt_relations:${ledgerId}`,
  settlementSuggestions: (ledgerId: string) => `settlement_suggestions:${ledgerId}`,
  settlementRecords: (ledgerId: string) => `settlement_records:${ledgerId}`,
  familyStats: (ledgerId: string) => `family_stats:${ledgerId}`,
};

// 定期清理过期缓存
setInterval(() => {
  globalCache.cleanup();
}, 60000); // 每分钟清理一次
