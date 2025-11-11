// src/bootstrap/splashscreen-manager.ts
import { closeFrontendSplashscreen, createFrontendSplashscreen } from '@/utils/splashscreen';

/**
 * 启动画面管理器
 * 负责启动画面的显示和关闭
 */
export class SplashscreenManager {
  private splash: HTMLElement | null = null;

  /**
   * 显示启动画面
   */
  show(): void {
    this.splash = createFrontendSplashscreen();
  }

  /**
   * 关闭启动画面
   */
  close(): void {
    if (this.splash) {
      closeFrontendSplashscreen(this.splash);
      this.splash = null;
    }
  }

  /**
   * 延迟关闭启动画面
   * @param delay - 延迟时间（毫秒）
   */
  closeAfterDelay(delay: number): void {
    setTimeout(() => this.close(), delay);
  }
}
