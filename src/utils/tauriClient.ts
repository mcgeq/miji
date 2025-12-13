/**
 * 统一 Tauri 命令客户端
 * 提供一致的命令调用、错误处理和拦截器支持
 * @module utils/tauriClient
 */

import { AppErrorSeverity } from '@/errors/appError';
import { invokeCommand, isBusinessError, isSystemError } from '@/types/api';
import { Lg } from './debugLog';
import { wrapError } from './errorHandler';

/**
 * Tauri Client 配置
 */
export interface TauriClientConfig {
  /**
   * 命令超时时间（毫秒）
   */
  timeout?: number;

  /**
   * 重试配置
   */
  retryConfig?: RetryConfig;
}

/**
 * 重试配置
 */
export interface RetryConfig {
  /**
   * 最大重试次数
   */
  maxRetries: number;

  /**
   * 初始重试延迟（毫秒）
   */
  retryDelay: number;

  /**
   * 退避策略
   * - 'linear': 线性退避 (delay * attempt)
   * - 'exponential': 指数退避 (delay * 2^attempt)
   */
  backoffStrategy?: 'linear' | 'exponential';

  /**
   * 最大退避延迟（毫秒），防止延迟过长
   */
  maxBackoffDelay?: number;

  /**
   * 可重试的错误代码列表
   * 如果指定，只有这些错误代码会触发重试
   */
  retryableErrors?: string[];
}

/**
 * 命令拦截器
 */
export interface CommandInterceptor {
  /**
   * 命令执行前拦截
   */
  onCommand?: (
    command: string,
    args: unknown,
  ) => { command: string; args: unknown } | Promise<{ command: string; args: unknown }>;

  /**
   * 命令错误拦截
   */
  onCommandError?: (error: Error) => Error | Promise<Error>;
}

/**
 * 响应拦截器
 */
export interface ResponseInterceptor {
  /**
   * 响应成功拦截
   */
  onResponse?: <T>(response: T) => T | Promise<T>;

  /**
   * 响应错误拦截
   */
  onResponseError?: (error: Error) => Error | Promise<Error>;
}

/**
 * 统一 Tauri 命令客户端类
 */
export class TauriClient {
  private config: TauriClientConfig;
  private commandInterceptors: CommandInterceptor[] = [];
  private responseInterceptors: ResponseInterceptor[] = [];

  constructor(config: TauriClientConfig = {}) {
    this.config = {
      timeout: 30000,
      retryConfig: {
        maxRetries: 3,
        retryDelay: 1000,
        backoffStrategy: 'exponential',
        maxBackoffDelay: 10000,
        retryableErrors: ['DATABASE_LOCKED', 'TIMEOUT', 'NETWORK_ERROR'],
      },
      ...config,
    };
  }

  /**
   * 注册命令拦截器
   */
  useCommandInterceptor(interceptor: CommandInterceptor): void {
    this.commandInterceptors.push(interceptor);
  }

  /**
   * 注册响应拦截器
   */
  useResponseInterceptor(interceptor: ResponseInterceptor): void {
    this.responseInterceptors.push(interceptor);
  }

  /**
   * 执行 Tauri 命令
   */
  async invoke<T>(command: string, args?: unknown): Promise<T> {
    let currentCommand = command;
    let currentArgs = args;

    try {
      // 执行命令拦截器
      for (const interceptor of this.commandInterceptors) {
        if (interceptor.onCommand) {
          const result = await interceptor.onCommand(currentCommand, currentArgs);
          currentCommand = result.command;
          currentArgs = result.args;
        }
      }

      // 执行命令（带超时和重试）
      const result = await this.invokeWithRetry<T>(currentCommand, currentArgs);

      // 执行响应拦截器
      let currentResult = result;
      for (const interceptor of this.responseInterceptors) {
        if (interceptor.onResponse) {
          currentResult = await interceptor.onResponse(currentResult);
        }
      }

      return currentResult;
    } catch (error) {
      // 记录错误日志
      Lg.e('TauriClient', `命令执行失败: ${currentCommand}`, {
        command: currentCommand,
        args: currentArgs,
        error: error instanceof Error ? error.message : String(error),
      });

      // 执行错误拦截器
      let currentError = error;
      for (const interceptor of this.responseInterceptors) {
        if (interceptor.onResponseError) {
          currentError = await interceptor.onResponseError(currentError as Error);
        }
      }

      // 包装为 AppError 并抛出
      const wrappedError = wrapError(
        'TauriClient',
        currentError,
        'COMMAND_FAILED',
        `命令执行失败: ${currentCommand}`,
      );

      // 记录包装后的错误
      wrappedError.log();

      throw wrappedError;
    }
  }

  /**
   * 带重试的命令执行
   */
  private async invokeWithRetry<T>(command: string, args?: unknown): Promise<T> {
    const { maxRetries, retryDelay, backoffStrategy, maxBackoffDelay, retryableErrors } =
      this.config.retryConfig!;
    let lastError: Error | null = null;

    for (let attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        return await this.invokeWithTimeout<T>(command, args);
      } catch (error) {
        lastError = error as Error;

        // 检查是否应该重试此错误
        const shouldRetry = this.shouldRetryError(error, retryableErrors);

        if (!shouldRetry) {
          // 不可重试的错误，直接抛出
          Lg.w('TauriClient', `错误不可重试，直接抛出: ${command}`, {
            error: error instanceof Error ? error.message : String(error),
          });
          throw error;
        }

        // 如果还有重试机会
        if (attempt < maxRetries) {
          // 计算退避延迟
          const backoffDelay = this.calculateBackoffDelay(
            attempt,
            retryDelay,
            backoffStrategy || 'exponential',
            maxBackoffDelay || 10000,
          );

          Lg.w('TauriClient', `命令重试 ${attempt + 1}/${maxRetries}: ${command}`, {
            attempt: attempt + 1,
            maxRetries,
            backoffDelay,
            error: error instanceof Error ? error.message : String(error),
          });

          // 等待后重试
          await this.delay(backoffDelay);
        } else {
          // 最后一次尝试失败，记录错误
          Lg.e('TauriClient', `命令重试失败，已达最大重试次数: ${command}`, {
            attempts: maxRetries + 1,
            error: error instanceof Error ? error.message : String(error),
          });
        }
      }
    }

    // 包装最终错误
    throw wrapError(
      'TauriClient',
      lastError,
      'RETRY_EXHAUSTED',
      `命令重试失败: ${command} (已尝试 ${maxRetries + 1} 次)`,
    );
  }

  /**
   * 判断错误是否应该重试
   */
  private shouldRetryError(error: unknown, retryableErrors?: string[]): boolean {
    // 如果没有指定可重试错误列表，默认所有错误都可重试
    if (!retryableErrors || retryableErrors.length === 0) {
      return true;
    }

    // 检查错误代码是否在可重试列表中
    if (error && typeof error === 'object' && 'code' in error) {
      const errorCode = (error as { code: string }).code;
      if (retryableErrors.includes(errorCode)) {
        return true;
      }

      // 如果是包装后的错误，检查原始错误
      if ('originalError' in error) {
        const originalError = (error as { originalError: unknown }).originalError;
        if (originalError && typeof originalError === 'object' && 'code' in originalError) {
          const originalCode = (originalError as { code: string }).code;
          if (retryableErrors.includes(originalCode)) {
            return true;
          }
        }
      }
    }

    // 检查错误消息是否包含可重试的关键词
    if (error instanceof Error) {
      const errorMessage = error.message.toLowerCase();
      return retryableErrors.some(code =>
        errorMessage.includes(code.toLowerCase().replace('_', ' ')),
      );
    }

    return false;
  }

  /**
   * 计算退避延迟
   */
  private calculateBackoffDelay(
    attempt: number,
    baseDelay: number,
    strategy: 'linear' | 'exponential',
    maxDelay: number,
  ): number {
    let delay: number;

    if (strategy === 'exponential') {
      // 指数退避: baseDelay * 2^attempt
      delay = baseDelay * 2 ** attempt;
    } else {
      // 线性退避: baseDelay * (attempt + 1)
      delay = baseDelay * (attempt + 1);
    }

    // 限制最大延迟
    return Math.min(delay, maxDelay);
  }

  /**
   * 带超时的命令执行
   */
  private async invokeWithTimeout<T>(command: string, args?: unknown): Promise<T> {
    try {
      // 使用项目现有的 invokeCommand，它已经包含超时处理
      return await invokeCommand<T>(command, args as Record<string, unknown>, this.config.timeout);
    } catch (error) {
      // 处理不同类型的错误
      if (isSystemError(error)) {
        // 系统错误（如超时、网络错误等）
        const errorMessage = error.message;
        if (errorMessage.includes('timeout') || errorMessage.includes('超时')) {
          throw wrapError(
            'TauriClient',
            error,
            'TIMEOUT',
            `命令执行超时: ${command} (超时时间: ${this.config.timeout}ms)`,
            AppErrorSeverity.HIGH,
          );
        }

        // 其他系统错误
        throw wrapError(
          'TauriClient',
          error,
          'SYSTEM_ERROR',
          `系统错误: ${command} - ${errorMessage}`,
          AppErrorSeverity.HIGH,
        );
      }

      if (isBusinessError(error)) {
        // 业务错误，包装但保留原始信息
        throw wrapError(
          'TauriClient',
          error,
          error.code,
          `业务错误: ${command} - ${error.description}`,
          AppErrorSeverity.MEDIUM,
        );
      }

      // 未知错误
      throw wrapError(
        'TauriClient',
        error,
        'UNKNOWN_ERROR',
        `未知错误: ${command}`,
        AppErrorSeverity.HIGH,
      );
    }
  }

  /**
   * 延迟工具函数
   */
  private delay(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}

/**
 * 默认 Tauri Client 实例
 */
export const defaultTauriClient = new TauriClient();

// 配置默认拦截器
import { createLoggingInterceptor, createUserContextInterceptor } from './tauriClient/interceptors';

/**
 * 获取当前用户 ID
 * 使用延迟导入避免循环依赖
 */
function getCurrentUserId(): string | undefined {
  try {
    // 动态导入 auth store 以避免循环依赖
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const { useAuthStore } = require('@/stores/auth');
    const authStore = useAuthStore();
    return authStore.user?.serialNum;
  } catch (_error) {
    // 如果 auth store 还未初始化，返回 undefined
    return undefined;
  }
}

// 注册用户上下文拦截器
const userContextInterceptor = createUserContextInterceptor(getCurrentUserId);
defaultTauriClient.useCommandInterceptor(userContextInterceptor);

// 只在开发环境启用日志
if (import.meta.env.DEV) {
  const { commandInterceptor, responseInterceptor } = createLoggingInterceptor({
    logCommands: true,
    logResponses: false, // 响应可能很大，默认不记录
    logErrors: true,
  });

  defaultTauriClient.useCommandInterceptor(commandInterceptor);
  defaultTauriClient.useResponseInterceptor(responseInterceptor);
}
