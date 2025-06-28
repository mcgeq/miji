// src/stores/auth.ts
import type { AuthUser, User, TokenResponse } from '@/schema/user';
import { toAuthUser } from '../utils/user';
import { verifyToken } from '@/services/auth';
import { createStore } from '@tauri-store/vue';
// 定义状态类型
interface AuthState {
  user: AuthUser | null;
  token: string | null;
  tokenExpiresAt: number | null;
  rememberMe: boolean;
  [key: string]: any; // 添加索引签名，保持一致性
}

export const authStore = createStore<AuthState>('auth', {
  user: null as AuthUser | null,
  token: null as string | null,
  tokenExpiresAt: null as number | null,
  rememberMe: false,
});

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
