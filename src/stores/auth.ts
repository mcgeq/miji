import { defineStore } from 'pinia';
import { clearAuthCache } from '@/router/guards/auth.guard';
import { refreshToken as refreshTokenApi, verifyToken } from '@/services/auth';
import { Role, RolePermissions } from '@/types/auth';
import { authAudit } from '@/utils/auth-audit';
import { Lg } from '@/utils/debugLog';
import { toAuthUser } from '../utils/user';
import type { AuthUser, TokenResponse, User } from '@/schema/user';
import type { Permission } from '@/types/auth';

// =============================================================================
// Pinia Store with Tauri Persistence
// =============================================================================

/**
 * Auth store with Tauri persistence
 * 使用 @tauri-store/pinia 提供认证状态的持久化和响应式支持
 */
export const useAuthStore = defineStore('auth', () => {
  // 状态
  const user = ref<AuthUser | null>(null);
  const token = ref<string | null>(null);
  const tokenExpiresAt = ref<number | null>(null);
  const rememberMe = ref<boolean>(false);
  const isLoading = ref<boolean>(false);

  // 权限相关状态
  const permissions = ref<Permission[]>([]);
  const role = ref<Role>(Role.GUEST);

  // 计算属性
  const isAuthenticated = computed(() => !!user.value && !!token.value);

  const isTokenExpired = computed(() => {
    if (!tokenExpiresAt.value) return false;
    return tokenExpiresAt.value < Date.now() / 1000;
  });

  // 计算有效权限（角色权限 + 额外权限）
  const effectivePermissions = computed(() => {
    const rolePerms = RolePermissions[role.value] || [];
    return [...new Set([...rolePerms, ...permissions.value])];
  });

  // =============================================================================
  // 核心方法
  // =============================================================================

  /**
   * 登录
   */
  async function login(
    userData: User,
    tokenResponse?: TokenResponse,
    remember = false,
  ): Promise<boolean> {
    try {
      isLoading.value = true;

      const authUser = toAuthUser(userData);
      user.value = authUser;
      rememberMe.value = remember;

      if (tokenResponse) {
        token.value = tokenResponse.token;
        tokenExpiresAt.value = remember ? tokenResponse.expiresAt : null;

        // Verify token immediately after login
        const tokenStatus = await verifyToken(tokenResponse.token);
        if (tokenStatus !== 'Valid') {
          throw new Error('Generated token is invalid');
        }
      }

      // 设置角色和权限
      // 注意：User 类型可能还没有 role 和 permissions 字段
      // 这里使用类型断言，如果字段不存在则使用默认值
      const rawRole = (userData as any).role;
      const userPermissions = ((userData as any).permissions as Permission[]) || [];

      // 将角色转换为小写以匹配枚举值（后端可能返回 'User' 而不是 'user'）
      const normalizedRole = rawRole?.toLowerCase() as Role;
      const userRole = normalizedRole || Role.USER;

      role.value = userRole;
      permissions.value = userPermissions;

      // 清除路由守卫缓存
      clearAuthCache();

      Lg.i('Auth', 'User logged in successfully', {
        hasUser: !!user.value,
        hasToken: !!token.value,
        rememberMe: rememberMe.value,
        role: role.value,
        explicitPermissions: permissions.value.length,
        effectivePermissions: effectivePermissions.value.length,
      });

      // 记录审计日志
      authAudit.logLogin(authUser.serialNum, role.value, {
        rememberMe: rememberMe.value,
        effectivePermissions: effectivePermissions.value.length,
      });

      // 注意：autosave 已在 storeStart() 中启用
      // 状态变化后会在 300ms 内自动保存到磁盘

      return true;
    } catch (error) {
      Lg.e('Auth', 'Login failed:', error);
      throw error;
    } finally {
      isLoading.value = false;
    }
  }

  /**
   * 登出
   */
  async function logout(): Promise<void> {
    try {
      isLoading.value = true;

      // 记录审计日志（在清除前记录）
      const userId = user.value?.serialNum || 'unknown';
      authAudit.logLogout(userId);

      user.value = null;
      token.value = null;
      tokenExpiresAt.value = null;
      rememberMe.value = false;

      // 清除权限和角色
      permissions.value = [];
      role.value = Role.GUEST;

      // 清除路由守卫缓存
      clearAuthCache();

      Lg.i('Auth', 'User logged out successfully');
    } catch (error) {
      Lg.e('Auth', 'Logout failed:', error);
      throw error;
    } finally {
      isLoading.value = false;
    }
  }

  /**
   * 检查认证状态
   */
  async function checkAuthStatus(): Promise<boolean> {
    try {
      if (!user.value || !token.value) {
        return false;
      }

      const currentTime = Date.now() / 1000;

      // 记住我模式：检查 token 是否过期
      if (rememberMe.value) {
        if (!tokenExpiresAt.value || tokenExpiresAt.value < currentTime) {
          await logout();
          return false;
        }

        // Token自动刷新：如果在5分钟内过期，尝试刷新
        const timeUntilExpiry = tokenExpiresAt.value - currentTime;
        if (timeUntilExpiry < 5 * 60) { // 5分钟
          Lg.i('Auth', 'Token expires soon, attempting refresh...', {
            expiresIn: `${Math.round(timeUntilExpiry / 60)} minutes`,
          });

          try {
            await refreshToken();
            Lg.i('Auth', 'Token refreshed successfully');
          } catch (error) {
            Lg.w('Auth', 'Token refresh failed:', error);
            // 刷新失败不立即登出，继续使用旧token直到完全过期
          }
        }
      }

      // 验证 token
      const tokenStatus = await verifyToken(token.value);
      if (tokenStatus !== 'Valid') {
        await logout();
        return false;
      }

      return true;
    } catch (error) {
      Lg.e('Auth', 'Auth check failed:', error);
      await logout();
      return false;
    }
  }

  /**
   * 刷新Token
   *
   * 自动刷新机制：
   * - Token在1小时内过期时自动刷新
   * - 使用旧Token换取新Token（延长7天）
   * - 刷新失败不立即登出，继续使用旧Token直到完全过期
   */
  async function refreshToken(): Promise<void> {
    if (!token.value || !user.value) {
      throw new Error('No token or user to refresh');
    }

    try {
      isLoading.value = true;

      // 调用后端刷新Token API
      const tokenResponse = await refreshTokenApi(token.value);

      // 更新Token和过期时间
      token.value = tokenResponse.token;
      tokenExpiresAt.value = tokenResponse.expiresAt;

      Lg.i('Auth', 'Token refreshed successfully', {
        newExpiresAt: new Date(tokenResponse.expiresAt * 1000).toISOString(),
      });
    } catch (error) {
      Lg.e('Auth', 'Token refresh error:', error);
      throw error;
    } finally {
      isLoading.value = false;
    }
  }

  /**
   * 更新用户信息
   */
  async function updateUser(updatedUser: Partial<AuthUser>): Promise<void> {
    if (!user.value) {
      throw new Error('用户未登录');
    }

    user.value = { ...user.value, ...updatedUser };
    Lg.i('Auth', 'User info updated');
  }

  /**
   * 获取当前用户
   */
  function getCurrentUser(): AuthUser | null {
    return user.value;
  }

  /**
   * 检查是否有指定权限（满足任一即可）
   */
  function hasAnyPermission(perms?: Permission[]): boolean {
    if (!perms || perms.length === 0) return true;

    const hasPermission = perms.some(p => effectivePermissions.value.includes(p));
    const userId = user.value?.serialNum || 'unknown';

    // 记录审计日志
    if (hasPermission) {
      authAudit.logPermissionGranted(userId, role.value, perms);
    } else {
      authAudit.logPermissionDenied(
        userId,
        role.value,
        perms,
        effectivePermissions.value,
      );
    }

    return hasPermission;
  }

  /**
   * 检查是否有所有指定权限
   */
  function hasAllPermissions(perms?: Permission[]): boolean {
    if (!perms || perms.length === 0) return true;
    return perms.every(p => effectivePermissions.value.includes(p));
  }

  /**
   * 检查是否有指定角色（满足任一即可）
   */
  function hasAnyRole(roles?: Role[]): boolean {
    if (!roles || roles.length === 0) return true;
    return roles.includes(role.value);
  }

  /**
   * 检查是否有指定权限
   */
  function hasPermission(permission: Permission): boolean {
    return effectivePermissions.value.includes(permission);
  }

  // =============================================================================
  // 扩展方法
  // =============================================================================

  /**
   * 更新用户资料
   */
  async function updateProfile(profileData: Partial<AuthUser>) {
    if (!user.value || !token.value) {
      throw new Error('用户未登录');
    }

    try {
      isLoading.value = true;

      // 调用后端 API 更新用户资料
      const response = await fetch('/api/user/profile', {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token.value}`,
        },
        body: JSON.stringify(profileData),
      });

      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.message || '更新资料失败');
      }

      const updatedUserData = await response.json();

      // 更新本地状态
      await updateUser(updatedUserData);

      return updatedUserData;
    } catch (error) {
      Lg.e('Auth', '更新用户资料错误:', error);
      throw error;
    } finally {
      isLoading.value = false;
    }
  }

  /**
   * 上传头像
   */
  async function uploadAvatar(file: File) {
    if (!user.value || !token.value) {
      throw new Error('用户未登录');
    }

    try {
      isLoading.value = true;

      const formData = new FormData();
      formData.append('avatar', file);

      const response = await fetch('/api/user/avatar', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${token.value}`,
        },
        body: formData,
      });

      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.message || '头像上传失败');
      }

      const { avatarUrl } = await response.json();

      // 更新本地用户头像
      await updateUser({ avatarUrl });

      return avatarUrl;
    } catch (error) {
      Lg.e('Auth', '上传头像错误:', error);
      throw error;
    } finally {
      isLoading.value = false;
    }
  }

  /**
   * 验证邮箱
   */
  async function verifyEmailAddress(verificationCode: string) {
    if (!user.value || !token.value) {
      throw new Error('用户未登录');
    }

    try {
      isLoading.value = true;

      const response = await fetch('/api/user/verify-email', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token.value}`,
        },
        body: JSON.stringify({ code: verificationCode }),
      });

      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.message || '邮箱验证失败');
      }

      // 更新用户验证状态
      await updateUser({
        isVerified: true,
        emailVerifiedAt: new Date().toISOString(),
      });

      return true;
    } catch (error) {
      Lg.e('Auth', '邮箱验证错误:', error);
      throw error;
    } finally {
      isLoading.value = false;
    }
  }

  /**
   * 发送邮箱验证码
   */
  async function sendEmailVerification() {
    if (!user.value || !token.value) {
      throw new Error('用户未登录');
    }

    try {
      isLoading.value = true;

      const response = await fetch('/api/user/send-email-verification', {
        method: 'POST',
        headers: {
          Authorization: `Bearer ${token.value}`,
        },
      });

      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.message || '发送验证邮件失败');
      }

      return true;
    } catch (error) {
      Lg.e('Auth', '发送邮箱验证错误:', error);
      throw error;
    } finally {
      isLoading.value = false;
    }
  }

  /**
   * 修改密码
   */
  async function changePassword(
    currentPassword: string,
    newPassword: string,
  ) {
    if (!user.value || !token.value) {
      throw new Error('用户未登录');
    }

    try {
      isLoading.value = true;

      const response = await fetch('/api/user/change-password', {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${token.value}`,
        },
        body: JSON.stringify({
          currentPassword,
          newPassword,
        }),
      });

      if (!response.ok) {
        const errorData = await response.json();
        throw new Error(errorData.message || '修改密码失败');
      }

      return true;
    } catch (error) {
      Lg.e('Auth', '修改密码错误:', error);
      throw error;
    } finally {
      isLoading.value = false;
    }
  }

  return {
    // 状态（不使用 readonly，因为 @tauri-store/pinia 需要写入权限来加载持久化数据）
    user,
    token,
    tokenExpiresAt,
    rememberMe,
    isLoading,
    permissions,
    role,

    // 计算属性
    isAuthenticated,
    isTokenExpired,
    effectivePermissions,

    // 核心方法
    login,
    logout,
    checkAuthStatus,
    refreshToken,
    updateUser,
    getCurrentUser,

    // 权限检查方法
    hasAnyPermission,
    hasAllPermissions,
    hasAnyRole,
    hasPermission,

    // 扩展方法
    updateProfile,
    uploadAvatar,
    verifyEmail: verifyEmailAddress,
    sendEmailVerification,
    changePassword,
  };
}, {
  // 官方推荐：启用 saveOnChange
  // 文档：https://tb.dev.br/tauri-store/plugin-pinia/guide/persisting-state
  tauri: {
    saveOnChange: true, // 状态变化时自动保存
    saveStrategy: 'debounce', // 使用防抖策略
    saveInterval: 300, // 300ms 防抖延迟
  },
});

// =============================================================================
// 向后兼容性导出
// =============================================================================

/**
 * @deprecated 使用 useAuthStore() 替代
 * 为了向后兼容而保留
 */
export function getCurrentUser(): AuthUser | null {
  const store = useAuthStore();
  return store.getCurrentUser();
}

/**
 * @deprecated 使用 useAuthStore().login() 替代
 */
export async function loginUser(
  userData: User,
  tokenResponse?: TokenResponse,
  remember = false,
): Promise<void> {
  const store = useAuthStore();
  await store.login(userData, tokenResponse, remember);
}

/**
 * @deprecated 使用 useAuthStore().logout() 替代
 */
export async function logoutUser(): Promise<void> {
  const store = useAuthStore();
  await store.logout();
}

/**
 * @deprecated 使用 useAuthStore().checkAuthStatus() 替代
 */
export async function isAuthenticated(): Promise<boolean> {
  const store = useAuthStore();
  return await store.checkAuthStatus();
}

// 导出类型
export type { AuthUser, TokenResponse, User };
