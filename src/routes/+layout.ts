// Tauri doesn't have a Node.js server to do proper SSR
// so we will use adapter-static to prerender the app (SSG)
// See: https://v2.tauri.app/start/frontend/sveltekit/ for more info

import { isAuthenticated } from '@/lib/stores/auth';
import type { LayoutLoad } from './$types';
import { redirect } from '@sveltejs/kit';
import { init } from '$lib/i18n/i18n';
import { Lg } from '@/lib/utils/debugLog';
export const prerender = true;
export const ssr = false;

export const load: LayoutLoad = async ({ url }) => {
  Lg.i('Routes', url);
  // 初始化 i18n
  await init();
  const isAuth = await isAuthenticated();
  const pathname = url.pathname;
  const routes = {
    public: ['/auth/login', '/auth/register', '/'],
    protected: [
      '/todos',
      '/profile',
      '/settings',
      '/notes',
      '/money',
      '/health',
      '/checklist',
    ],
    defaultProtected: '/todos',
    login: '/auth/login',
  };
  // 未登录用户访问受保护路由，重定向到登录页面
  if (!isAuth && routes.protected.some((route) => pathname.startsWith(route))) {
    throw redirect(302, routes.login);
  }

  // 已登录用户访问公共路由，重定向到默认受保护路由
  if (isAuth && routes.public.includes(pathname)) {
    throw redirect(302, routes.defaultProtected);
  }
  return {
    isAuthenticated: isAuth,
    pathname, // 返回路径供子布局或页面使用
  };
};
