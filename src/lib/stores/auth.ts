// src/lib/stores/auth.ts
import { RuneStore } from '@tauri-store/svelte';
import type { AuthUser, User, TokenResponse } from '$lib/schema/user';
import { toAuthUser } from '../utils/user';
import { verifyToken } from '../api/auth';

export const authStore = new RuneStore('auth', {
  user: null as AuthUser | null,
  token: null as string | null,
  tokenExpiresAt: null as number | null,
});

export function getCurrentUser(): AuthUser | null {
  return authStore.state.user;
}

export async function loginUser(user: User, tokenResponse?: TokenResponse) {
  const authUser = toAuthUser(user);
  authStore.state.user = authUser;

  if (tokenResponse) {
    authStore.state.token = tokenResponse.token;
    authStore.state.tokenExpiresAt = tokenResponse.expires_at;

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
  const { user, token, tokenExpiresAt } = authStore.state;

  if (!user || !token || !tokenExpiresAt) {
    return false;
  }

  // Check if token is expired
  if (tokenExpiresAt < Date.now() / 1000) {
    await logoutUser();
    return false;
  }

  // Verify token
  const tokenStatus = await verifyToken(token);
  if (tokenStatus !== 'Valid') {
    await logoutUser();
    return false;
  }

  return true;
}
