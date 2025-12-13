import { defineStore } from 'pinia';
import { computed, ref } from 'vue';
import type { AppError } from '@/errors/appError';
import { AppErrorSeverity } from '@/errors/appError';
import { clearAuthCache } from '@/router/guards/auth.guard';
import type { AuthUser, TokenResponse, UpdateUserRequest, User } from '@/schema/user';
import { authService } from '@/services/authService';
import { withLoadingSafe } from '@/stores/utils/withLoadingSafe';
import type { Permission } from '@/types/auth';
import { Role, RolePermissions } from '@/types/auth';
import { authAudit } from '@/utils/auth-audit';
import { Lg } from '@/utils/debugLog';
import { assertExists, throwAppError, wrapError } from '@/utils/errorHandler';
import { toAuthUser } from '../utils/user';

// =============================================================================
// Pinia Store with Tauri Persistence
// =============================================================================

/**
 * Auth store with Tauri persistence
 * 使用 @tauri-store/pinia 提供认证状态的持久化和响应式支持
 */
export const useAuthStore = defineStore(
  'auth',
  () => {
    // 状态
    const user = ref<AuthUser | null>(null);
    const token = ref<string | null>(null);
    const tokenExpiresAt = ref<number | null>(null);
    const rememberMe = ref<boolean>(false);
    const isLoading = ref<boolean>(false);
    const error = ref<AppError | null>(null);

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
    const login = withLoadingSafe<[User, TokenResponse?, boolean?], boolean>(
      async (userData: User, tokenResponse?: TokenResponse, remember = false) => {
        try {
          const authUser = toAuthUser(userData);
          user.value = authUser;
          rememberMe.value = remember;

          if (tokenResponse) {
            token.value = tokenResponse.token;
            tokenExpiresAt.value = remember ? tokenResponse.expiresAt : null;

            // Verify token immediately after login
            const tokenStatus = await authService.verifyToken(tokenResponse.token);
            if (tokenStatus !== 'Valid') {
              throwAppError(
                'Auth',
                'INVALID_TOKEN',
                'Generated token is invalid',
                AppErrorSeverity.HIGH,
              );
            }
          }

          // 设置角色和权限
          // 使用类型守卫安全地提取角色和权限
          const rawRole =
            'role' in userData && typeof userData.role === 'string' ? userData.role : undefined;
          const userPermissions =
            'permissions' in userData && Array.isArray(userData.permissions)
              ? (userData.permissions as Permission[])
              : [];

          // 将角色转换为小写以匹配枚举值（后端可能返回 'User' 而不是 'user'）
          const normalizedRole = rawRole?.toLowerCase();
          const userRole =
            normalizedRole && Object.values(Role).includes(normalizedRole as Role)
              ? (normalizedRole as Role)
              : Role.USER;

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
        } catch (err) {
          error.value = wrapError('AuthStore', err, 'LOGIN_FAILED', '登录失败');
          throw error.value;
        }
      },
      isLoading,
      error,
    );

    /**
     * 登出
     */
    const logout = withLoadingSafe(
      async (): Promise<void> => {
        try {
          // 记录审计日志（在清除前记录）
          const userId = user.value?.serialNum || 'unknown';
          authAudit.logLogout(userId);

          // 调用 Service 层的登出逻辑
          await authService.logout();

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
        } catch (err) {
          error.value = wrapError('AuthStore', err, 'LOGOUT_FAILED', '登出失败');
          throw error.value;
        }
      },
      isLoading,
      error,
    );

    /**
     * 检查 token 过期状态并在需要时刷新
     */
    async function handleTokenExpiry(currentTime: number): Promise<boolean> {
      if (!tokenExpiresAt.value || tokenExpiresAt.value < currentTime) {
        await logout();
        return false;
      }

      const timeUntilExpiry = tokenExpiresAt.value - currentTime;
      if (timeUntilExpiry < 5 * 60) {
        Lg.i('Auth', 'Token expires soon, attempting refresh...', {
          expiresIn: `${Math.round(timeUntilExpiry / 60)} minutes`,
        });

        try {
          await refreshToken();
          Lg.i('Auth', 'Token refreshed successfully');
        } catch (error) {
          Lg.w('Auth', 'Token refresh failed:', error);
        }
      }

      return true;
    }

    /**
     * 检查认证状态
     */
    async function checkAuthStatus(): Promise<boolean> {
      try {
        if (!(user.value && token.value)) {
          return false;
        }

        const currentTime = Date.now() / 1000;

        if (rememberMe.value) {
          const isValid = await handleTokenExpiry(currentTime);
          if (!isValid) {
            return false;
          }
        }

        const tokenStatus = await authService.verifyToken(token.value);
        if (tokenStatus !== 'Valid') {
          await logout();
          return false;
        }

        return true;
      } catch (err) {
        Lg.e('Auth', 'Auth check failed:', err);
        error.value = wrapError('AuthStore', err, 'AUTH_CHECK_FAILED', '认证检查失败');
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
    const refreshToken = withLoadingSafe(
      async (): Promise<void> => {
        assertExists(
          token.value,
          'Auth',
          'NO_TOKEN',
          'No token available to refresh',
          AppErrorSeverity.HIGH,
        );
        assertExists(
          user.value,
          'Auth',
          'NO_USER',
          'No user available to refresh',
          AppErrorSeverity.HIGH,
        );

        try {
          // 调用 AuthService 刷新 Token
          const tokenResponse = await authService.refreshToken(token.value);

          // 更新Token和过期时间
          token.value = tokenResponse.token;
          tokenExpiresAt.value = tokenResponse.expiresAt;

          Lg.i('Auth', 'Token refreshed successfully', {
            newExpiresAt: new Date(tokenResponse.expiresAt * 1000).toISOString(),
          });
        } catch (err) {
          error.value = wrapError('AuthStore', err, 'TOKEN_REFRESH_FAILED', 'Token 刷新失败');
          throw error.value;
        }
      },
      isLoading,
      error,
    );

    /**
     * 更新用户信息
     */
    const updateUser = withLoadingSafe(
      async (updatedUser: Partial<AuthUser>): Promise<void> => {
        assertExists(
          user.value,
          'Auth',
          'NOT_AUTHENTICATED',
          '用户未登录',
          AppErrorSeverity.MEDIUM,
        );

        try {
          // 如果有 serialNum，调用 Service 更新后端数据
          if (user.value.serialNum && Object.keys(updatedUser).length > 0) {
            const updated = await authService.updateUser(
              user.value.serialNum,
              updatedUser as UpdateUserRequest,
            );
            user.value = toAuthUser(updated);
          } else {
            // 仅更新本地状态
            user.value = { ...user.value, ...updatedUser };
          }

          Lg.i('Auth', 'User info updated');
        } catch (err) {
          error.value = wrapError('AuthStore', err, 'UPDATE_USER_FAILED', '更新用户信息失败');
          throw error.value;
        }
      },
      isLoading,
      error,
    );

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
        authAudit.logPermissionDenied(userId, role.value, perms, effectivePermissions.value);
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
    const updateProfile = withLoadingSafe(
      async (profileData: Partial<AuthUser>) => {
        assertExists(
          user.value,
          'Auth',
          'NOT_AUTHENTICATED',
          '用户未登录',
          AppErrorSeverity.MEDIUM,
        );

        try {
          // 调用 Service 层更新用户资料
          const updatedUserData = await authService.updateProfile(profileData as any);

          // 更新本地状态
          user.value = toAuthUser(updatedUserData);

          return updatedUserData;
        } catch (err) {
          error.value = wrapError('AuthStore', err, 'UPDATE_PROFILE_FAILED', '更新用户资料失败');
          throw error.value;
        }
      },
      isLoading,
      error,
    );

    /**
     * 上传头像
     */
    const uploadAvatar = withLoadingSafe(
      async (file: File) => {
        assertExists(
          user.value,
          'Auth',
          'NOT_AUTHENTICATED',
          '用户未登录',
          AppErrorSeverity.MEDIUM,
        );

        try {
          // 调用 Service 层上传头像
          const avatarUrl = await authService.uploadAvatar(file);

          // 更新本地用户头像
          await updateUser({ avatarUrl });

          return avatarUrl;
        } catch (err) {
          error.value = wrapError('AuthStore', err, 'UPLOAD_AVATAR_FAILED', '上传头像失败');
          throw error.value;
        }
      },
      isLoading,
      error,
    );

    /**
     * 验证邮箱
     */
    const verifyEmailAddress = withLoadingSafe(
      async (verificationCode: string) => {
        assertExists(
          user.value,
          'Auth',
          'NOT_AUTHENTICATED',
          '用户未登录',
          AppErrorSeverity.MEDIUM,
        );

        try {
          // 调用 Service 层验证邮箱
          const success = await authService.verifyEmail(verificationCode);

          if (success) {
            // 更新用户验证状态
            await updateUser({
              isVerified: true,
              emailVerifiedAt: new Date().toISOString(),
            });
          }

          return success;
        } catch (err) {
          error.value = wrapError('AuthStore', err, 'VERIFY_EMAIL_FAILED', '邮箱验证失败');
          throw error.value;
        }
      },
      isLoading,
      error,
    );

    /**
     * 发送邮箱验证码
     */
    const sendEmailVerification = withLoadingSafe(
      async () => {
        assertExists(
          user.value,
          'Auth',
          'NOT_AUTHENTICATED',
          '用户未登录',
          AppErrorSeverity.MEDIUM,
        );

        try {
          // 调用 Service 层发送验证邮件
          const success = await authService.sendEmailVerification();
          return success;
        } catch (err) {
          error.value = wrapError('AuthStore', err, 'SEND_VERIFICATION_FAILED', '发送验证邮件失败');
          throw error.value;
        }
      },
      isLoading,
      error,
    );

    /**
     * 修改密码
     */
    const changePassword = withLoadingSafe(
      async (currentPassword: string, newPassword: string) => {
        assertExists(
          user.value,
          'Auth',
          'NOT_AUTHENTICATED',
          '用户未登录',
          AppErrorSeverity.MEDIUM,
        );

        try {
          // 调用 Service 层修改密码
          const success = await authService.changePassword(currentPassword, newPassword);
          return success;
        } catch (err) {
          error.value = wrapError('AuthStore', err, 'CHANGE_PASSWORD_FAILED', '修改密码失败');
          throw error.value;
        }
      },
      isLoading,
      error,
    );

    /**
     * 重置 Store 状态
     */
    function $reset() {
      user.value = null;
      token.value = null;
      tokenExpiresAt.value = null;
      rememberMe.value = false;
      isLoading.value = false;
      error.value = null;
      permissions.value = [];
      role.value = Role.GUEST;
    }

    return {
      // 状态（不使用 readonly，因为 @tauri-store/pinia 需要写入权限来加载持久化数据）
      user,
      token,
      tokenExpiresAt,
      rememberMe,
      isLoading,
      error,
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

      // 重置方法
      $reset,
    };
  },
  {
    // 官方推荐：启用 saveOnChange
    // 文档：https://tb.dev.br/tauri-store/plugin-pinia/guide/persisting-state
    tauri: {
      saveOnChange: true, // 状态变化时自动保存
      saveStrategy: 'debounce', // 使用防抖策略
      saveInterval: 300, // 300ms 防抖延迟
    },
  },
);

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
