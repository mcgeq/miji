/**
 * Tauri Client 拦截器
 * 提供常用的拦截器实现
 * @module utils/tauriClient/interceptors
 */

import { Lg } from '../debugLog';
import type { CommandInterceptor, ResponseInterceptor } from '../tauriClient';

/**
 * 创建用户上下文拦截器
 * 自动添加用户 ID 到命令参数
 *
 * @param getUserId - 获取用户 ID 的函数
 * @returns 命令拦截器
 *
 * @example
 * ```typescript
 * import { useAuthStore } from '@/stores/auth';
 *
 * const authStore = useAuthStore();
 * const userContextInterceptor = createUserContextInterceptor(() => authStore.user?.id);
 *
 * tauriClient.useCommandInterceptor(userContextInterceptor);
 * ```
 */
export function createUserContextInterceptor(
  getUserId: () => string | undefined,
): CommandInterceptor {
  return {
    onCommand: (command, args) => {
      const userId = getUserId();
      if (userId && args && typeof args === 'object') {
        return {
          command,
          args: {
            ...args,
            userId,
          },
        };
      }
      return { command, args };
    },
  };
}

/**
 * 创建日志拦截器
 * 记录命令和响应
 *
 * @param options - 日志选项
 * @returns 命令和响应拦截器
 *
 * @example
 * ```typescript
 * const { commandInterceptor, responseInterceptor } = createLoggingInterceptor({
 *   logCommands: true,
 *   logResponses: true,
 *   logErrors: true,
 * });
 *
 * tauriClient.useCommandInterceptor(commandInterceptor);
 * tauriClient.useResponseInterceptor(responseInterceptor);
 * ```
 */
export function createLoggingInterceptor(options: {
  logCommands?: boolean;
  logResponses?: boolean;
  logErrors?: boolean;
}): {
  commandInterceptor: CommandInterceptor;
  responseInterceptor: ResponseInterceptor;
} {
  const { logCommands = true, logResponses = true, logErrors = true } = options;

  return {
    commandInterceptor: {
      onCommand: (command, args) => {
        if (logCommands) {
          Lg.i('TauriCommand', `执行命令: ${command}`, args);
        }
        return { command, args };
      },
    },
    responseInterceptor: {
      onResponse: response => {
        if (logResponses) {
          Lg.i('TauriResponse', '命令响应:', response);
        }
        return response;
      },
      onResponseError: error => {
        if (logErrors) {
          Lg.e('TauriError', '命令错误:', error);
        }
        return error;
      },
    },
  };
}

/**
 * 创建性能监控拦截器
 * 记录命令执行时间
 *
 * @param threshold - 慢命令阈值（毫秒），超过此时间会记录警告
 * @returns 命令和响应拦截器
 *
 * @example
 * ```typescript
 * const { commandInterceptor, responseInterceptor } = createPerformanceInterceptor(1000);
 *
 * tauriClient.useCommandInterceptor(commandInterceptor);
 * tauriClient.useResponseInterceptor(responseInterceptor);
 * ```
 */
export function createPerformanceInterceptor(threshold = 1000): {
  commandInterceptor: CommandInterceptor;
  responseInterceptor: ResponseInterceptor;
} {
  const timings = new Map<string, number>();

  return {
    commandInterceptor: {
      onCommand: (command, args) => {
        const key = `${command}_${Date.now()}`;
        timings.set(key, Date.now());
        return { command, args };
      },
    },
    responseInterceptor: {
      onResponse: response => {
        // 找到最近的计时记录
        const entries = Array.from(timings.entries());
        if (entries.length > 0) {
          const [key, startTime] = entries[entries.length - 1];
          const duration = Date.now() - startTime;

          if (duration > threshold) {
            Lg.w('Performance', `慢命令: ${key.split('_')[0]} (${duration}ms)`);
          }

          timings.delete(key);
        }
        return response;
      },
      onResponseError: error => {
        // 清理计时记录
        const entries = Array.from(timings.entries());
        if (entries.length > 0) {
          const [key] = entries[entries.length - 1];
          timings.delete(key);
        }
        return error;
      },
    },
  };
}

/**
 * 创建错误处理拦截器
 * 统一处理和记录错误
 *
 * @param options - 错误处理选项
 * @returns 响应拦截器
 *
 * @example
 * ```typescript
 * const errorInterceptor = createErrorHandlingInterceptor({
 *   logErrors: true,
 *   transformError: (error) => {
 *     // 自定义错误转换逻辑
 *     return error;
 *   },
 * });
 *
 * tauriClient.useResponseInterceptor(errorInterceptor);
 * ```
 */
export function createErrorHandlingInterceptor(options: {
  logErrors?: boolean;
  transformError?: (error: Error) => Error | Promise<Error>;
}): ResponseInterceptor {
  const { logErrors = true, transformError } = options;

  return {
    onResponseError: async error => {
      // 记录错误
      if (logErrors) {
        Lg.e('TauriError', '命令执行错误', {
          message: error.message,
          name: error.name,
          stack: error.stack,
        });
      }

      // 转换错误（如果提供了转换函数）
      if (transformError) {
        return await transformError(error);
      }

      return error;
    },
  };
}
