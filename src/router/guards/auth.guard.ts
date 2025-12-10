import type { Composer } from 'vue-i18n';
/**
 * 认证路由守卫
 */
import type { NavigationGuardNext, RouteLocationNormalized } from 'vue-router';
import { i18nInstance } from '@/i18n/i18n';
import { useAuthStore } from '@/stores/auth';
import { Lg } from '@/utils/debugLog';
import { toast } from '@/utils/toast';

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
 * 获取认证状态（带缓存）
 */
async function getAuthStatus(): Promise<boolean> {
  const authStore = useAuthStore();
  const now = Date.now();

  try {
    // 使用缓存（30秒内有效）
    if (authCheckCache && now - authCheckCache.timestamp < CACHE_DURATION) {
      Lg.d('AuthGuard', 'Using cached auth status:', authCheckCache.isAuth);
      return authCheckCache.isAuth;
    }

    // 重新检查认证状态
    const isAuth = await authStore.checkAuthStatus();
    authCheckCache = { isAuth, timestamp: now };
    Lg.d('AuthGuard', 'Fresh auth check:', isAuth);
    return isAuth;
  } catch (error) {
    Lg.e('AuthGuard', 'Failed to check auth:', error);
    authCheckCache = null;
    return false;
  }
}

/**
 * 处理未登录情况
 */
function handleUnauthenticated(
  to: RouteLocationNormalized,
  next: NavigationGuardNext,
  t: Composer['t'],
): void {
  if (to.meta.requiresAuth) {
    toast.warning(t('auth.messages.pleaseLogin') || '请先登录');
    next({
      name: 'auth-login',
      query: { redirect: to.fullPath },
    });
  } else {
    next();
  }
}

/**
 * 检查权限
 */
function checkPermissions(
  to: RouteLocationNormalized,
  routeName: string,
  next: NavigationGuardNext,
  t: Composer['t'],
): boolean {
  if (!to.meta.permissions || to.meta.permissions.length === 0) {
    return true;
  }

  const authStore = useAuthStore();
  Lg.d('AuthGuard', 'Checking permissions for route:', {
    route: routeName,
    required: to.meta.permissions,
    userRole: authStore.role,
    explicitPermissions: authStore.permissions,
    effectivePermissions: authStore.effectivePermissions,
  });

  const hasPermission = authStore.hasAnyPermission(to.meta.permissions);
  if (!hasPermission) {
    toast.error(t('auth.messages.noPermission') || '您没有权限访问此页面');
    Lg.e('AuthGuard', 'Permission denied:', {
      route: routeName,
      required: to.meta.permissions,
      userRole: authStore.role,
      effectivePermissions: authStore.effectivePermissions,
    });
    next({ name: 'home' });
    return false;
  }

  return true;
}

/**
 * 检查角色
 */
function checkRoles(
  to: RouteLocationNormalized,
  routeName: string,
  next: NavigationGuardNext,
  t: Composer['t'],
): boolean {
  if (!to.meta.roles || to.meta.roles.length === 0) {
    return true;
  }

  const authStore = useAuthStore();
  const hasRole = authStore.hasAnyRole(to.meta.roles);

  if (!hasRole) {
    toast.error(t('auth.messages.noPermission') || '您没有权限访问此页面');
    Lg.w('AuthGuard', 'Role check failed:', {
      route: routeName,
      required: to.meta.roles,
      userRole: authStore.role,
    });
    next({ name: 'home' });
    return false;
  }

  return true;
}

/**
 * 认证守卫
 */
export async function authGuard(
  to: RouteLocationNormalized,
  _from: RouteLocationNormalized,
  next: NavigationGuardNext,
) {
  const t = i18nInstance ? (i18nInstance.global as Composer).t : (key: string) => key;
  const routeName = typeof to.name === 'string' ? to.name : '';

  // 1. 检查白名单
  if (WHITE_LIST.includes(routeName)) {
    next();
    return;
  }

  // 2. 获取认证状态
  const isAuth = await getAuthStatus();

  // 3. 处理未登录情况
  if (!isAuth) {
    handleUnauthenticated(to, next, t);
    return;
  }

  // 4. 已登录，不允许访问登录/注册页
  if (['auth-login', 'auth-register'].includes(routeName)) {
    next({ name: 'home' });
    return;
  }

  // 5. 检查权限
  if (!checkPermissions(to, routeName, next, t)) {
    return;
  }

  // 6. 检查角色
  if (!checkRoles(to, routeName, next, t)) {
    return;
  }

  // 7. 所有检查通过
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
