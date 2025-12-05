/**
 * 首次启动路由守卫
 * @description 检测用户是否首次启动应用，如果是则重定向到欢迎页面
 */

import type { NavigationGuardNext, RouteLocationNormalized } from 'vue-router';

const FIRST_LAUNCH_KEY = 'app.first_launch_completed';

/**
 * 首次启动守卫
 */
export async function firstLaunchGuard(
  to: RouteLocationNormalized,
  _from: RouteLocationNormalized,
  next: NavigationGuardNext
) {
  // 如果目标路由已经是欢迎页，直接通过
  if (to.path === '/welcome') {
    next();
    return;
  }

  // 如果是登录或注册页面，也直接通过
  if (to.path.startsWith('/auth')) {
    next();
    return;
  }

  try {
    // 检查是否已完成首次启动
    const completed = localStorage.getItem(FIRST_LAUNCH_KEY) === 'true';

    if (!completed) {
      // 首次启动，重定向到欢迎页
      console.log('🎉 检测到首次启动，跳转到欢迎页面');
      next({ path: '/welcome', replace: true });
    } else {
      // 不是首次启动，正常通过
      next();
    }
  } catch (error) {
    console.error('❌ 首次启动检测失败:', error);
    // 发生错误时正常通过，避免阻塞用户
    next();
  }
}
