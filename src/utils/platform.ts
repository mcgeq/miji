/**
 * 平台检测工具函数
 */

/**
 * 检测是否为桌面端
 * @returns {boolean} 是否为桌面端
 */
export function isDesktop(): boolean {
  // 在Tauri环境中，可以通过检查window.__TAURI__来判断
  if (typeof window !== 'undefined' && '__TAURI__' in window) {
    // 在Tauri环境中，通过检查用户代理字符串来判断平台
    const userAgent = navigator.userAgent.toLowerCase();
    const isMobile = /android|iphone|ipad|ipod|blackberry|iemobile|opera mini/i.test(userAgent);
    return !isMobile;
  }

  // 在非Tauri环境中，通过用户代理字符串判断
  const userAgent = navigator.userAgent.toLowerCase();
  const isMobile = /android|iphone|ipad|ipod|blackberry|iemobile|opera mini/i.test(userAgent);
  return !isMobile;
}

/**
 * 检测是否为移动端
 * @returns {boolean} 是否为移动端
 */
export function isMobile(): boolean {
  return !isDesktop();
}

/**
 * 检测是否为Tauri环境
 * @returns {boolean} 是否为Tauri环境
 */
export function isTauri(): boolean {
  return typeof window !== 'undefined' && '__TAURI__' in window;
}
