// src/services/platform-service.ts
import { detectMobileDevice } from '@/utils/platform';

/**
 * 平台检测和工具服务
 * 统一管理平台相关的判断逻辑，避免重复代码
 */

// Module-level cache variables
let _isMobile: boolean | null = null;
let _isTauri: boolean | null = null;

/**
 * 检测是否为移动设备
 * 结果会被缓存，多次调用不会重复检测
 */
export function isMobile(): boolean {
  if (_isMobile === null) {
    _isMobile = detectMobileDevice();
  }
  return _isMobile;
}

/**
 * 检测是否在 Tauri 环境中运行
 */
export function isTauri(): boolean {
  if (_isTauri === null) {
    _isTauri = '__TAURI__' in window;
  }
  return _isTauri;
}

/**
 * 检测是否为桌面平台
 */
export function isDesktop(): boolean {
  return !isMobile();
}

/**
 * 根据平台执行带超时的Promise
 * @param promise - 要执行的Promise
 * @param mobileTimeout - 移动端超时时间（毫秒）
 * @param desktopTimeout - 桌面端超时时间（毫秒）
 */
export async function executeWithTimeout<T>(
  promise: Promise<T>,
  mobileTimeout: number,
  desktopTimeout: number,
): Promise<T> {
  const timeout = isMobile() ? mobileTimeout : desktopTimeout;

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
export function getDelay(mobileDelay: number, desktopDelay: number): number {
  return isMobile() ? mobileDelay : desktopDelay;
}

/**
 * 根据平台执行不同的延迟
 * @param mobileDelay - 移动端延迟（毫秒）
 * @param desktopDelay - 桌面端延迟（毫秒）
 */
export async function delay(mobileDelay: number, desktopDelay: number): Promise<void> {
  const delayTime = getDelay(mobileDelay, desktopDelay);
  return new Promise(resolve => setTimeout(resolve, delayTime));
}

/**
 * 根据平台返回不同的配置值
 * @param mobileValue - 移动端值
 * @param desktopValue - 桌面端值
 */
export function getValue<T>(mobileValue: T, desktopValue: T): T {
  return isMobile() ? mobileValue : desktopValue;
}

/**
 * 重置缓存（用于测试）
 */
export function resetCache(): void {
  _isMobile = null;
  _isTauri = null;
}

// Legacy export for backward compatibility
export const PlatformService = {
  isMobile,
  isTauri,
  isDesktop,
  executeWithTimeout,
  getDelay,
  delay,
  getValue,
  resetCache,
};
