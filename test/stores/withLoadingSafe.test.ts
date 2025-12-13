/**
 * withLoadingSafe 工具函数测试
 */

import { describe, it, expect, vi, beforeEach } from 'vitest';
import { ref } from 'vue';
import type { Ref } from 'vue';
import { withLoadingSafe } from '@/stores/utils/withLoadingSafe';
import { AppError } from '@/errors/appError';

// Test implementation of AppError
class TestAppError extends AppError {
  constructor(module: string, code: string, message: string) {
    super(module, code, message);
    this.name = 'TestAppError';
  }
}

describe('withLoadingSafe', () => {
  let isLoading: Ref<boolean>;
  let error: Ref<AppError | null>;

  beforeEach(() => {
    isLoading = ref<boolean>(false);
    error = ref<AppError | null>(null);
  });

  describe('加载状态管理', () => {
    it('应该在操作开始时设置 isLoading 为 true', async () => {
      const mockFn = vi.fn(async () => {
        expect(isLoading.value).toBe(true);
        return 'success';
      });

      const wrapped = withLoadingSafe(mockFn, isLoading, error);
      await wrapped();

      expect(mockFn).toHaveBeenCalled();
    });

    it('应该在操作成功后设置 isLoading 为 false', async () => {
      const mockFn = vi.fn(async () => 'success');
      const wrapped = withLoadingSafe(mockFn, isLoading, error);

      await wrapped();

      expect(isLoading.value).toBe(false);
    });

    it('应该在操作失败后设置 isLoading 为 false', async () => {
      const mockFn = vi.fn(async () => {
        throw new Error('Test error');
      });
      const wrapped = withLoadingSafe(mockFn, isLoading, error);

      try {
        await wrapped();
      } catch {
        // 预期会抛出错误
      }

      expect(isLoading.value).toBe(false);
    });

    it('应该在操作开始时清除之前的错误', async () => {
      error.value = new TestAppError('Test', 'OLD_ERROR', 'Old error');
      const mockFn = vi.fn(async () => 'success');
      const wrapped = withLoadingSafe(mockFn, isLoading, error);

      await wrapped();

      expect(error.value).toBeNull();
    });
  });

  describe('错误处理', () => {
    it('应该捕获并包装错误为 AppError', async () => {
      const testError = new Error('Test error');
      const mockFn = vi.fn(async () => {
        throw testError;
      });
      const wrapped = withLoadingSafe(mockFn, isLoading, error);

      try {
        await wrapped();
        expect.fail('应该抛出错误');
      } catch (err) {
        expect(err).toBeInstanceOf(AppError);
        expect(error.value).toBeInstanceOf(AppError);
        expect(error.value?.message).toContain('Test error');
      }
    });

    it('应该保留已经是 AppError 的错误', async () => {
      const appError = new TestAppError('TestModule', 'TEST_ERROR', 'Test app error');
      const mockFn = vi.fn(async () => {
        throw appError;
      });
      const wrapped = withLoadingSafe(mockFn, isLoading, error);

      try {
        await wrapped();
        expect.fail('应该抛出错误');
      } catch (err) {
        expect(err).toBeInstanceOf(AppError);
        expect(error.value).toBeInstanceOf(AppError);
      }
    });

    it('应该将错误存储到 error ref 中', async () => {
      const mockFn = vi.fn(async () => {
        throw new Error('Test error');
      });
      const wrapped = withLoadingSafe(mockFn, isLoading, error);

      try {
        await wrapped();
      } catch {
        // 预期会抛出错误
      }

      expect(error.value).not.toBeNull();
      expect(error.value).toBeInstanceOf(AppError);
    });
  });

  describe('函数参数和返回值', () => {
    it('应该正确传递参数到包装的函数', async () => {
      const mockFn = vi.fn(async (a: number, b: string) => `${a}-${b}`);
      const wrapped = withLoadingSafe(mockFn, isLoading, error);

      await wrapped(42, 'test');

      expect(mockFn).toHaveBeenCalledWith(42, 'test');
    });

    it('应该返回包装函数的结果', async () => {
      const expectedResult = { id: 1, name: 'test' };
      const mockFn = vi.fn(async () => expectedResult);
      const wrapped = withLoadingSafe(mockFn, isLoading, error);

      const result = await wrapped();

      expect(result).toBe(expectedResult);
    });

    it('应该支持无参数的函数', async () => {
      const mockFn = vi.fn(async () => 'success');
      const wrapped = withLoadingSafe(mockFn, isLoading, error);

      const result = await wrapped();

      expect(result).toBe('success');
      expect(mockFn).toHaveBeenCalledWith();
    });

    it('应该支持多个参数的函数', async () => {
      const mockFn = vi.fn(async (a: number, b: string, c: boolean) => ({ a, b, c }));
      const wrapped = withLoadingSafe(mockFn, isLoading, error);

      const result = await wrapped(1, 'test', true);

      expect(result).toEqual({ a: 1, b: 'test', c: true });
      expect(mockFn).toHaveBeenCalledWith(1, 'test', true);
    });
  });

  describe('并发操作', () => {
    it('应该正确处理多个并发操作', async () => {
      const mockFn1 = vi.fn(async () => {
        await new Promise(resolve => setTimeout(resolve, 10));
        return 'result1';
      });
      const mockFn2 = vi.fn(async () => {
        await new Promise(resolve => setTimeout(resolve, 5));
        return 'result2';
      });
      const mockFn3 = vi.fn(async () => {
        await new Promise(resolve => setTimeout(resolve, 1));
        return 'result3';
      });

      const wrapped1 = withLoadingSafe(mockFn1, isLoading, error);
      const wrapped2 = withLoadingSafe(mockFn2, isLoading, error);
      const wrapped3 = withLoadingSafe(mockFn3, isLoading, error);

      const [result1, result2, result3] = await Promise.all([
        wrapped1(),
        wrapped2(),
        wrapped3(),
      ]);

      // 验证所有调用都完成了
      expect(mockFn1).toHaveBeenCalledTimes(1);
      expect(mockFn2).toHaveBeenCalledTimes(1);
      expect(mockFn3).toHaveBeenCalledTimes(1);
      expect(result1).toBe('result1');
      expect(result2).toBe('result2');
      expect(result3).toBe('result3');
      expect(isLoading.value).toBe(false);
    });

    it('应该在一个操作失败时不影响其他操作', async () => {
      let callCount = 0;
      const mockFn = vi.fn(async () => {
        callCount++;
        if (callCount === 2) {
          throw new Error('Second call fails');
        }
        return callCount;
      });
      const wrapped = withLoadingSafe(mockFn, isLoading, error);

      const results = await Promise.allSettled([
        wrapped(),
        wrapped(),
        wrapped(),
      ]);

      expect(results[0].status).toBe('fulfilled');
      expect(results[1].status).toBe('rejected');
      expect(results[2].status).toBe('fulfilled');
    });
  });

  describe('边界情况', () => {
    it('应该处理返回 undefined 的函数', async () => {
      const mockFn = vi.fn(async () => undefined);
      const wrapped = withLoadingSafe(mockFn, isLoading, error);

      const result = await wrapped();

      expect(result).toBeUndefined();
      expect(error.value).toBeNull();
    });

    it('应该处理返回 null 的函数', async () => {
      const mockFn = vi.fn(async () => null);
      const wrapped = withLoadingSafe(mockFn, isLoading, error);

      const result = await wrapped();

      expect(result).toBeNull();
      expect(error.value).toBeNull();
    });

    it('应该处理抛出非 Error 对象的情况', async () => {
      const mockFn = vi.fn(async () => {
        throw 'string error';
      });
      const wrapped = withLoadingSafe(mockFn, isLoading, error);

      try {
        await wrapped();
        expect.fail('应该抛出错误');
      } catch (err) {
        expect(error.value).toBeInstanceOf(AppError);
      }
    });
  });
});
