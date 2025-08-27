import { TokenStatus } from '@/schema/user';
import { invokeCommand, isBusinessError, isSystemError } from '@/types/api';
import { DateUtils } from '../utils/date';
import { Lg } from '../utils/debugLog';
import type {
  CreateUserRequest,
  TokenResponse,
  UpdateUserRequest,
  User,
  UserQuery,
} from '@/schema/user';
import type { Credentials, CredentialsLogin } from '@/types';

// 认证相关的业务错误类
export class AuthError extends Error {
  constructor(
    public code: string,
    message: string,
    public details?: unknown,
  ) {
    super(message);
    this.name = 'AuthError';
  }
}

export async function login(
  credentials: CredentialsLogin,
  rememberMe = false,
): Promise<User> {
  try {
    const { email, password } = credentials;

    const exists = await invokeCommand<boolean>('exists_user', {
      query: { email } as UserQuery,
    });
    if (!exists) {
      throw new AuthError('EMAIL_EXISTS', 'User is not found');
    }

    const user = await invokeCommand<User>('get_user_with_email', {
      email,
    });
    // 使用新的 API 调用方式
    const isValidPassword = await checkPassword(password, user.serialNum);
    if (!isValidPassword) {
      throw new AuthError('INVALID_CREDENTIALS', 'Invalid password');
    }

    // Generate token
    const tokenResponse = await invokeCommand<TokenResponse>('generate_token', {
      userId: user.email,
      role: user.role,
    });
    // Update auth store
    await loginUser(user, tokenResponse, rememberMe);
    const now = DateUtils.getLocalISODateTimeWithOffset();
    const updateUser: UpdateUserRequest = {
      lastActiveAt: now,
      lastLoginAt: now,
    };
    const u = await invokeCommand<User>('update_user', {
      serialNum: user.serialNum,
      data: updateUser,
    });
    return u;
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
    const { email, username, password } = credentials;

    const exists = await invokeCommand<boolean>('exists_user', {
      query: { email } as UserQuery,
    });
    if (exists) {
      throw new AuthError('EMAIL_EXISTS', 'Email already registered');
    }

    // 生成字段
    const user: CreateUserRequest = {
      name: username,
      email,
      password,
      phone: null,
      avatarUrl: null,
      isVerified: false,
      role: 'User',
      status: 'Active',
      bio: null,
      language: 'en',
      timezone: Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC',
    };
    // 使用新的 API 调用方式
    const password_hash = await hashPassword(password);
    user.password = password_hash;

    const result = await invokeCommand<User>('create_user', { data: user });

    if (rememberMe) {
      const tokenResponse = await invokeCommand<TokenResponse>(
        'generate_token',
        {
          userId: result.email,
          role: result.role,
        },
      );
      await loginUser(result, tokenResponse);
    }

    return result;
  } catch (error) {
    const authError = handleAuthError(error);
    Lg.e('Api Registration', authError);
    throw authError;
  }
}

export async function hashPassword(password: string): Promise<string> {
  try {
    return await invokeCommand<string>('pwd_hash', { pwd: password });
  } catch (error) {
    if (isBusinessError(error)) {
      throw new AuthError(
        'PASSWORD_HASH_FAILED',
        `Password hashing failed: ${error.description}`,
        error,
      );
    }
    throw new AuthError('PASSWORD_HASH_ERROR', 'Failed to hash password');
  }
}

export async function checkPassword(
  password: string,
  user_id: string,
): Promise<boolean> {
  try {
    return await invokeCommand<boolean>('check_pwd', {
      pwd: password,
      userId: user_id,
    });
  } catch (error) {
    if (isBusinessError(error)) {
      // 如果是认证失败的业务错误，返回 false 而不是抛出异常
      if (error.code === '100003') {
        // 假设这是认证失败的错误码
        return false;
      }
      throw new AuthError(
        'PASSWORD_CHECK_FAILED',
        `Password verification failed: ${error.description}`,
        error,
      );
    }
    throw new AuthError('PASSWORD_CHECK_ERROR', 'Failed to check password');
  }
}

export async function verifyToken(token: string): Promise<TokenStatus> {
  try {
    const status = await invokeCommand<TokenStatus>('is_verify_token', {
      token,
    });
    return status;
  } catch (error) {
    Lg.e('Api Token verification', error);

    if (isBusinessError(error)) {
      // 根据业务错误码判断 token 状态
      switch (error.code) {
        case '100004': // 假设这是 token 过期的错误码
          return TokenStatus.Expired;
        case '100005': // 假设这是 token 无效的错误码
          return TokenStatus.Invalid;
        default:
          return TokenStatus.Invalid;
      }
    }

    return TokenStatus.Invalid;
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

// 统一的认证错误处理函数
function handleAuthError(error: unknown): AuthError {
  // 如果已经是认证错误，直接返回
  if (error instanceof AuthError) {
    return error;
  }

  // 如果是业务错误，转换为认证错误
  if (isBusinessError(error)) {
    return new AuthError(
      error.code,
      `Authentication failed: ${error.description}`,
      {
        category: error.category,
        module: error.module,
        details: error.details,
      },
    );
  }

  // 如果是系统错误，转换为认证错误
  if (isSystemError(error)) {
    return new AuthError(
      'SYSTEM_ERROR',
      `System error during authentication: ${error.message}`,
      error.originalError,
    );
  }

  // 如果是普通错误，转换为认证错误
  if (error instanceof Error) {
    return new AuthError('AUTH_ERROR', error.message, error);
  }

  // 未知错误
  return new AuthError(
    'UNKNOWN_ERROR',
    'Unknown error occurred during authentication',
  );
}

// 错误类型守卫
export function isAuthError(error: unknown): error is AuthError {
  return error instanceof AuthError;
}

// 获取用户友好的错误信息
export function getAuthErrorMessage(error: AuthError): string {
  const errorMessages: Record<string, string> = {
    USER_NOT_FOUND: '用户不存在',
    INVALID_CREDENTIALS: '密码错误',
    EMAIL_EXISTS: '邮箱已被注册',
    PASSWORD_HASH_FAILED: '密码加密失败',
    PASSWORD_CHECK_FAILED: '密码验证失败',
    SYSTEM_ERROR: '系统错误，请稍后重试',
    AUTH_ERROR: '认证失败',
    UNKNOWN_ERROR: '未知错误',
  };

  return errorMessages[error.code] || error.message;
}
