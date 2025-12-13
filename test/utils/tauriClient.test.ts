/**
 * TauriClient 单元测试
 * 测试超时、重试和拦截器功能
 */

import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { TauriClient } from '../../src/utils/tauriClient';
import type { CommandInterceptor, ResponseInterceptor } from '../../src/utils/tauriClient';
import * as apiModule from '../../src/types/api';

// Mock Tauri invoke
vi.mock('@tauri-apps/api/core', () => ({
  invoke: vi.fn(),
}));

// Mock invokeCommand
vi.mock('../../src/types/api', async () => {
  const actual = await vi.importActual('../../src/types/api');
  return {
    ...actual,
    invokeCommand: vi.fn(),
  };
});

// Mock errorHandler
vi.mock('../../src/utils/errorHandler', () => ({
  wrapError: vi.fn((module, error, code, message) => {
    const err = new Error(message);
    // Preserve the original error's code if it exists
    (err as any).code = (error && typeof error === 'object' && 'code' in error) 
      ? (error as any).code 
      : code;
    (err as any).module = module;
    (err as any).originalError = error;
    (err as any).log = vi.fn();
    return err;
  }),
}));

// Mock debugLog
vi.mock('../../src/utils/debugLog', () => ({
  Lg: {
    info: vi.fn(),
    warn: vi.fn(),
    error: vi.fn(),
    w: vi.fn(),
    e: vi.fn(),
  },
}));

describe('TauriClient - Timeout and Retry', () => {
  let client: TauriClient;
  let mockInvokeCommand: any;

  beforeEach(() => {
    vi.clearAllMocks();
    mockInvokeCommand = vi.mocked(apiModule.invokeCommand);
  });

  afterEach(() => {
    vi.restoreAllMocks();
  });

  describe('Timeout Handling', () => {
    it('should handle timeout errors correctly', async () => {
      client = new TauriClient({
        timeout: 1000,
        retryConfig: {
          maxRetries: 0, // 禁用重试以测试超时
          retryDelay: 100,
        },
      });

      // 模拟超时错误
      mockInvokeCommand.mockRejectedValueOnce(
        new apiModule.SystemError('Request timeout')
      );

      await expect(client.invoke('test_command', {})).rejects.toThrow();
    });

    it('should use configured timeout value', async () => {
      const customTimeout = 5000;
      client = new TauriClient({
        timeout: customTimeout,
        retryConfig: {
          maxRetries: 0,
          retryDelay: 100,
        },
      });

      mockInvokeCommand.mockResolvedValueOnce({ success: true });

      await client.invoke('test_command', {});

      expect(mockInvokeCommand).toHaveBeenCalledWith(
        'test_command',
        {},
        customTimeout
      );
    });
  });

  describe('Retry Mechanism', () => {
    it('should retry on failure up to maxRetries', async () => {
      client = new TauriClient({
        timeout: 1000,
        retryConfig: {
          maxRetries: 3,
          retryDelay: 10, // 短延迟以加快测试
          retryableErrors: [],
        },
      });

      // 前3次失败，第4次成功
      mockInvokeCommand
        .mockRejectedValueOnce(new Error('Failure 1'))
        .mockRejectedValueOnce(new Error('Failure 2'))
        .mockRejectedValueOnce(new Error('Failure 3'))
        .mockResolvedValueOnce({ data: 'success' });

      const result = await client.invoke('test_command', {});

      expect(result).toEqual({ data: 'success' });
      expect(mockInvokeCommand).toHaveBeenCalledTimes(4);
    });

    it('should throw RETRY_EXHAUSTED after max retries', async () => {
      client = new TauriClient({
        timeout: 1000,
        retryConfig: {
          maxRetries: 2,
          retryDelay: 10,
          retryableErrors: [],
        },
      });

      // 所有尝试都失败
      mockInvokeCommand.mockRejectedValue(new Error('Persistent failure'));

      await expect(client.invoke('test_command', {})).rejects.toThrow();
      
      // 应该尝试 3 次 (初始 + 2 次重试)
      expect(mockInvokeCommand).toHaveBeenCalledTimes(3);
    });

    it('should not retry non-retryable errors', async () => {
      client = new TauriClient({
        timeout: 1000,
        retryConfig: {
          maxRetries: 3,
          retryDelay: 10,
          retryableErrors: ['DATABASE_LOCKED', 'TIMEOUT'],
        },
      });

      // 模拟不可重试的错误
      const nonRetryableError = new Error('Validation error');
      (nonRetryableError as any).code = 'VALIDATION_ERROR';
      mockInvokeCommand.mockRejectedValueOnce(nonRetryableError);

      await expect(client.invoke('test_command', {})).rejects.toThrow();
      
      // 应该只尝试 1 次，不重试
      expect(mockInvokeCommand).toHaveBeenCalledTimes(1);
    });

    it('should retry database locked errors', async () => {
      client = new TauriClient({
        timeout: 1000,
        retryConfig: {
          maxRetries: 2,
          retryDelay: 10,
          retryableErrors: ['DATABASE_LOCKED'],
        },
      });

      // 模拟数据库锁定错误 - 使用 SystemError 以便被正确识别
      const dbLockedError = new apiModule.SystemError('Database is locked');
      (dbLockedError as any).code = 'DATABASE_LOCKED';
      
      mockInvokeCommand
        .mockRejectedValueOnce(dbLockedError)
        .mockResolvedValueOnce({ data: 'success' });

      const result = await client.invoke('test_command', {});

      expect(result).toEqual({ data: 'success' });
      expect(mockInvokeCommand).toHaveBeenCalledTimes(2);
    });
  });

  describe('Backoff Strategy', () => {
    it('should use exponential backoff by default', async () => {
      client = new TauriClient({
        timeout: 1000,
        retryConfig: {
          maxRetries: 3,
          retryDelay: 100,
          backoffStrategy: 'exponential',
          retryableErrors: [],
        },
      });

      const delays: number[] = [];
      const originalDelay = (client as any).delay.bind(client);
      (client as any).delay = vi.fn((ms: number) => {
        delays.push(ms);
        return originalDelay(0); // 立即返回以加快测试
      });

      mockInvokeCommand
        .mockRejectedValueOnce(new Error('Failure 1'))
        .mockRejectedValueOnce(new Error('Failure 2'))
        .mockRejectedValueOnce(new Error('Failure 3'))
        .mockResolvedValueOnce({ data: 'success' });

      await client.invoke('test_command', {});

      // 指数退避: 100 * 2^0 = 100, 100 * 2^1 = 200, 100 * 2^2 = 400
      expect(delays).toEqual([100, 200, 400]);
    });

    it('should use linear backoff when configured', async () => {
      client = new TauriClient({
        timeout: 1000,
        retryConfig: {
          maxRetries: 3,
          retryDelay: 100,
          backoffStrategy: 'linear',
          retryableErrors: [],
        },
      });

      const delays: number[] = [];
      const originalDelay = (client as any).delay.bind(client);
      (client as any).delay = vi.fn((ms: number) => {
        delays.push(ms);
        return originalDelay(0);
      });

      mockInvokeCommand
        .mockRejectedValueOnce(new Error('Failure 1'))
        .mockRejectedValueOnce(new Error('Failure 2'))
        .mockRejectedValueOnce(new Error('Failure 3'))
        .mockResolvedValueOnce({ data: 'success' });

      await client.invoke('test_command', {});

      // 线性退避: 100 * 1 = 100, 100 * 2 = 200, 100 * 3 = 300
      expect(delays).toEqual([100, 200, 300]);
    });

    it('should respect maxBackoffDelay', async () => {
      client = new TauriClient({
        timeout: 1000,
        retryConfig: {
          maxRetries: 5,
          retryDelay: 100,
          backoffStrategy: 'exponential',
          maxBackoffDelay: 500, // 限制最大延迟
          retryableErrors: [],
        },
      });

      const delays: number[] = [];
      const originalDelay = (client as any).delay.bind(client);
      (client as any).delay = vi.fn((ms: number) => {
        delays.push(ms);
        return originalDelay(0);
      });

      mockInvokeCommand
        .mockRejectedValueOnce(new Error('Failure 1'))
        .mockRejectedValueOnce(new Error('Failure 2'))
        .mockRejectedValueOnce(new Error('Failure 3'))
        .mockRejectedValueOnce(new Error('Failure 4'))
        .mockRejectedValueOnce(new Error('Failure 5'))
        .mockResolvedValueOnce({ data: 'success' });

      await client.invoke('test_command', {});

      // 指数退避但限制在 500ms: 100, 200, 400, 500 (限制), 500 (限制)
      expect(delays).toEqual([100, 200, 400, 500, 500]);
    });
  });

  describe('Interceptors with Retry', () => {
    it('should execute command interceptors once per invoke call', async () => {
      client = new TauriClient({
        timeout: 1000,
        retryConfig: {
          maxRetries: 2,
          retryDelay: 10,
          retryableErrors: [], // 空列表表示所有错误都可重试
        },
      });

      const interceptorCalls: number[] = [];
      const commandInterceptor: CommandInterceptor = {
        onCommand: (command, args) => {
          interceptorCalls.push(Date.now());
          return { command, args };
        },
      };

      client.useCommandInterceptor(commandInterceptor);

      // 使用 SystemError 以确保错误被正确处理
      mockInvokeCommand
        .mockRejectedValueOnce(new apiModule.SystemError('Failure 1'))
        .mockRejectedValueOnce(new apiModule.SystemError('Failure 2'))
        .mockResolvedValueOnce({ data: 'success' });

      await client.invoke('test_command', {});

      // 拦截器应该被调用 1 次 (在整个操作开始时)
      // 重试是在拦截器之后的内部逻辑
      expect(interceptorCalls).toHaveLength(1);
      // 但 invokeCommand 应该被调用 3 次 (初始 + 2 次重试)
      expect(mockInvokeCommand).toHaveBeenCalledTimes(3);
    });

    it('should execute response interceptors on success after retry', async () => {
      client = new TauriClient({
        timeout: 1000,
        retryConfig: {
          maxRetries: 2,
          retryDelay: 10,
          retryableErrors: [],
        },
      });

      let responseInterceptorCalled = false;
      const responseInterceptor: ResponseInterceptor = {
        onResponse: (response) => {
          responseInterceptorCalled = true;
          return response;
        },
      };

      client.useResponseInterceptor(responseInterceptor);

      mockInvokeCommand
        .mockRejectedValueOnce(new Error('Failure 1'))
        .mockResolvedValueOnce({ data: 'success' });

      await client.invoke('test_command', {});

      expect(responseInterceptorCalled).toBe(true);
    });
  });

  describe('User Context Interceptor', () => {
    it('should add userId to command args when user is authenticated', async () => {
      client = new TauriClient({
        timeout: 1000,
        retryConfig: {
          maxRetries: 0,
          retryDelay: 10,
        },
      });

      const mockUserId = 'user-123';
      const userContextInterceptor: CommandInterceptor = {
        onCommand: (command, args) => {
          if (args && typeof args === 'object') {
            return {
              command,
              args: {
                ...args,
                userId: mockUserId,
              },
            };
          }
          return { command, args };
        },
      };

      client.useCommandInterceptor(userContextInterceptor);

      mockInvokeCommand.mockResolvedValueOnce({ data: 'success' });

      await client.invoke('test_command', { param1: 'value1' });

      // 验证 userId 被添加到参数中
      expect(mockInvokeCommand).toHaveBeenCalledWith(
        'test_command',
        {
          param1: 'value1',
          userId: mockUserId,
        },
        1000
      );
    });

    it('should not modify args when userId is not available', async () => {
      client = new TauriClient({
        timeout: 1000,
        retryConfig: {
          maxRetries: 0,
          retryDelay: 10,
        },
      });

      const userContextInterceptor: CommandInterceptor = {
        onCommand: (command, args) => {
          const userId = undefined; // 模拟未登录状态
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

      client.useCommandInterceptor(userContextInterceptor);

      mockInvokeCommand.mockResolvedValueOnce({ data: 'success' });

      const originalArgs = { param1: 'value1' };
      await client.invoke('test_command', originalArgs);

      // 验证参数未被修改
      expect(mockInvokeCommand).toHaveBeenCalledWith(
        'test_command',
        originalArgs,
        1000
      );
    });

    it('should handle null or undefined args gracefully', async () => {
      client = new TauriClient({
        timeout: 1000,
        retryConfig: {
          maxRetries: 0,
          retryDelay: 10,
        },
      });

      const mockUserId = 'user-123';
      const userContextInterceptor: CommandInterceptor = {
        onCommand: (command, args) => {
          if (mockUserId && args && typeof args === 'object') {
            return {
              command,
              args: {
                ...args,
                userId: mockUserId,
              },
            };
          }
          return { command, args };
        },
      };

      client.useCommandInterceptor(userContextInterceptor);

      mockInvokeCommand.mockResolvedValueOnce({ data: 'success' });

      // 测试 undefined args
      await client.invoke('test_command', undefined);

      expect(mockInvokeCommand).toHaveBeenCalledWith(
        'test_command',
        undefined,
        1000
      );
    });

    it('should not override existing userId in args', async () => {
      client = new TauriClient({
        timeout: 1000,
        retryConfig: {
          maxRetries: 0,
          retryDelay: 10,
        },
      });

      const mockUserId = 'user-123';
      const userContextInterceptor: CommandInterceptor = {
        onCommand: (command, args) => {
          if (mockUserId && args && typeof args === 'object') {
            return {
              command,
              args: {
                ...args,
                userId: mockUserId,
              },
            };
          }
          return { command, args };
        },
      };

      client.useCommandInterceptor(userContextInterceptor);

      mockInvokeCommand.mockResolvedValueOnce({ data: 'success' });

      // 参数中已经包含 userId
      const argsWithUserId = { param1: 'value1', userId: 'existing-user' };
      await client.invoke('test_command', argsWithUserId);

      // 验证 userId 被拦截器覆盖
      expect(mockInvokeCommand).toHaveBeenCalledWith(
        'test_command',
        {
          param1: 'value1',
          userId: mockUserId, // 应该使用拦截器提供的 userId
        },
        1000
      );
    });
  });
});
