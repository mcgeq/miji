// src/bootstrap/app-bootstrapper.ts
import type { App } from 'vue';
import { PlatformService } from '@/services/platform-service';
import { Lg } from '@/utils/debugLog';
import { showBootstrapErrorPage } from '@/utils/errorPage';
import { SplashscreenManager } from './splashscreen-manager';
import { StoreInitializer } from './store-initializer';
import { ThemeInitializer } from './theme-initializer';

/**
 * 应用启动器
 * 负责统一管理应用的启动流程
 */
export class AppBootstrapper {
  private splashManager: SplashscreenManager;
  private storeInitializer: StoreInitializer;
  private themeInitializer: ThemeInitializer;

  constructor() {
    this.splashManager = new SplashscreenManager();
    this.storeInitializer = new StoreInitializer();
    this.themeInitializer = new ThemeInitializer();
  }

  /**
   * 启动应用
   * @param app - Vue 应用实例
   */
  async bootstrap(app: App): Promise<void> {
    try {
      Lg.i('Bootstrap', 'Starting application bootstrap...');

      // 1. 显示启动画面（仅移动端）
      if (PlatformService.isMobile()) {
        this.splashManager.show();
      }

      // 2. 等待 DOM 准备
      await this.waitForDOMReady();

      // 3. 平台特定延迟
      await PlatformService.delay(100, 0);

      // 4. 初始化 Stores
      await this.storeInitializer.initialize();

      // 5. 初始化主题
      await this.themeInitializer.initialize();

      // 6. 挂载应用
      Lg.i('Bootstrap', 'Mounting Vue app...');
      app.mount('#app');

      // 7. 后处理
      await this.postMount();

      // 8. 关闭启动画面
      if (PlatformService.isMobile()) {
        this.splashManager.closeAfterDelay(500);
      }

      Lg.i('Bootstrap', 'Application bootstrap completed successfully');
    } catch (error) {
      this.handleBootstrapError(error);
    }
  }

  /**
   * 等待 DOM 准备就绪
   */
  private async waitForDOMReady(): Promise<void> {
    return new Promise(resolve => {
      if (document.readyState === 'complete') {
        resolve();
      } else {
        const onReady = () => {
          document.removeEventListener('DOMContentLoaded', onReady);
          window.removeEventListener('load', onReady);
          resolve();
        };

        document.addEventListener('DOMContentLoaded', onReady);
        window.addEventListener('load', onReady);
      }
    });
  }

  /**
   * 应用挂载后的处理
   */
  private async postMount(): Promise<void> {
    // 确保样式正确应用
    await new Promise(resolve => setTimeout(resolve, 100));

    // 验证 CSS 是否正常工作
    this.validateCSS();

    // Tauri 特定处理
    if (PlatformService.isTauri()) {
      this.setupTauriHandlers();
    }
  }

  /**
   * 验证 CSS 工具类是否正常工作
   */
  private validateCSS(): void {
    const testElement = document.createElement('div');
    testElement.className = 'hidden';
    testElement.style.visibility = 'visible';
    document.body.appendChild(testElement);

    const computed = window.getComputedStyle(testElement);
    if (computed.display !== 'none') {
      console.warn('CSS utilities may not be working correctly');
    }

    document.body.removeChild(testElement);
  }

  /**
   * 设置 Tauri 特定的事件处理器
   */
  private setupTauriHandlers(): void {
    // 防止右键菜单（桌面端）
    if (PlatformService.isDesktop()) {
      document.addEventListener('contextmenu', e => {
        e.preventDefault();
        return false;
      });
    }

    // 防止拖拽
    document.addEventListener('dragover', e => e.preventDefault());
    document.addEventListener('drop', e => e.preventDefault());
  }

  /**
   * 处理启动错误
   */
  private handleBootstrapError(error: unknown): void {
    console.error('Failed to bootstrap app:', error);
    Lg.e('Bootstrap', 'Bootstrap failed:', error);

    // 关闭启动画面
    this.splashManager.close();

    // 显示错误页面
    showBootstrapErrorPage(error, {
      title: '应用启动失败',
      message: '应用启动时发生错误，请重新加载应用。',
      showDetails: import.meta.env.DEV || import.meta.env.MODE === 'development',
      showReloadButton: true,
    });
  }
}
