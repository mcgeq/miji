/**
 * 平台检测工具函数
 * 用于检测设备类型（而非屏幕尺寸）
 * 主要用于系统功能控制，如系统托盘、关闭行为等
 */

/**
 * 统一的移动设备检测函数
 * 避免在多个文件中重复相同的检测逻辑
 * @returns {boolean} 是否为移动设备
 */
export function detectMobileDevice(): boolean {
  if (typeof window === 'undefined') return false;
  const userAgent = navigator.userAgent.toLowerCase();
  return /android|iphone|ipad|ipod|blackberry|iemobile|opera mini/i.test(userAgent);
}

/**
 * 检测是否为桌面端
 * @returns {boolean} 是否为桌面端
 */
export function isDesktop(): boolean {
  return !detectMobileDevice();
}

/**
 * 检测是否为移动设备
 * @returns {boolean} 是否为移动设备
 */
export function isMobile(): boolean {
  return detectMobileDevice();
}

/**
 * 检测是否为Tauri环境
 * @returns {boolean} 是否为Tauri环境
 */
export function isTauri(): boolean {
  return typeof window !== 'undefined' && '__TAURI__' in window;
}
