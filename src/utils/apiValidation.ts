/**
 * API 响应验证工具
 *
 * 提供运行时类型验证，确保 API 响应符合预期的 Zod schema
 */

import type { ZodType, ZodError } from 'zod';
import { AppError } from '@/errors/appError';

/** API 验证错误代码 */
export enum ApiValidationErrorCode {
  INVALID_RESPONSE = 'INVALID_RESPONSE',
  SCHEMA_VALIDATION_FAILED = 'SCHEMA_VALIDATION_FAILED',
  UNEXPECTED_NULL = 'UNEXPECTED_NULL',
}

/**
 * 验证 API 响应数据
 *
 * @param data - API 返回的原始数据
 * @param schema - Zod schema 用于验证
 * @param context - 错误上下文信息
 * @returns 验证后的类型安全数据
 * @throws AppError 如果验证失败
 *
 * @example
 * ```ts
 * const todo = validateApiResponse(response, TodoSchema, 'fetchTodo');
 * ```
 */
export function validateApiResponse<T>(
  data: unknown,
  schema: ZodType<T>,
  context: string,
): T {
  const result = schema.safeParse(data);

  if (!result.success) {
    const error = AppError.wrap(
      'api',
      result.error,
      ApiValidationErrorCode.SCHEMA_VALIDATION_FAILED,
      `API 响应验证失败 [${context}]: ${formatZodError(result.error)}`,
    );
    error.log();
    throw error;
  }

  return result.data;
}

/**
 * 安全验证 API 响应数据（不抛出异常）
 *
 * @param data - API 返回的原始数据
 * @param schema - Zod schema 用于验证
 * @param context - 错误上下文信息
 * @returns 验证结果对象
 *
 * @example
 * ```ts
 * const result = validateApiResponseSafe(response, TodoSchema, 'fetchTodo');
 * if (result.success) {
 *   console.log(result.data);
 * } else {
 *   console.error(result.error);
 * }
 * ```
 */
export function validateApiResponseSafe<T>(
  data: unknown,
  schema: ZodType<T>,
  context: string,
): { success: true; data: T } | { success: false; error: AppError } {
  const result = schema.safeParse(data);

  if (!result.success) {
    const error = AppError.wrap(
      'api',
      result.error,
      ApiValidationErrorCode.SCHEMA_VALIDATION_FAILED,
      `API 响应验证失败 [${context}]: ${formatZodError(result.error)}`,
    );
    return { success: false, error };
  }

  return { success: true, data: result.data };
}

/**
 * 验证 API 响应数组
 *
 * @param data - API 返回的原始数组数据
 * @param schema - 单个元素的 Zod schema
 * @param context - 错误上下文信息
 * @returns 验证后的类型安全数组
 */
export function validateApiArrayResponse<T>(
  data: unknown,
  schema: ZodType<T>,
  context: string,
): T[] {
  if (!Array.isArray(data)) {
    const error = AppError.wrap(
      'api',
      new Error('Expected array response'),
      ApiValidationErrorCode.INVALID_RESPONSE,
      `API 响应应为数组 [${context}]`,
    );
    error.log();
    throw error;
  }

  return data.map((item, index) => {
    const result = schema.safeParse(item);
    if (!result.success) {
      const error = AppError.wrap(
        'api',
        result.error,
        ApiValidationErrorCode.SCHEMA_VALIDATION_FAILED,
        `API 数组响应验证失败 [${context}][${index}]: ${formatZodError(result.error)}`,
      );
      error.log();
      throw error;
    }
    return result.data;
  });
}

/**
 * 验证可空 API 响应
 *
 * @param data - API 返回的原始数据（可能为 null）
 * @param schema - Zod schema 用于验证
 * @param context - 错误上下文信息
 * @returns 验证后的数据或 null
 */
export function validateApiNullableResponse<T>(
  data: unknown,
  schema: ZodType<T>,
  context: string,
): T | null {
  if (data === null || data === undefined) {
    return null;
  }

  return validateApiResponse(data, schema, context);
}

/**
 * 格式化 Zod 错误信息
 */
function formatZodError(error: ZodError): string {
  // Zod 4 uses 'issues' instead of 'errors'
  return error.issues
    .map(issue => {
      const path = issue.path.join('.');
      return path ? `${path}: ${issue.message}` : issue.message;
    })
    .join('; ');
}

/**
 * 创建带验证的 API 调用包装器
 *
 * @param apiCall - 原始 API 调用函数
 * @param schema - 响应验证 schema
 * @param context - 错误上下文
 * @returns 带验证的 API 调用函数
 *
 * @example
 * ```ts
 * const fetchTodoValidated = withValidation(
 *   () => invokeCommand<Todo>('todo_get', { serialNum }),
 *   TodoSchema,
 *   'fetchTodo'
 * );
 * const todo = await fetchTodoValidated();
 * ```
 */
export function withValidation<T>(
  apiCall: () => Promise<unknown>,
  schema: ZodType<T>,
  context: string,
): () => Promise<T> {
  return async () => {
    const data = await apiCall();
    return validateApiResponse(data, schema, context);
  };
}

/**
 * 创建带数组验证的 API 调用包装器
 */
export function withArrayValidation<T>(
  apiCall: () => Promise<unknown>,
  schema: ZodType<T>,
  context: string,
): () => Promise<T[]> {
  return async () => {
    const data = await apiCall();
    return validateApiArrayResponse(data, schema, context);
  };
}
