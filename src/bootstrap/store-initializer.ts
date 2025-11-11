import { PlatformService } from '@/services/platform-service';
import { useAuthStore } from '@/stores/auth';
import { useLocaleStore } from '@/stores/locales';
import { useThemeStore } from '@/stores/theme';
// src/bootstrap/store-initializer.ts
import { Lg } from '@/utils/debugLog';

/**
 * Store 初始化器
 * 负责所有 Pinia Store 的启动和初始化
 */
export class StoreInitializer {
  /**
   * 初始化所有必需的 Store
   */
  async initialize(): Promise<void> {
    const authStore = useAuthStore();
    const localeStore = useLocaleStore();
    const themeStore = useThemeStore();

    try {
      if (PlatformService.isMobile()) {
        // 移动端使用超时处理，避免无限等待
        await PlatformService.executeWithTimeout(
          this.startStores(authStore, localeStore, themeStore),
          2000, // 移动端2秒超时
          5000, // 桌面端5秒超时（此处不会用到）
        );
      } else {
        // 桌面端正常初始化
        await this.startStores(authStore, localeStore, themeStore);
      }

      Lg.i('Bootstrap', 'Stores initialized successfully');
      this.logStoreState(authStore, themeStore);
    } catch (error) {
      Lg.w('Bootstrap', 'Store initialization failed:', error);

      // 移动端失败不阻塞启动
      if (PlatformService.isMobile()) {
        Lg.i('Bootstrap', 'Mobile device: continuing with fallback');
        return;
      }

      throw error;
    }
  }

  /**
   * 启动所有 Store
   */
  private async startStores(
    authStore: ReturnType<typeof useAuthStore>,
    localeStore: ReturnType<typeof useLocaleStore>,
    themeStore: ReturnType<typeof useThemeStore>,
  ): Promise<void> {
    await Promise.all([
      authStore.$tauri.start(),
      localeStore.$tauri.start(),
      themeStore.$tauri.start(),
    ]);
  }

  /**
   * 记录 Store 状态（用于调试）
   */
  private logStoreState(
    authStore: ReturnType<typeof useAuthStore>,
    themeStore: ReturnType<typeof useThemeStore>,
  ): void {
    Lg.i('Bootstrap', 'Auth store loaded:', {
      hasUser: !!authStore.user,
      hasToken: !!authStore.token,
      rememberMe: authStore.rememberMe,
    });

    Lg.i('Bootstrap', 'Theme store loaded:', {
      currentTheme: themeStore.currentTheme,
      effectiveTheme: themeStore.effectiveTheme,
    });
  }
}
