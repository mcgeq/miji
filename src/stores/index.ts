import { PlatformService } from '../services/platform-service';
// src/stores/index.ts
import { Lg } from '../utils/debugLog';
import { useAuthStore } from './auth';
import { useLocaleStore } from './locales';
import { useThemeStore } from './theme';

let isStarted = false;

/**
 * 初始化并启动所有 Tauri stores
 *
 * 注意：此函数已被 bootstrap/store-initializer.ts 替代
 * 保留此函数是为了向后兼容
 *
 * @deprecated 请使用 StoreInitializer 类
 */
export async function storeStart() {
  if (isStarted) return;
  isStarted = true;

  try {
    // 获取 store 实例
    const authStore = useAuthStore();
    const localeStore = useLocaleStore();
    const themeStore = useThemeStore();

    // 移动设备优化：使用超时处理
    if (PlatformService.isMobile()) {
      try {
        await PlatformService.executeWithTimeout(
          Promise.all([
            authStore.$tauri.start(),
            localeStore.$tauri.start(),
            themeStore.$tauri.start(),
          ]),
          2000, // 移动端2秒超时
          5000, // 桌面端5秒超时
        );
      } catch (error) {
        Lg.w('Store', 'Store initialization timed out, continuing with fallback:', error);
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

    // 移动设备不抛出错误，让应用继续启动
    if (!PlatformService.isMobile()) {
      throw error;
    }
  }
}
