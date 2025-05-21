import { load, type Store } from '@tauri-apps/plugin-store';
import type { PersistStorage, StorageValue } from 'zustand/middleware';

let storePromise: Promise<Store> | null = null;

function getStore() {
  if (!storePromise) {
    storePromise = load('.settings.json', { autoSave: false }).catch(
      (error) => {
        console.error('[useTauriStorage] Failed to load store:', error);
        throw error;
      },
    );
  }
  return storePromise;
}

export const useTauriStorage = {
  async get<T = unknown>(key: string): Promise<T | null> {
    try {
      const store = await getStore();
      const value = await store.get<T>(key);
      return value ?? null;
    } catch (error) {
      console.error(`[useTauriStorage] Failed to get key "${key}":`, error);
      return null;
    }
  },
  async set<T = unknown>(key: string, value: T): Promise<void> {
    try {
      const store = await getStore();
      await store.set(key, value);
      await store.save();
    } catch (error) {
      console.error(`[useTauriStorage] Failed to set key "${key}":`, error);
    }
  },
  async remove(key: string): Promise<void> {
    try {
      const store = await getStore();
      await store.delete(key);
      await store.save();
    } catch (error) {
      console.error(`[useTauriStorage] Failed to remove key "${key}":`, error);
    }
  },
};

export function createTauriStorage<S>(): PersistStorage<S> {
  return {
    async getItem(key: string): Promise<StorageValue<S> | null> {
      const value = await useTauriStorage.get<string>(key);
      if (!value) return null;
      try {
        return JSON.parse(value) as StorageValue<S>;
      } catch (e) {
        console.error(`[createTauriStorage] Failed to parse key "${key}":`, e);
        return null;
      }
    },

    async setItem(key: string, value: StorageValue<S>): Promise<void> {
      try {
        const str = JSON.stringify(value);
        await useTauriStorage.set(key, str);
      } catch (e) {
        console.error(
          `[createTauriStorage] Failed to stringify key "${key}":`,
          e,
        );
      }
    },

    async removeItem(key: string): Promise<void> {
      await useTauriStorage.remove(key);
    },
  };
}
