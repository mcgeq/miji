// src/lib/stores/index.ts
import { Lg } from '../utils/debugLog';
import { authStore } from './auth';
import { localeStore } from './locales';

let isStarted = false;

export async function storeStart() {
  if (isStarted) return;
  isStarted = true;

  try {
    // 初始化 authStore 和 localeStore
    await Promise.all([authStore.$tauri.start(), localeStore.$tauri.start()]);
    Lg.i('Store', 'Stores initialized successfully');
  } catch (error) {
    Lg.e('Store', 'Store initialization failed:', error);
    throw error;
  }
}
