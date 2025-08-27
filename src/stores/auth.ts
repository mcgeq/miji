import { createStore } from '@tauri-store/vue';
import { defineStore } from 'pinia';
import { verifyToken } from '@/services/auth';
import { Lg } from '@/utils/debugLog';
import { toAuthUser } from '../utils/user';
import type { AuthUser, TokenResponse, User } from '@/schema/user';

// 定义状态类型
interface AuthState {
  user: AuthUser | null;
  token: string | null;
  tokenExpiresAt: number | null;
  rememberMe: boolean;
  [key: string]: any; // 添加索引签名，保持一致性
}

// Tauri Store (保持原有实现)
export const authStore = createStore<AuthState>('auth', {
  user: null as AuthUser | null,
  token: null as string | null,
  tokenExpiresAt: null as number | null,
  rememberMe: false,
});

// 保持原有函数不变
export function getCurrentUser(): AuthUser | null {
  return authStore.value.user;
}

export async function loginUser(
  user: User,
  tokenResponse?: TokenResponse,
  rememberMe = false,
) {
  const authUser = toAuthUser(user);
  authStore.value.user = authUser;
  authStore.value.rememberMe = rememberMe;

  if (tokenResponse) {
    authStore.value.token = tokenResponse.token;
    authStore.value.tokenExpiresAt = rememberMe
      ? tokenResponse.expiresAt
      : null;

    // Verify token immediately after login
    const tokenStatus = await verifyToken(tokenResponse.token);
    if (tokenStatus !== 'Valid') {
      throw new Error('Generated token is invalid');
    }
  }
  await authStore.$tauri.saveNow();
}

export async function logoutUser() {
  authStore.value.user = null;
  authStore.value.token = null;
  authStore.value.tokenExpiresAt = null;
  await authStore.$tauri.saveNow();
}

export async function isAuthenticated(): Promise<boolean> {
  const { user, token, tokenExpiresAt, rememberMe } = authStore.value;
  if (!user || !token) {
    return false;
  }

  const currentTime = Date.now() / 1000;

  if (rememberMe) {
    // 记住我模式，tokenExpiresAt 必须有效且未过期
    if (!tokenExpiresAt || tokenExpiresAt < currentTime) {
      await logoutUser();
      return false;
    }
  }

  // Verify token
  try {
    const tokenStatus = await verifyToken(token);
    if (tokenStatus !== 'Valid') {
      await logoutUser();
      return false;
    }
  } catch {
    await logoutUser();
    return false;
  }

  return true;
}

// 新增：Pinia Store 定义
export const useAuthStore = defineStore('auth', () => {
  // 状态 (响应式，基于 Tauri store)
  const user = ref<AuthUser | null>(null);
  const token = ref<string | null>(null);
  const tokenExpiresAt = ref<number | null>(null);
  const rememberMe = ref(false);
  const isLoading = ref(false);

  // 计算属性
  const isAuthenticatedComputed = computed(() => !!user.value && !!token.value);

  const isTokenExpired = computed(() => {
    if (!tokenExpiresAt.value) return false;
    return tokenExpiresAt.value < Date.now() / 1000;
  });

  // 同步 Tauri store 到 Pinia store
  const syncFromTauriStore = () => {
    const state = authStore.value;
    user.value = state.user;
    token.value = state.token;
    tokenExpiresAt.value = state.tokenExpiresAt;
    rememberMe.value = state.rememberMe;
  };

  // 退出登录函数
  const logout = async () => {
    try {
      isLoading.value = true;

      // 使用原有的 logoutUser 函数
      await logoutUser();

      // 同步状态
      syncFromTauriStore();

      return true;
    } catch (error) {
      Lg.e('Auth', 'Logout failed:', error);
      throw error;
    } finally {
      isLoading.value = false;
    }
  };

  // 自动同步 Tauri store 状态（应用启动时 Tauri store 已经初始化）
  syncFromTauriStore();

  // 登录
  const login = async (
    userData: User,
    tokenResponse?: TokenResponse,
    remember = false,
  ) => {
    try {
      isLoading.value = true;

      // 使用原有的 loginUser 函数
      await loginUser(userData, tokenResponse, remember);

      // 同步状态
      syncFromTauriStore();

      return true;
    } catch (error) {
      console.error('Login failed:', error);
      throw error;
    } finally {
      isLoading.value = false;
    }
  };

  // 检查认证状态
  const checkAuthStatus = async (): Promise<boolean> => {
    try {
      const result = await isAuthenticated();
      if (!result) {
        // 如果认证失败，同步本地状态（isAuthenticated 中已调用 logoutUser）
        syncFromTauriStore();
      }
      return result;
    } catch (error) {
      Lg.e('Auth', 'Auth check failed:', error);
      return false;
    }
  };

  // 更新用户信息
  const updateUser = async (updatedUser: Partial<AuthUser>) => {
    if (!user.value) return;

    const newUser = { ...user.value, ...updatedUser };

    // 同步到 Tauri store
    authStore.value.user = newUser;
    await authStore.$tauri.saveNow();

    // 同步到 Pinia store
    user.value = newUser;
  };

  // 获取当前用户 - 保持与原 auth.ts 兼容
  const getCurrentUserFromStore = (): AuthUser | null => {
    return user.value;
  };
  const updateProfile = async (profileData: Partial<AuthUser>) => {
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
          Authorization: `Bearer ${token.value}`,
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
  };

  // 上传头像
  const uploadAvatar = async (file: File) => {
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
  };

  // 验证邮箱
  const verifyEmail = async (verificationCode: string) => {
    if (!user.value || !token.value) {
      throw new Error('用户未登录');
    }

    try {
      isLoading.value = true;

      const response = await fetch('/api/user/verify-email', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token.value}`,
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
  };

  // 发送邮箱验证码
  const sendEmailVerification = async () => {
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
  };

  // 修改密码
  const changePassword = async (
    currentPassword: string,
    newPassword: string,
  ) => {
    if (!user.value || !token.value) {
      throw new Error('用户未登录');
    }

    try {
      isLoading.value = true;

      const response = await fetch('/api/user/change-password', {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${token.value}`,
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
  };
  return {
    // 状态
    user: computed(() => user.value),
    token: computed(() => token.value),
    tokenExpiresAt: computed(() => tokenExpiresAt.value),
    rememberMe: computed(() => rememberMe.value),
    isLoading: computed(() => isLoading.value),

    // 计算属性
    isAuthenticated: isAuthenticatedComputed,
    isTokenExpired,

    // 方法
    login,
    logout,
    checkAuthStatus,
    updateUser,
    getCurrentUser: getCurrentUserFromStore,
    syncFromTauriStore,
    updateProfile,
    uploadAvatar,
    verifyEmail,
    sendEmailVerification,
    changePassword,
  };
});
