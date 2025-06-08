// src/stores/authStore.ts
import { writable } from 'svelte/store';
import { useTauriStorage } from '$lib/hooks/useTauriStorage';

const STORAGE_KEY = 'auth-storage';

type AuthState = {
  token: string | null;
  user: any | null;
  rememberMe: boolean;
};

const defaultState: AuthState = {
  token: null,
  user: null,
  rememberMe: false,
};

function createAuthStore() {
  const { subscribe, set, update } = writable<AuthState>(defaultState);

  async function load() {
    const saved = await useTauriStorage.get<AuthState>(STORAGE_KEY);
    if (saved) set(saved);
  }

  async function persist(state: AuthState) {
    await useTauriStorage.set<AuthState>(STORAGE_KEY, state);
  }

  return {
    subscribe,

    // 初始化
    init: async () => {
      await load();
    },

    // 完整设置（登录）
    setAuth: async (token: string, user: any, rememberMe: boolean) => {
      const newState = { token, user, rememberMe };
      set(newState);
      await persist(newState);
    },

    // 登出
    logout: async () => {
      set(defaultState);
      await useTauriStorage.remove(STORAGE_KEY);
    },

    // ✅ 局部更新方法
    setToken: async (token: string | null) => {
      update((state) => {
        const newState = { ...state, token };
        persist(newState);
        return newState;
      });
    },

    setUser: async (user: any | null) => {
      update((state) => {
        const newState = { ...state, user };
        persist(newState);
        return newState;
      });
    },

    setRememberMe: async (rememberMe: boolean) => {
      update((state) => {
        const newState = { ...state, rememberMe };
        persist(newState);
        return newState;
      });
    },
  };
}

export const authStore = createAuthStore();
