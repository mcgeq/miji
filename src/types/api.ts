// types/api.ts - 创建与后端对应的 API Response 类型
import { invoke } from '@tauri-apps/api/core';

/////////////////////////
// API 响应类型
/////////////////////////
export interface ApiResponse<T = unknown> {
  success: boolean;
  code: string; // 6 位错误码
  data?: T;
  error?: ErrorPayload;
}

export interface ErrorPayload {
  code: string;
  message: string;
  details?: Record<string, string[] | string>;
  description: string;
  category: string;
  module: string;
}

// 业务异常类
export class BusinessError extends Error {
  constructor(
    public code: string,
    public description: string,
    public category: string,
    public module: string,
    public details?: Record<string, string[] | string>,
    public requestInfo?: {
      command?: string;
      args?: unknown;
    },
  ) {
    super(description);
    this.name = 'BusinessError';
  }
}

export class SystemError extends Error {
  constructor(
    message: string,
    public originalError?: unknown,
  ) {
    super(message);
    this.name = 'SystemError';
  }
}

// 错误类型守卫
export function isBusinessError(error: unknown): error is BusinessError {
  return error instanceof BusinessError;
}

export function isSystemError(error: unknown): error is SystemError {
  return error instanceof SystemError;
}

/////////////////////////
// 响应处理
/////////////////////////
function handleApiResponse<T>(response: ApiResponse<T>): T {
  if (!response.success) {
    if (!response.error) {
      throw new SystemError('API response failed but no error details provided');
    }
    const error = response.error;
    // 如果是验证错误且 details 是对象，自动映射到字段
    let details: Record<string, string[] | string> | undefined;
    if (
      error.category === 'Validation' &&
      typeof error.details === 'object' &&
      error.details !== null
    ) {
      details = error.details as Record<string, string[] | string>;
    }
    throw new BusinessError(error.code, error.description, error.category, error.module, details);
  }
  return response.data ?? (null as unknown as T);
}

// 专门处理可能返回空数据的命令
export async function invokeCommandWithEmptyResponse(
  command: string,
  args?: Record<string, unknown>,
): Promise<void> {
  await invokeCommand<void>(command, args);
}

// 统一的错误处理函数
export function handleApiError(error: unknown): never {
  if (isBusinessError(error)) {
    if (error.category === 'Validation' && error.details) {
      console.warn('Form Validation Error:', error.details);
    } else {
      console.error('Business Error:', error);
    }
  } else if (isSystemError(error)) {
    console.error('System Error:', error.message, error.originalError);
  } else {
    console.error('Unknown Error:', error);
  }
  throw error;
}

// API 调用工具函数
export async function invokeCommand<T = void>(
  command: string,
  args?: Record<string, unknown>,
  timeout = 5000,
): Promise<T> {
  try {
    const response = await Promise.race([
      invoke<ApiResponse<T>>(command, args),
      new Promise<never>((_, reject) =>
        setTimeout(() => reject(new SystemError('Request timeout')), timeout),
      ),
    ]);
    return handleApiResponse(response);
  } catch (error) {
    // 如果是 Tauri 层面的错误（比如网络错误、序列化错误等）
    if (!(error instanceof BusinessError)) {
      throw new SystemError(`System error: ${error}`);
    }
    throw error;
  }
}
