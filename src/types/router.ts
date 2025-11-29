/**
 * 路由类型扩展
 */
import type { Permission, Role } from './auth';

/**
 * 扩展 vue-router 的 RouteMeta 接口
 */
declare module 'vue-router' {
  interface RouteMeta {
    /** 是否需要登录认证 */
    requiresAuth?: boolean;

    /** 需要的权限（满足任一即可访问） */
    permissions?: Permission[];

    /** 需要的角色（满足任一即可访问） */
    roles?: Role[];

    /** 页面标题 */
    title?: string;

    /** 是否在菜单中隐藏 */
    hidden?: boolean;

    /** 页面图标 */
    icon?: string;

    /** 面包屑 */
    breadcrumb?: boolean;

    /** 是否缓存页面 */
    keepAlive?: boolean;
  }
}

export {};
