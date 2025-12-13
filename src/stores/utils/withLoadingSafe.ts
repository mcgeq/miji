/**
 * Store 工具函数 - withLoadingSafe
 * 包装异步操作，自动管理加载状态和错误
 * @module stores/utils/withLoadingSafe
 */

import type { Ref } from 'vue';
import type { AppError } from '@/errors/appError';
import { wrapError } from '@/utils/errorHandler';

/**
 * 包装异步操作，自动管理加载状态和错误
 *
 * @param fn - 异步函数
 * @param isLoading - 加载状态 ref
 * @param error - 错误状态 ref
 * @returns 包装后的异步函数
 *
 * @example
 * ```typescript
 * const fetchItems = withLoadingSafe(async () => {
 *   const items = await itemService.list();
 *   itemsRef.value = items;
 * }, isLoading, error);
 * ```
 */
export function withLoadingSafe<TArgs extends unknown[], TReturn>(
  fn: (...args: TArgs) => Promise<TReturn>,
  isLoading: Ref<boolean>,
  error: Ref<AppError | null>,
): (...args: TArgs) => Promise<TReturn> {
  return async (...args: TArgs): Promise<TReturn> => {
    try {
      isLoading.value = true;
      error.value = null;

      const result = await fn(...args);

      return result;
    } catch (err) {
      error.value = wrapError('Store', err, 'OPERATION_FAILED', '操作失败');
      throw error.value;
    } finally {
      isLoading.value = false;
    }
  };
}
