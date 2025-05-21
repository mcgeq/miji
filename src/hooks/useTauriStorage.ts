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
      const value = await store.get(key); // Get raw value from store
      if (value === null || value === undefined) return null;
      // If the value is a string and looks like JSON, parse it
      if (typeof value === 'string') {
        try {
          return JSON.parse(value) as T;
        } catch (e) {
          return value as T; // If parsing fails, return the string as is
        }
      }
      return value as T; // Return non-string values directly
    } catch (error) {
      console.error(`[useTauriStorage] Failed to get key "${key}":`, error);
      return null;
    }
  },
  async set<T = unknown>(key: string, value: T): Promise<void> {
    try {
      const store = await getStore();
      // If the value is an object, stringify it; otherwise, store it as is
      const storeValue =
        typeof value === 'object' && value !== null
          ? JSON.stringify(value)
          : value;
      await store.set(key, storeValue);
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
      const value = await useTauriStorage.get<StorageValue<S>>(key); // Get typed value
      return value ?? null;
    },

    async setItem(key: string, value: StorageValue<S>): Promise<void> {
      try {
        const str = JSON.stringify(value); // Stringify the value
        await useTauriStorage.set(key, str); // Store as string
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
