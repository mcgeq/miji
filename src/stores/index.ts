// src/lib/stores/index.ts
import { Lg } from '../utils/debugLog';
import { useAuthStore } from './auth';
import { useLocaleStore } from './locales';
import { useThemeStore } from './theme';

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
    // 检测是否为移动端
    const isMobile = /Android|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(
      navigator.userAgent,
    );

    // 获取 store 实例
    const authStore = useAuthStore();
    const localeStore = useLocaleStore();
    const themeStore = useThemeStore();

    // 移动端优化：使用超时处理，避免无限等待
    if (isMobile) {
      try {
        await Promise.race([
          Promise.all([
            authStore.$tauri.start(),
            localeStore.$tauri.start(),
            themeStore.$tauri.start(),
          ]),
          new Promise((_, reject) =>
            setTimeout(() => reject(new Error('Store initialization timeout')), 2000),
          ),
        ]);
      } catch (error) {
        Lg.w('Store', 'Store initialization timed out or failed, continuing with fallback:', error);
        // 移动端超时后继续，不阻塞应用启动
        return;
      }
    } else {
      // 桌面端正常初始化
      await Promise.all([
        authStore.$tauri.start(),
        localeStore.$tauri.start(),
        themeStore.$tauri.start(),
      ]);
    }

    Lg.i('Store', 'Stores initialized successfully');
    Lg.i('Store', 'Auth store loaded:', {
      hasUser: !!authStore.user,
      hasToken: !!authStore.token,
      rememberMe: authStore.rememberMe,
    });
    Lg.i('Store', 'Theme store loaded:', {
      currentTheme: themeStore.currentTheme,
      effectiveTheme: themeStore.effectiveTheme,
    });
  } catch (error) {
    Lg.e('Store', 'Store initialization failed:', error);
    // 移动端不抛出错误，让应用继续启动
    const isMobile = /Android|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(
      navigator.userAgent,
    );
    if (!isMobile) {
      throw error;
    }
  }
}
