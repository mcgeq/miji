/**
 * 认证守卫 Composable
 * 提供组件级别的权限保护和错误处理
 */
import { useRouter } from 'vue-router';
import { useAuthStore } from '@/stores/auth';
import type { Permission, Role } from '@/types/auth';
import { Lg } from '@/utils/debugLog';
import { toast } from '@/utils/toast';

export interface AuthGuardOptions {
  /** 所需权限（满足任一即可） */
  permissions?: Permission[];
  /** 所需角色（满足任一即可） */
  roles?: Role[];
  /** 权限不足时的回调 */
  onDenied?: () => void;
  /** 是否显示错误提示 */
  showToast?: boolean;
  /** 权限不足时的跳转路由 */
  redirectTo?: string;
}

/**
 * 使用认证守卫
 *
 * @example
 * ```ts
 * const { hasAccess, checkAccess, requireAccess } = useAuthGuard({
 *   permissions: [Permission.TRANSACTION_DELETE],
 *   showToast: true,
 * });
 *
 * // 响应式检查
 * if (hasAccess.value) {
 *   // 显示删除按钮
 * }
 *
 * // 函数式检查
 * if (checkAccess()) {
 *   // 执行删除操作
 * }
 *
 * // 要求访问（失败则跳转）
 * requireAccess();
 * ```
 */
export function useAuthGuard(options: AuthGuardOptions = {}) {
  const { permissions, roles, onDenied, showToast = true, redirectTo = '/home' } = options;

  const authStore = useAuthStore();
  const router = useRouter();

  /**
   * 响应式：是否有访问权限
   */
  const hasAccess = computed(() => {
    // 检查认证
    if (!authStore.isAuthenticated) {
      return false;
    }

    // 检查权限
    if (permissions && permissions.length > 0) {
      if (!authStore.hasAnyPermission(permissions)) {
        return false;
      }
    }

    // 检查角色
    if (roles && roles.length > 0) {
      if (!authStore.hasAnyRole(roles)) {
        return false;
      }
    }

    return true;
  });

  /**
   * 检查是否有访问权限
   * @returns 是否有权限
   */
  function checkAccess(): boolean {
    const result = hasAccess.value;

    if (!result) {
      Lg.w('AuthGuard', 'Access denied:', {
        requiredPermissions: permissions,
        requiredRoles: roles,
        userRole: authStore.role,
        effectivePermissions: authStore.effectivePermissions,
      });

      if (showToast) {
        if (!authStore.isAuthenticated) {
          toast.warning('请先登录');
        } else {
          toast.error('您没有权限执行此操作');
        }
      }

      if (onDenied) {
        onDenied();
      }
    }

    return result;
  }

  /**
   * 要求访问权限（失败则跳转）
   * @returns 是否有权限
   */
  function requireAccess(): boolean {
    const result = checkAccess();

    if (!result) {
      if (!authStore.isAuthenticated) {
        router.push({
          name: 'auth-login',
          query: { redirect: router.currentRoute.value.fullPath },
        });
      } else {
        router.push(redirectTo);
      }
    }

    return result;
  }

  /**
   * 检查特定权限
   */
  function hasPermission(permission: Permission): boolean {
    return authStore.hasPermission(permission);
  }

  /**
   * 检查特定角色
   */
  function hasRole(role: Role): boolean {
    return authStore.role === role;
  }

  return {
    /** 响应式：是否有访问权限 */
    hasAccess,
    /** 检查访问权限 */
    checkAccess,
    /** 要求访问权限（失败则跳转） */
    requireAccess,
    /** 检查特定权限 */
    hasPermission,
    /** 检查特定角色 */
    hasRole,
    /** 当前用户角色 */
    role: computed(() => authStore.role),
    /** 是否已认证 */
    isAuthenticated: computed(() => authStore.isAuthenticated),
  };
}

/**
 * 快捷方法：要求登录
 */
export function requireAuth() {
  const authStore = useAuthStore();
  const router = useRouter();

  if (!authStore.isAuthenticated) {
    toast.warning('请先登录');
    router.push({
      name: 'auth-login',
      query: { redirect: router.currentRoute.value.fullPath },
    });
    return false;
  }

  return true;
}

/**
 * 快捷方法：要求权限
 */
export function requirePermission(permission: Permission): boolean {
  const authStore = useAuthStore();

  if (!requireAuth()) {
    return false;
  }

  if (!authStore.hasPermission(permission)) {
    toast.error('您没有权限执行此操作');
    Lg.w('AuthGuard', 'Permission denied:', {
      required: permission,
      userRole: authStore.role,
      effectivePermissions: authStore.effectivePermissions,
    });
    return false;
  }

  return true;
}

/**
 * 快捷方法：要求角色
 */
export function requireRole(role: Role): boolean {
  const authStore = useAuthStore();

  if (!requireAuth()) {
    return false;
  }

  if (authStore.role !== role) {
    toast.error('您没有权限访问此功能');
    Lg.w('AuthGuard', 'Role check failed:', {
      required: role,
      current: authStore.role,
    });
    return false;
  }

  return true;
}
