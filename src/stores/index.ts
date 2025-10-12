// src/lib/stores/index.ts
import { Lg } from '../utils/debugLog';
import { useAuthStore } from './auth';
import { useLocaleStore } from './locales';

let isStarted = false;

export async function storeStart() {
  if (isStarted) return;
  isStarted = true;

  try {
    // 获取 store 实例
    const authStore = useAuthStore();
    const localeStore = useLocaleStore();

    // 初始化所有 stores 的持久化和同步
    await Promise.all([
      authStore.$tauri.start(),
      localeStore.$tauri.start(),
    ]);

    Lg.i('Store', 'Stores initialized successfully');
  } catch (error) {
    Lg.e('Store', 'Store initialization failed:', error);
    throw error;
  }
}
