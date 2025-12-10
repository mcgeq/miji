/**
 * 认证权限 Composable
 * 提供基于 RBAC 的权限检查功能
 */
import { useAuthStore } from '@/stores/auth';
import type { Permission, Role } from '@/types/auth';

export function useAuthPermission() {
  const authStore = useAuthStore();

  /**
   * 检查是否有指定权限（满足任一即可）
   */
  const hasPermission = (permission: Permission | Permission[]) => {
    const perms = Array.isArray(permission) ? permission : [permission];
    return authStore.hasAnyPermission(perms);
  };

  /**
   * 检查是否有所有指定权限
   */
  const hasAllPermissions = (permissions: Permission[]) => {
    return authStore.hasAllPermissions(permissions);
  };

  /**
   * 检查是否有指定角色（满足任一即可）
   */
  const hasRole = (role: Role | Role[]) => {
    const roles = Array.isArray(role) ? role : [role];
    return authStore.hasAnyRole(roles);
  };

  /**
   * 检查是否是特定角色
   */
  const isRole = (role: Role) => {
    return authStore.role === role;
  };

  /**
   * 当前用户的所有有效权限
   */
  const permissions = computed(() => authStore.effectivePermissions);

  /**
   * 当前用户角色
   */
  const role = computed(() => authStore.role);

  /**
   * 是否已登录
   */
  const isAuthenticated = computed(() => authStore.isAuthenticated);

  return {
    // 状态
    permissions,
    role,
    isAuthenticated,

    // 权限检查方法
    hasPermission,
    hasAllPermissions,
    hasRole,
    isRole,
  };
}
