/**
 * 设置缓存管理器
 * 
 * 功能：
 * - 内存缓存，减少数据库查询
 * - 自动同步到持久化存储
 * - 支持批量更新
 * - 提供重置功能
 */

import { ref, watch, type Ref } from 'vue';
import { debounce } from 'es-toolkit';

export interface SettingsConfig<T = any> {
  /** 设置键名（唯一标识） */
  key: string;
  /** 默认值 */
  defaultValue: T;
  /** 保存到持久化存储的函数 */
  saveFn: (value: T) => Promise<void>;
  /** 从持久化存储加载的函数 */
  loadFn: () => Promise<T | null>;
  /** 自动保存的防抖延迟（毫秒），默认 500ms */
  debounceMs?: number;
}

/**
 * 设置缓存管理器类
 */
class SettingsCacheManager {
  private cache = new Map<string, any>();
  private watchers = new Map<string, (() => void)>();

  /**
   * 获取缓存值
   */
  get<T>(key: string): T | undefined {
    return this.cache.get(key);
  }

  /**
   * 设置缓存值
   */
  set<T>(key: string, value: T): void {
    this.cache.set(key, value);
  }

  /**
   * 删除缓存值
   */
  delete(key: string): void {
    this.cache.delete(key);
    // 同时清理 watcher
    const stopWatch = this.watchers.get(key);
    if (stopWatch) {
      stopWatch();
      this.watchers.delete(key);
    }
  }

  /**
   * 清空所有缓存
   */
  clear(): void {
    this.cache.clear();
    // 清理所有 watchers
    for (const stopWatch of this.watchers.values()) {
      stopWatch();
    }
    this.watchers.clear();
  }

  /**
   * 注册 watcher
   */
  addWatcher(key: string, stopFn: () => void): void {
    // 如果已有 watcher，先停止
    const existingStop = this.watchers.get(key);
    if (existingStop) {
      existingStop();
    }
    this.watchers.set(key, stopFn);
  }

  /**
   * 检查缓存是否存在
   */
  has(key: string): boolean {
    return this.cache.has(key);
  }

  /**
   * 获取所有缓存键
   */
  keys(): string[] {
    return Array.from(this.cache.keys());
  }
}

// 全局单例
const cacheManager = new SettingsCacheManager();

/**
 * 使用设置缓存的 Composable
 * 
 * @example
 * ```ts
 * const { value, save, reset, isLoading } = useSettingsCache({
 *   key: 'theme',
 *   defaultValue: 'system',
 *   saveFn: async (val) => await saveTheme(val),
 *   loadFn: async () => await loadTheme(),
 * });
 * 
 * // 值会自动保存（带防抖）
 * value.value = 'dark';
 * 
 * // 手动保存（立即）
 * await save();
 * 
 * // 重置为默认值
 * await reset();
 * ```
 */
export function useSettingsCache<T>(config: SettingsConfig<T>) {
  const {
    key,
    defaultValue,
    saveFn,
    loadFn,
    debounceMs = 500,
  } = config;

  // 状态
  const isLoading = ref(false);
  const isSaving = ref(false);
  const error = ref<Error | null>(null);

  // 从缓存或默认值初始化
  const cachedValue = cacheManager.get<T>(key);
  const value: Ref<T> = ref(cachedValue ?? defaultValue) as Ref<T>;

  // 更新缓存
  if (!cachedValue) {
    cacheManager.set(key, value.value);
  }

  /**
   * 立即保存到持久化存储
   */
  async function save(): Promise<void> {
    try {
      isSaving.value = true;
      error.value = null;
      
      await saveFn(value.value);
      
      // 更新缓存
      cacheManager.set(key, value.value);
    } catch (err) {
      error.value = err as Error;
      console.error(`Failed to save setting "${key}":`, err);
      throw err;
    } finally {
      isSaving.value = false;
    }
  }

  /**
   * 从持久化存储加载
   */
  async function load(): Promise<void> {
    try {
      isLoading.value = true;
      error.value = null;

      const loadedValue = await loadFn();
      
      if (loadedValue !== null && loadedValue !== undefined) {
        value.value = loadedValue;
        cacheManager.set(key, loadedValue);
      } else {
        // 如果加载失败或返回空，使用默认值
        value.value = defaultValue;
        cacheManager.set(key, defaultValue);
      }
    } catch (err) {
      error.value = err as Error;
      console.error(`Failed to load setting "${key}":`, err);
      
      // 加载失败时使用默认值
      value.value = defaultValue;
      cacheManager.set(key, defaultValue);
    } finally {
      isLoading.value = false;
    }
  }

  /**
   * 重置为默认值
   */
  async function reset(): Promise<void> {
    value.value = defaultValue;
    cacheManager.set(key, defaultValue);
    await save();
  }

  /**
   * 手动设置值（不触发自动保存）
   */
  function setValue(newValue: T): void {
    value.value = newValue;
    cacheManager.set(key, newValue);
  }

  // 防抖保存
  const debouncedSave = debounce(save, debounceMs);

  // 监听值变化，自动保存
  const stopWatch = watch(
    value,
    () => {
      debouncedSave();
    },
    { deep: true }
  );

  // 注册 watcher 到管理器
  cacheManager.addWatcher(key, stopWatch);

  // 返回 API
  return {
    /** 响应式的设置值 */
    value,
    /** 是否正在加载 */
    isLoading,
    /** 是否正在保存 */
    isSaving,
    /** 错误信息 */
    error,
    /** 立即保存（不等待防抖） */
    save,
    /** 从持久化存储加载 */
    load,
    /** 重置为默认值 */
    reset,
    /** 手动设置值（不触发自动保存，用于初始化） */
    setValue,
  };
}

/**
 * 清空所有设置缓存
 * 通常在登出时使用
 */
export function clearAllSettingsCache(): void {
  cacheManager.clear();
}

/**
 * 获取缓存管理器实例（用于调试）
 */
export function getSettingsCacheManager() {
  return cacheManager;
}
