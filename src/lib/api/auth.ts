// src/lib/api/auth.ts
import { user } from '$lib/stores/auth';
import type { Credentials } from '@/types';
import { invoke } from '@tauri-apps/api/core';
import type { User } from '$lib/schema/user';

export async function login(credentials: Credentials): Promise<User> {
  try {
    const loginCredentials = {
      ...credentials,
      name: credentials.username || credentials.email, // Default to email for login
    };
    const userData: User = await invoke('login_user', {
      credentials: loginCredentials,
    });
    user.set(userData);
    return userData;
  } catch (error) {
    console.error('Login failed:', error);
    throw new Error('Invalid credentials');
  }
}

export async function register(
  credentials: Credentials,
  rememberMe: boolean = false,
): Promise<User> {
  try {
    const userData: User = await invoke('register_user', { credentials });
    user.set(userData);
    if (rememberMe) {
      console.log('Persisting user:', userData);
    }
    return userData;
  } catch (error) {
    console.error('Register failed:', error);
    throw new Error('Registration failed');
  }
}
