// src/lib/api/auth.ts
import { invoke } from '@tauri-apps/api/core';
import type { Credentials } from '@/types';
import type { TokenResponse, User } from '$lib/schema/user';
import { authStore, loginUser, logoutUser } from '$lib/stores/auth';
import { getDb } from '../db';
import { uuid } from '../utils/uuid';
import { getLocalISODateTimeWithOffset } from '../utils/date';
import { Lg } from '../utils/debugLog';

interface AuthError extends Error {
  code?: string;
  details?: unknown;
}

export async function login(
  credentials: Credentials,
  rememberMe = false,
): Promise<User> {
  try {
    const db = await getDb();
    const { email, password } = credentials;

    const rows = await db.select<User[]>(
      'SELECT * FROM users WHERE email = ?',
      [email],
    );

    if (rows.length === 0) {
      throw createAuthError('User not found', 'USER_NOT_FOUND');
    }

    const user = rows[0];

    const isValidPassword = await checkPassword(password, user.password);
    if (!isValidPassword) {
      throw createAuthError('Invalid password', 'INVALID_CREDENTIALS');
    }

    // Generate token
    const tokenResponse = await invoke<TokenResponse>('generate_token', {
      userId: user.serial_num,
      role: user.role,
    });

    // Update auth store
    await loginUser(user, tokenResponse, rememberMe);

    const now = getLocalISODateTimeWithOffset();
    await db.execute(
      'UPDATE users SET last_login_at = ?, last_active_at = ? WHERE serial_num = ?',
      [now, now, user.serial_num],
    );
    return user;
  } catch (error) {
    const authError = handleAuthError(error);
    Lg.e('Api Login', authError);
    throw authError;
  }
}

export async function register(
  credentials: Credentials,
  rememberMe = false,
): Promise<User> {
  try {
    const db = await getDb();
    const { email, username, password } = credentials;

    // 检查是否存在
    const exists = await db.select('SELECT 1 FROM users WHERE email = ?', [
      email,
    ]);
    if ((exists as unknown[]).length > 0) {
      throw createAuthError('Email already registered', 'EMAIL_EXISTS');
    }

    // 生成字段
    const now = getLocalISODateTimeWithOffset();
    const user: Omit<User, 'password'> = {
      serial_num: uuid(38),
      name: username,
      email,
      phone: null,
      avatar_url: null,
      last_login_at: now,
      is_verified: false,
      role: 'User',
      status: 'Active',
      email_verified_at: null,
      phone_verified_at: null,
      bio: null,
      language: 'en',
      timezone: Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC',
      last_active_at: now,
      deleted_at: null,
      created_at: now,
      updated_at: now,
    };

    const password_hash = await hashPassword(password);

    await db.execute(
      `INSERT INTO users (
        serial_num, name, email, phone, password, avatar_url,
        last_login_at, is_verified, role, status, email_verified_at,
        phone_verified_at, bio, language, timezone, last_active_at,
        deleted_at, created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        user.serial_num,
        user.name,
        user.email,
        user.phone,
        password_hash,
        user.avatar_url,
        user.last_login_at,
        user.is_verified ? 1 : 0,
        user.role,
        user.status,
        user.email_verified_at,
        user.phone_verified_at,
        user.bio,
        user.language,
        user.timezone,
        user.last_active_at,
        user.deleted_at,
        user.created_at,
        user.updated_at,
      ],
    );

    // 查询刚刚插入的用户
    const rows = await db.select<User[]>(
      'SELECT * FROM users WHERE email = ?',
      [email],
    );
    const newUser = rows[0];

    if (rememberMe) {
      const tokenResponse = await invoke<TokenResponse>('generate_token', {
        userId: newUser.serial_num,
        role: newUser.role,
      });
      await loginUser(newUser, tokenResponse);
    }

    return newUser;
  } catch (error) {
    const authError = handleAuthError(error);
    Lg.e('Api Registration', authError);
    throw authError;
  }
}

export const hashPassword = async (password: string) => {
  return await invoke<string>('pwd_hash', { pwd: password });
};

export const checkPassword = async (password: string, pwdHash: string) => {
  return await invoke<boolean>('check_pwd', {
    pwd: password,
    pwdHash: pwdHash,
  });
};

export async function verifyToken(
  token: string,
): Promise<'Valid' | 'Expired' | 'Invalid'> {
  try {
    const status = await invoke<string>('is_verify_token', { token });
    if (status === 'Valid' || status === 'Expired' || status === 'Invalid') {
      return status;
    }
    return 'Invalid';
  } catch (error) {
    Lg.e('Api Token verification', error);
    return 'Invalid';
  }
}

export async function maybeLogoutOnExit() {
  if (authStore.state.token && !authStore.state.rememberMe) {
    await logoutUser();
  }
}

export async function checkAndCleanSession() {
  if (authStore.state.token && !authStore.state.rememberMe) {
    await logoutUser();
  }
}

function createAuthError(
  message: string,
  code: string,
  details?: unknown,
): AuthError {
  const error = new Error(message) as AuthError;
  error.code = code;
  error.details = details;
  return error;
}

function handleAuthError(error: unknown): AuthError {
  if (error instanceof Error) {
    return createAuthError(error.message, 'AUTH_ERROR', error);
  }
  return createAuthError('Unknown error occurred', 'UNKNOWN_ERROR');
}
