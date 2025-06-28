// src/services/auth.ts
import { invoke } from '@tauri-apps/api/core';
import type { Credentials, CredentialsLogin } from '@/types';
import type { TokenResponse, User } from '@/schema/user';
import { authStore, loginUser, logoutUser } from '@/stores/auth';
import { getDb } from '../db';
import { uuid } from '../utils/uuid';
import { getLocalISODateTimeWithOffset } from '../utils/date';
import { Lg } from '../utils/debugLog';
import { toCamelCase } from '../utils/common';

interface AuthError extends Error {
  code?: string;
  details?: unknown;
}

export async function login(
  credentials: CredentialsLogin,
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

    const user = toCamelCase(rows[0]);

    const isValidPassword = await checkPassword(password, user.password);
    if (!isValidPassword) {
      throw createAuthError('Invalid password', 'INVALID_CREDENTIALS');
    }

    // Generate token
    const tokenResponse = await invoke<TokenResponse>('generate_token', {
      userId: user.email,
      role: user.role,
    });
    // Update auth store
    await loginUser(user, tokenResponse, rememberMe);

    const now = getLocalISODateTimeWithOffset();
    await db.execute(
      'UPDATE users SET last_login_at = ?, last_active_at = ? WHERE serial_num = ?',
      [now, now, user.serialNum],
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
      serialNum: uuid(38),
      name: username,
      email,
      phone: null,
      avatarUrl: null,
      lastLoginAt: now,
      isVerified: false,
      role: 'User',
      status: 'Active',
      emailVerifiedAt: null,
      phoneVerifiedAt: null,
      bio: null,
      language: 'en',
      timezone: Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC',
      lastActiveAt: now,
      deletedAt: null,
      createdAt: now,
      updatedAt: now,
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
        user.serialNum,
        user.name,
        user.email,
        user.phone,
        password_hash,
        user.avatarUrl,
        user.lastLoginAt,
        user.isVerified ? 1 : 0,
        user.role,
        user.status,
        user.emailVerifiedAt,
        user.phoneVerifiedAt,
        user.bio,
        user.language,
        user.timezone,
        user.lastActiveAt,
        user.deletedAt,
        user.createdAt,
        user.updatedAt,
      ],
    );

    // 查询刚刚插入的用户
    const rows = await db.select<User[]>(
      'SELECT * FROM users WHERE email = ?',
      [email],
    );
    const newUser = toCamelCase(rows[0]);

    if (rememberMe) {
      const tokenResponse = await invoke<TokenResponse>('generate_token', {
        userId: newUser.email,
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
  if (authStore.value.token && !authStore.value.rememberMe) {
    await logoutUser();
  }
}

export async function checkAndCleanSession() {
  if (authStore.value.token && !authStore.value.rememberMe) {
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
