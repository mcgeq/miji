// src/lib/stores/auth.ts
import { RuneStore } from '@tauri-store/svelte';
import type { AuthUser, User, TokenResponse } from '$lib/schema/user';
import { toAuthUser } from '../utils/user';
import { verifyToken } from '../api/auth';
// 定义状态类型
interface AuthState {
  user: AuthUser | null;
  token: string | null;
  tokenExpiresAt: number | null;
  rememberMe: boolean;
  [key: string]: any; // 添加索引签名，保持一致性
}

export const authStore = new RuneStore<AuthState>('auth', {
  user: null as AuthUser | null,
  token: null as string | null,
  tokenExpiresAt: null as number | null,
  rememberMe: false,
});

export function getCurrentUser(): AuthUser | null {
  return authStore.state.user;
}

export async function loginUser(
  user: User,
  tokenResponse?: TokenResponse,
  rememberMe = false,
) {
  const authUser = toAuthUser(user);
  authStore.state.user = authUser;
  authStore.state.rememberMe = rememberMe;

  if (tokenResponse) {
    authStore.state.token = tokenResponse.token;
    authStore.state.tokenExpiresAt = rememberMe
      ? tokenResponse.expires_at
      : null;

    // Verify token immediately after login
    const tokenStatus = await verifyToken(tokenResponse.token);
    if (tokenStatus !== 'Valid') {
      throw new Error('Generated token is invalid');
    }
  }

  await authStore.save();
}

export async function logoutUser() {
  authStore.state.user = null;
  authStore.state.token = null;
  authStore.state.tokenExpiresAt = null;
  await authStore.save();
}

export async function isAuthenticated(): Promise<boolean> {
  const { user, token, tokenExpiresAt, rememberMe } = authStore.state;

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
