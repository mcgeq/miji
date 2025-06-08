// src/hooks/tauriStorage.ts
import { load, type Store } from '@tauri-apps/plugin-store';

let storePromise: Promise<Store> | null = null;

/**
 * 获取持久化 store 实例（单例）
 */
async function getStore(): Promise<Store> {
  if (!storePromise) {
    storePromise = load('.settings.json', { autoSave: false }).catch(
      (error) => {
        console.error('[tauriStorage] Failed to load store:', error);
        throw error;
      },
    );
  }
  return storePromise;
}

/**
 * 提供与 localStorage 类似的异步 API，内部使用 plugin-store 实现
 */
export const useTauriStorage = {
  async get<T = unknown>(key: string): Promise<T | null> {
    try {
      const store = await getStore();
      const value = await store.get(key);
      if (value === null || value === undefined) return null;
      if (typeof value === 'string') {
        try {
          return JSON.parse(value) as T;
        } catch {
          return value as T;
        }
      }
      return value as T;
    } catch (error) {
      console.error(`[tauriStorage] get("${key}") error:`, error);
      return null;
    }
  },

  async set<T = unknown>(key: string, value: T): Promise<void> {
    try {
      const store = await getStore();
      const storeValue =
        typeof value === 'object' && value !== null
          ? JSON.stringify(value)
          : value;
      await store.set(key, storeValue);
      await store.save();
    } catch (error) {
      console.error(`[tauriStorage] set("${key}") error:`, error);
    }
  },

  async remove(key: string): Promise<void> {
    try {
      const store = await getStore();
      await store.delete(key);
      await store.save();
    } catch (error) {
      console.error(`[tauriStorage] remove("${key}") error:`, error);
    }
  },

  async clear(): Promise<void> {
    try {
      const store = await getStore();
      await store.clear();
      await store.save();
    } catch (error) {
      console.error('[tauriStorage] clear() error:', error);
    }
  },
};
