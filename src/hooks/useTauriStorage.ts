import { load, type Store } from '@tauri-apps/plugin-store';
import type { StateStorage } from 'zustand/middleware';

let storePromise: Promise<Store> | null = null;

function getStore() {
  if (!storePromise) {
    storePromise = load('.settings.json', { autoSave: false });
  }
  return storePromise;
}

export const useTauriStorage = {
  async get<T = unknown>(key: string): Promise<T | null> {
    const store = await getStore();
    const value = await store.get<T>(key);
    return value ?? null;
  },

  async set<T = unknown>(key: string, value: T): Promise<void> {
    const store = await getStore();
    await store.set(key, value);
    await store.save();
  },

  async remove(key: string): Promise<void> {
    const store = await getStore();
    await store.delete(key);
    await store.save();
  },

  async clear(): Promise<void> {
    const store = await getStore();
    await store.clear();
    await store.save();
  },

  async keys(): Promise<string[]> {
    const store = await getStore();
    return await store.keys();
  },

  async has(key: string): Promise<boolean> {
    const store = await getStore();
    const keys = await store.keys();
    return keys.includes(key);
  },
};

export function createTauriStorage(): StateStorage {
  return {
    getItem: async (key: string): Promise<string | null> => {
      const value = await useTauriStorage.get<string>(key);
      return value ?? null;
    },

    setItem: async (key: string, value: string): Promise<void> => {
      await useTauriStorage.set(key, value);
    },

    removeItem: async (key: string): Promise<void> => {
      await useTauriStorage.remove(key);
    },
  };
}
