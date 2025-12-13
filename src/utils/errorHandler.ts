/**
 * 统一错误处理工具
 * 提供一致的错误创建和处理方法
 */

import { AppError, AppErrorSeverity } from '@/errors/appError';

/**
 * 创建应用错误
 * 统一的错误创建接口，避免直接使用 throw new Error()
 */
export function createAppError(
  module: string,
  code: string,
  message: string,
  severity: AppErrorSeverity = AppErrorSeverity.MEDIUM,
  _details?: unknown,
): AppError {
  return AppError.wrap(module, new Error(message), code, message, severity);
}

/**
 * 抛出应用错误
 * 便捷方法，创建并抛出错误
 */
export function throwAppError(
  module: string,
  code: string,
  message: string,
  severity: AppErrorSeverity = AppErrorSeverity.MEDIUM,
  _details?: unknown,
): never {
  throw createAppError(module, code, message, severity);
}

/**
 * 包装现有错误为 AppError
 */
export function wrapError(
  module: string,
  error: unknown,
  code: string,
  message?: string,
  severity: AppErrorSeverity = AppErrorSeverity.MEDIUM,
): AppError {
  const errorMessage = message || (error instanceof Error ? error.message : String(error));
  return AppError.wrap(module, error, code, errorMessage, severity);
}

/**
 * 验证条件，失败时抛出错误
 */
export function assert(
  condition: boolean,
  module: string,
  code: string,
  message: string,
  severity: AppErrorSeverity = AppErrorSeverity.MEDIUM,
): asserts condition {
  if (!condition) {
    throwAppError(module, code, message, severity);
  }
}

/**
 * 检查值是否存在，不存在时抛出错误
 */
export function assertExists<T>(
  value: T | null | undefined,
  module: string,
  code: string,
  message: string,
  severity: AppErrorSeverity = AppErrorSeverity.MEDIUM,
): asserts value is T {
  if (value === null || value === undefined) {
    throwAppError(module, code, message, severity);
  }
}
