/**
 * Auth API Functions
 * Wrapper functions around authService for backward compatibility
 * @module services/auth
 */

import type { TokenResponse, User } from '@/schema/user';
import { useAuthStore } from '@/stores/auth';
import type { Credentials, CredentialsLogin } from '@/types';
import { authService } from './authService';

/**
 * Login user
 * @param credentials - Login credentials
 * @param rememberMe - Whether to remember the user
 * @returns User information
 */
export async function login(credentials: CredentialsLogin, rememberMe = false): Promise<User> {
  const result = await authService.login(credentials);

  // Update auth store
  const authStore = useAuthStore();
  await authStore.login(result.user, result.tokenResponse, rememberMe);

  return result.user;
}

/**
 * Register new user
 * @param credentials - Registration credentials
 * @param rememberMe - Whether to remember the user
 * @returns User information
 */
export async function register(credentials: Credentials, rememberMe = false): Promise<User> {
  const user = await authService.register(credentials);

  if (rememberMe) {
    const result = await authService.login({
      email: credentials.email,
      password: credentials.password,
    });

    const authStore = useAuthStore();
    await authStore.login(result.user, result.tokenResponse, rememberMe);
  }

  return user;
}

/**
 * Refresh authentication token
 * @param token - Current token
 * @returns New token response
 */
export async function refreshToken(token: string): Promise<TokenResponse> {
  return authService.refreshToken(token);
}

/**
 * Check and clean session if not remembered
 * Used on app exit
 */
export async function checkAndCleanSession(): Promise<void> {
  const authStore = useAuthStore();
  if (authStore.token && !authStore.rememberMe) {
    await authStore.logout();
  }
}

/**
 * Maybe logout on exit if session is not remembered
 */
export async function maybeLogoutOnExit(): Promise<void> {
  await checkAndCleanSession();
}
