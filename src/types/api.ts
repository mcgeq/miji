// types/api.ts - 创建与后端对应的 API Response 类型
import { invoke } from '@tauri-apps/api/core';

export interface ApiResponse<T = any> {
  success: boolean;
  code: string; // 6 位错误码
  data?: T;
  error?: ErrorPayload;
}

export interface ErrorPayload {
  code: string;
  message: string;
  details?: any;
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
    public details?: any,
  ) {
    super(description);
    this.name = 'BusinessError';
  }
}

export class SystemError extends Error {
  constructor(message: string, public originalError?: unknown) {
    super(message);
    this.name = 'SystemError';
  }
}

// API 调用工具函数
export async function invokeCommand<T>(
  command: string,
  args?: Record<string, any>,
): Promise<T> {
  try {
    const response = await invoke<ApiResponse<T>>(command, args);

    if (!response.success) {
      const error = response.error!;
      throw new BusinessError(
        error.code,
        error.description,
        error.category,
        error.module,
        error.details,
      );
    }

    return response.data!;
  } catch (error) {
    // 如果是 Tauri 层面的错误（比如网络错误、序列化错误等）
    if (!(error instanceof BusinessError)) {
      throw new SystemError(`System error: ${error}`);
    }
    throw error;
  }
}

// 专门处理可能返回空数据的命令
export async function invokeCommandWithEmptyResponse(
  command: string,
  args?: Record<string, any>,
): Promise<void> {
  try {
    const response = await invoke<ApiResponse<void>>(command, args);

    if (!response.success) {
      const error = response.error!;
      throw new BusinessError(
        error.code,
        error.description,
        error.category,
        error.module,
        error.details,
      );
    }
  } catch (error) {
    if (!(error instanceof BusinessError)) {
      throw new SystemError(`System error: ${error}`);
    }
    throw error;
  }
}

// 错误类型守卫
export function isBusinessError(error: unknown): error is BusinessError {
  return error instanceof BusinessError;
}

export function isSystemError(error: unknown): error is SystemError {
  return error instanceof SystemError;
}

// 统一的错误处理函数
export function handleApiError(error: unknown): never {
  if (isBusinessError(error)) {
    console.error('Business Error:', {
      code: error.code,
      description: error.description,
      category: error.category,
      module: error.module,
      details: error.details,
    });
  } else if (isSystemError(error)) {
    console.error('System Error:', error.message, error.originalError);
  } else {
    console.error('Unknown Error:', error);
  }
  throw error;
}
