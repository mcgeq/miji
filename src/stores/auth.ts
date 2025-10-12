import { defineStore } from 'pinia';
import { verifyToken } from '@/services/auth';
import { Lg } from '@/utils/debugLog';
import { toAuthUser } from '../utils/user';
import type { AuthUser, TokenResponse, User } from '@/schema/user';

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

  // 计算属性
  const isAuthenticated = computed(() => !!user.value && !!token.value);

  const isTokenExpired = computed(() => {
    if (!tokenExpiresAt.value) return false;
    return tokenExpiresAt.value < Date.now() / 1000;
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

      Lg.i('Auth', 'User logged in successfully', {
        hasUser: !!user.value,
        hasToken: !!token.value,
        rememberMe: rememberMe.value,
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

      user.value = null;
      token.value = null;
      tokenExpiresAt.value = null;
      rememberMe.value = false;

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

    // 计算属性
    isAuthenticated,
    isTokenExpired,

    // 核心方法
    login,
    logout,
    checkAuthStatus,
    updateUser,
    getCurrentUser,

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
