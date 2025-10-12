// src/lib/stores/index.ts
import { Lg } from '../utils/debugLog';
import { useAuthStore } from './auth';
import { useLocaleStore } from './locales';

let isStarted = false;

/**
 * 初始化并启动所有 Tauri stores
 *
 * 使用官方推荐的 saveOnChange 配置来自动保存状态变化
 * 文档：https://tb.dev.br/tauri-store/plugin-pinia/guide/persisting-state
 */
export async function storeStart() {
  if (isStarted) return;
  isStarted = true;

  try {
    // 获取 store 实例
    const authStore = useAuthStore();
    const localeStore = useLocaleStore();

    // 初始化所有 stores 的持久化和同步
    // saveOnChange: true 会自动处理状态变化的保存（使用防抖策略）
    await Promise.all([
      authStore.$tauri.start(),
      localeStore.$tauri.start(),
    ]);

    Lg.i('Store', 'Stores initialized successfully');
    Lg.i('Store', 'Auth store loaded:', {
      hasUser: !!authStore.user,
      hasToken: !!authStore.token,
      rememberMe: authStore.rememberMe,
    });
  } catch (error) {
    Lg.e('Store', 'Store initialization failed:', error);
    throw error;
  }
}
