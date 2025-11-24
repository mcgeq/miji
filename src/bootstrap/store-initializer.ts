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
    Lg.i('StoreInit', '开始初始化 Stores...');

    Lg.i('StoreInit', '获取 Store 实例...');
    const authStore = useAuthStore();
    const localeStore = useLocaleStore();
    const themeStore = useThemeStore();
    Lg.i('StoreInit', '✓ Store 实例获取完成');

    try {
      const isMobile = PlatformService.isMobile();
      Lg.i('StoreInit', `平台: ${isMobile ? '移动端' : '桌面端'}`);

      if (isMobile) {
        Lg.i('StoreInit', '移动端: 使用超时处理 (2秒)...');
        // 移动端使用超时处理，避免无限等待
        await PlatformService.executeWithTimeout(
          this.startStores(authStore, localeStore, themeStore),
          2000, // 移动端2秒超时
          5000, // 桌面端5秒超时（此处不会用到）
        );
      } else {
        Lg.i('StoreInit', '桌面端: 正常初始化...');
        // 桌面端正常初始化
        await this.startStores(authStore, localeStore, themeStore);
      }

      Lg.i('StoreInit', '✓ Stores 初始化成功');
      this.logStoreState(authStore, themeStore);
    } catch (error) {
      Lg.e('StoreInit', 'Store 初始化失败:', error);

      // 移动端失败不阻塞启动
      if (PlatformService.isMobile()) {
        Lg.w('StoreInit', '移动端: 使用降级模式继续启动');
        return;
      }

      Lg.e('StoreInit', '桌面端初始化失败，抛出错误');
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
    Lg.i('StoreInit', '并行启动 Auth/Locale/Theme Store...');

    try {
      await Promise.all([
        (async () => {
          Lg.i('StoreInit', '  > Auth Store 启动中...');
          await authStore.$tauri.start();
          Lg.i('StoreInit', '  ✓ Auth Store 启动完成');
        })(),
        (async () => {
          Lg.i('StoreInit', '  > Locale Store 启动中...');
          await localeStore.$tauri.start();
          Lg.i('StoreInit', '  ✓ Locale Store 启动完成');
        })(),
        (async () => {
          Lg.i('StoreInit', '  > Theme Store 启动中...');
          await themeStore.$tauri.start();
          Lg.i('StoreInit', '  ✓ Theme Store 启动完成');
        })(),
      ]);

      Lg.i('StoreInit', '✓ 所有 Store 启动完成');
    } catch (error) {
      Lg.e('StoreInit', 'Store 启动过程中出错:', error);
      throw error;
    }
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
