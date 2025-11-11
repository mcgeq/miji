// src/services/platform-service.ts
import { detectMobileDevice } from '@/utils/platform';

/**
 * 平台检测和工具服务
 * 统一管理平台相关的判断逻辑，避免重复代码
 */
export class PlatformService {
  private static _isMobile: boolean | null = null;
  private static _isTauri: boolean | null = null;

  /**
   * 检测是否为移动设备
   * 结果会被缓存，多次调用不会重复检测
   */
  static isMobile(): boolean {
    if (this._isMobile === null) {
      this._isMobile = detectMobileDevice();
    }
    return this._isMobile;
  }

  /**
   * 检测是否在 Tauri 环境中运行
   */
  static isTauri(): boolean {
    if (this._isTauri === null) {
      this._isTauri = '__TAURI__' in window;
    }
    return this._isTauri;
  }

  /**
   * 检测是否为桌面平台
   */
  static isDesktop(): boolean {
    return !this.isMobile();
  }

  /**
   * 根据平台执行带超时的Promise
   * @param promise - 要执行的Promise
   * @param mobileTimeout - 移动端超时时间（毫秒）
   * @param desktopTimeout - 桌面端超时时间（毫秒）
   */
  static async executeWithTimeout<T>(
    promise: Promise<T>,
    mobileTimeout: number,
    desktopTimeout: number,
  ): Promise<T> {
    const timeout = this.isMobile() ? mobileTimeout : desktopTimeout;

    return Promise.race([
      promise,
      new Promise<T>((_, reject) =>
        setTimeout(() => reject(new Error('Operation timeout')), timeout),
      ),
    ]);
  }

  /**
   * 根据平台返回不同的延迟时间
   * @param mobileDelay - 移动端延迟（毫秒）
   * @param desktopDelay - 桌面端延迟（毫秒）
   */
  static getDelay(mobileDelay: number, desktopDelay: number): number {
    return this.isMobile() ? mobileDelay : desktopDelay;
  }

  /**
   * 根据平台执行不同的延迟
   * @param mobileDelay - 移动端延迟（毫秒）
   * @param desktopDelay - 桌面端延迟（毫秒）
   */
  static async delay(mobileDelay: number, desktopDelay: number): Promise<void> {
    const delay = this.getDelay(mobileDelay, desktopDelay);
    return new Promise(resolve => setTimeout(resolve, delay));
  }

  /**
   * 根据平台返回不同的配置值
   * @param mobileValue - 移动端值
   * @param desktopValue - 桌面端值
   */
  static getValue<T>(mobileValue: T, desktopValue: T): T {
    return this.isMobile() ? mobileValue : desktopValue;
  }

  /**
   * 重置缓存（用于测试）
   */
  static resetCache(): void {
    this._isMobile = null;
    this._isTauri = null;
  }
}
