import { i18nInstance } from '@/i18n/i18n';
import { useAuthStore } from '@/stores/auth';
import { Lg } from '@/utils/debugLog';
import { toast } from '@/utils/toast';
import type { Composer } from 'vue-i18n';
/**
 * 认证路由守卫
 */
import type { NavigationGuardNext, RouteLocationNormalized } from 'vue-router';

/** 白名单路由（不需要认证检查） */
const WHITE_LIST = ['auth-login', 'auth-register', 'splash'];

/** 认证检查缓存（避免重复API调用） */
interface AuthCache {
  isAuth: boolean;
  timestamp: number;
}

let authCheckCache: AuthCache | null = null;

/** 缓存有效期：30秒 */
const CACHE_DURATION = 30000;

/**
 * 认证守卫
 */
export async function authGuard(
  to: RouteLocationNormalized,
  _from: RouteLocationNormalized,
  next: NavigationGuardNext,
) {
  // 获取 i18n 翻译函数
  const t = i18nInstance ? (i18nInstance.global as Composer).t : (key: string) => key;

  const authStore = useAuthStore();
  const routeName = typeof to.name === 'string' ? to.name : '';

  // 1. 检查白名单 - 无需认证
  if (WHITE_LIST.includes(routeName)) {
    next();
    return;
  }

  // 2. 获取认证状态（使用缓存优化性能）
  let isAuth = false;
  try {
    const now = Date.now();

    // 使用缓存（30秒内有效）
    if (authCheckCache && now - authCheckCache.timestamp < CACHE_DURATION) {
      isAuth = authCheckCache.isAuth;
      Lg.d('AuthGuard', 'Using cached auth status:', isAuth);
    } else {
      // 重新检查认证状态
      isAuth = await authStore.checkAuthStatus();
      authCheckCache = { isAuth, timestamp: now };
      Lg.d('AuthGuard', 'Fresh auth check:', isAuth);
    }
  } catch (error) {
    Lg.e('AuthGuard', 'Failed to check auth:', error);
    isAuth = false;
    authCheckCache = null;
  }

  // 3. 处理未登录情况
  if (!isAuth) {
    if (to.meta.requiresAuth) {
      toast.warning(t('auth.messages.pleaseLogin') || '请先登录');
      next({
        name: 'auth-login',
        query: { redirect: to.fullPath }, // 保存目标路由用于登录后重定向
      });
      return;
    }
    // 不需要认证的路由，直接放行
    next();
    return;
  }

  // 4. 已登录，不允许访问登录/注册页
  const isAuthPage = ['auth-login', 'auth-register'].includes(routeName);
  if (isAuthPage) {
    next({ name: 'home' });
    return;
  }

  // 5. 检查权限
  if (to.meta.permissions && to.meta.permissions.length > 0) {
    const hasPermission = authStore.hasAnyPermission(to.meta.permissions);

    if (!hasPermission) {
      toast.error(t('auth.messages.noPermission') || '您没有权限访问此页面');
      Lg.w('AuthGuard', 'Permission denied:', {
        route: routeName,
        required: to.meta.permissions,
        userPermissions: authStore.effectivePermissions,
      });
      next({ name: 'home' });
      return;
    }
  }

  // 6. 检查角色
  if (to.meta.roles && to.meta.roles.length > 0) {
    const hasRole = authStore.hasAnyRole(to.meta.roles);

    if (!hasRole) {
      toast.error(t('auth.messages.noPermission') || '您没有权限访问此页面');
      Lg.w('AuthGuard', 'Role check failed:', {
        route: routeName,
        required: to.meta.roles,
        userRole: authStore.role,
      });
      next({ name: 'home' });
      return;
    }
  }

  // 7. 所有检查通过，放行
  next();
}

/**
 * 清除认证检查缓存
 * 在登录/登出时调用，确保状态同步
 */
export function clearAuthCache() {
  authCheckCache = null;
  Lg.d('AuthGuard', 'Auth cache cleared');
}
