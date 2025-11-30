/**
 * API辅助工具
 *
 * 提供统一的错误处理、请求缓存、请求去重等功能
 */

import { apiCache, cacheKeys } from './cache';
import { toast } from './toast';

// ==================== 错误处理 ====================

export interface ApiError {
  code: string;
  message: string;
  details?: any;
}

/**
 * 统一错误处理
 */
export function handleApiError(error: any, customMessage?: string): void {
  console.error('API错误:', error);

  let errorMessage = customMessage || '操作失败';

  // 解析不同类型的错误
  if (typeof error === 'string') {
    errorMessage = error;
  } else if (error?.message) {
    errorMessage = error.message;
  } else if (error?.error) {
    errorMessage = error.error;
  }

  // 显示错误提示
  toast.error(errorMessage);

  // 可选：上报错误到监控系统
  // reportError(error);
}

/**
 * 包装API调用，自动处理错误
 */
export async function safeApiCall<T>(
  apiCall: () => Promise<T>,
  errorMessage?: string,
): Promise<T | null> {
  try {
    return await apiCall();
  } catch (error) {
    handleApiError(error, errorMessage);
    return null;
  }
}

// ==================== 请求缓存 ====================
// 使用统一的缓存系统 @/utils/cache
// apiCache 和 cacheKeys 已在顶部导入

/**
 * 带缓存的API调用
 */
export async function cachedApiCall<T>(
  cacheKey: string,
  apiCall: () => Promise<T>,
  expiresIn?: number,
): Promise<T> {
  // 尝试从缓存获取
  const cached = apiCache.get(cacheKey) as T | null;
  if (cached !== null) {
    return cached;
  }

  // 调用API
  const result = await apiCall();

  // 存入缓存
  apiCache.set(cacheKey, result, expiresIn);

  return result;
}

// ==================== 请求去重 ====================

class RequestDeduplicator {
  private pending: Map<string, Promise<any>> = new Map();

  /**
   * 执行请求，如果相同请求正在进行中则等待
   */
  async execute<T>(key: string, apiCall: () => Promise<T>): Promise<T> {
    // 检查是否有相同的请求正在进行
    const existing = this.pending.get(key);
    if (existing) {
      return existing as Promise<T>;
    }

    // 创建新请求
    const promise = apiCall().finally(() => {
      this.pending.delete(key);
    });

    this.pending.set(key, promise);
    return promise;
  }

  /**
   * 取消所有待处理请求
   */
  clear(): void {
    this.pending.clear();
  }
}

export const requestDeduplicator = new RequestDeduplicator();

// ==================== 加载状态管理 ====================

export interface LoadingState {
  loading: Ref<boolean>;
  error: Ref<string | null>;
  data: Ref<any>;
}

/**
 * 创建加载状态
 */
export function useLoadingState<T = any>(initialData?: T) {
  const loading = ref(false);
  const error = ref<string | null>(null);
  const data = ref<T | null>(initialData || null) as Ref<T | null>;

  /**
   * 执行异步操作
   */
  async function execute(apiCall: () => Promise<T>): Promise<T | null> {
    loading.value = true;
    error.value = null;

    try {
      const result = await apiCall();
      data.value = result;
      return result;
    } catch (err: any) {
      error.value = err?.message || '操作失败';
      handleApiError(err);
      return null;
    } finally {
      loading.value = false;
    }
  }

  /**
   * 重置状态
   */
  function reset() {
    loading.value = false;
    error.value = null;
    data.value = initialData || null;
  }

  return {
    loading,
    error,
    data,
    execute,
    reset,
  };
}

// ==================== 离线支持 ====================

export interface OfflineQueueItem {
  id: string;
  method: string;
  params: any;
  timestamp: number;
  retryCount: number;
}

class OfflineQueue {
  private queue: OfflineQueueItem[] = [];
  private maxRetries = 3;

  /**
   * 添加到离线队列
   */
  add(method: string, params: any): void {
    const item: OfflineQueueItem = {
      id: `${method}_${Date.now()}`,
      method,
      params,
      timestamp: Date.now(),
      retryCount: 0,
    };

    this.queue.push(item);
    this.saveToStorage();
  }

  /**
   * 处理离线队列
   */
  async process(executor: (item: OfflineQueueItem) => Promise<void>): Promise<void> {
    const items = [...this.queue];

    for (const item of items) {
      try {
        await executor(item);
        this.remove(item.id);
      } catch {
        item.retryCount++;
        if (item.retryCount >= this.maxRetries) {
          this.remove(item.id);
          console.error('离线请求失败，已达到最大重试次数:', item);
        }
      }
    }

    this.saveToStorage();
  }

  /**
   * 移除项目
   */
  remove(id: string): void {
    this.queue = this.queue.filter(item => item.id !== id);
    this.saveToStorage();
  }

  /**
   * 获取队列
   */
  getQueue(): OfflineQueueItem[] {
    return [...this.queue];
  }

  /**
   * 清空队列
   */
  clear(): void {
    this.queue = [];
    this.saveToStorage();
  }

  /**
   * 保存到本地存储
   */
  private saveToStorage(): void {
    try {
      localStorage.setItem('offline_queue', JSON.stringify(this.queue));
    } catch (error) {
      console.error('保存离线队列失败:', error);
    }
  }

  /**
   * 从本地存储加载
   */
  loadFromStorage(): void {
    try {
      const stored = localStorage.getItem('offline_queue');
      if (stored) {
        this.queue = JSON.parse(stored);
      }
    } catch (error) {
      console.error('加载离线队列失败:', error);
    }
  }
}

export const offlineQueue = new OfflineQueue();

// ==================== 网络状态监听 ====================

export function useNetworkStatus() {
  const isOnline = ref(navigator.onLine);

  const updateOnlineStatus = () => {
    isOnline.value = navigator.onLine;
  };

  onMounted(() => {
    window.addEventListener('online', updateOnlineStatus);
    window.addEventListener('offline', updateOnlineStatus);
  });

  onUnmounted(() => {
    window.removeEventListener('online', updateOnlineStatus);
    window.removeEventListener('offline', updateOnlineStatus);
  });

  return {
    isOnline,
  };
}

// ==================== 导出便捷函数 ====================

/**
 * 创建带所有优化功能的API调用
 */
export function createOptimizedApiCall<T>(
  method: string,
  apiCall: (params: any) => Promise<T>,
  options?: {
    cache?: boolean;
    cacheExpires?: number;
    deduplicate?: boolean;
    errorMessage?: string;
  },
) {
  return async (params: any): Promise<T | null> => {
    const cacheKey = options?.cache ? cacheKeys.api(method, params) : '';

    const executeCall = async () => {
      if (options?.cache) {
        return cachedApiCall(cacheKey, () => apiCall(params), options.cacheExpires);
      }
      return apiCall(params);
    };

    const finalCall = options?.deduplicate
      ? () => requestDeduplicator.execute(cacheKey || method, executeCall)
      : executeCall;

    return safeApiCall(finalCall, options?.errorMessage);
  };
}
