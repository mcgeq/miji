/**
 * 自动保存设置组合器
 * 
 * 用于管理一组相关的设置项，提供统一的接口
 */

import { computed, type Ref } from 'vue';
import { useSettingsCache, type SettingsConfig } from './useSettingsCache';

export interface SettingField<T = any> {
  /** 字段响应式值 */
  value: Ref<T>;
  /** 是否正在保存 */
  isSaving: Ref<boolean>;
  /** 是否正在加载 */
  isLoading: Ref<boolean>;
  /** 立即保存 */
  save: () => Promise<void>;
  /** 加载值 */
  load: () => Promise<void>;
  /** 重置为默认值 */
  reset: () => Promise<void>;
}

export interface AutoSaveSettingsConfig {
  /** 设置模块名称（用于日志） */
  moduleName?: string;
  /** 设置项配置 */
  fields: Record<string, SettingsConfig>;
}

/**
 * 使用自动保存设置
 * 
 * @example
 * ```ts
 * const { fields, isLoading, isSaving, resetAll, loadAll } = useAutoSaveSettings({
 *   moduleName: 'general',
 *   fields: {
 *     theme: {
 *       key: 'settings.general.theme',
 *       defaultValue: 'system',
 *       saveFn: async (val) => await saveTheme(val),
 *       loadFn: async () => await loadTheme(),
 *     },
 *     language: {
 *       key: 'settings.general.language',
 *       defaultValue: 'zh-CN',
 *       saveFn: async (val) => await saveLanguage(val),
 *       loadFn: async () => await loadLanguage(),
 *     },
 *   },
 * });
 * 
 * // 访问字段
 * fields.theme.value.value = 'dark'; // 自动保存
 * fields.language.value.value = 'en-US'; // 自动保存
 * 
 * // 重置所有
 * await resetAll();
 * ```
 */
export function useAutoSaveSettings(
  config: AutoSaveSettingsConfig
) {
  const { moduleName = 'settings', fields: fieldsConfig } = config;

  // 创建每个字段的设置缓存
  const fields = Object.entries(fieldsConfig).reduce((acc, [fieldName, fieldConfig]) => {
    const settingsCache = useSettingsCache(fieldConfig);
    
    acc[fieldName] = {
      value: settingsCache.value,
      isSaving: settingsCache.isSaving,
      isLoading: settingsCache.isLoading,
      save: settingsCache.save,
      load: settingsCache.load,
      reset: settingsCache.reset,
    };
    
    return acc;
  }, {} as Record<string, SettingField>);

  // 计算是否有任何字段正在加载
  const isLoading = computed(() =>
    Object.values(fields).some(field => field.isLoading.value)
  );

  // 计算是否有任何字段正在保存
  const isSaving = computed(() =>
    Object.values(fields).some(field => field.isSaving.value)
  );

  /**
   * 加载所有设置
   */
  async function loadAll(): Promise<void> {
    const loadPromises = Object.values(fields).map(field => field.load());
    await Promise.all(loadPromises);
    console.log(`[${moduleName}] All settings loaded`);
  }

  /**
   * 立即保存所有设置
   */
  async function saveAll(): Promise<void> {
    const savePromises = Object.values(fields).map(field => field.save());
    await Promise.all(savePromises);
    console.log(`[${moduleName}] All settings saved`);
  }

  /**
   * 重置所有设置为默认值
   */
  async function resetAll(): Promise<void> {
    const resetPromises = Object.values(fields).map(field => field.reset());
    await Promise.all(resetPromises);
    console.log(`[${moduleName}] All settings reset to defaults`);
  }

  return {
    /** 设置字段 */
    fields,
    /** 是否有任何字段正在加载 */
    isLoading,
    /** 是否有任何字段正在保存 */
    isSaving,
    /** 加载所有设置 */
    loadAll,
    /** 立即保存所有设置 */
    saveAll,
    /** 重置所有设置为默认值 */
    resetAll,
  };
}

/**
 * 创建简单的设置项（使用 localStorage）
 * 
 * 适用于不需要复杂持久化逻辑的设置
 * 
 * @example
 * ```ts
 * const themeConfig = createSimpleSetting({
 *   key: 'theme',
 *   defaultValue: 'system',
 * });
 * ```
 */
export function createSimpleSetting<T>(params: {
  key: string;
  defaultValue: T;
}): SettingsConfig<T> {
  const { key, defaultValue } = params;
  
  return {
    key,
    defaultValue,
    saveFn: async (value: T) => {
      try {
        localStorage.setItem(key, JSON.stringify(value));
      } catch (error) {
        console.error(`Failed to save setting "${key}" to localStorage:`, error);
        throw error;
      }
    },
    loadFn: async () => {
      try {
        const stored = localStorage.getItem(key);
        if (stored) {
          return JSON.parse(stored) as T;
        }
        return null;
      } catch (error) {
        console.error(`Failed to load setting "${key}" from localStorage:`, error);
        return null;
      }
    },
  };
}

/**
 * 创建使用 Tauri 命令的设置项
 * 
 * 适用于需要通过 Tauri 后端保存的设置
 * 
 * @example
 * ```ts
 * const themeConfig = createTauriSetting({
 *   key: 'theme',
 *   defaultValue: 'system',
 *   saveCommand: 'save_theme',
 *   loadCommand: 'load_theme',
 * });
 * ```
 */
export function createTauriSetting<T>(params: {
  key: string;
  defaultValue: T;
  saveCommand: string;
  loadCommand: string;
}): SettingsConfig<T> {
  const { key, defaultValue, saveCommand, loadCommand } = params;
  
  // 动态导入 Tauri API
  const invokePromise = import('@tauri-apps/api/core').then(m => m.invoke);
  
  return {
    key,
    defaultValue,
    saveFn: async (value: T) => {
      const invoke = await invokePromise;
      await invoke(saveCommand, { value });
    },
    loadFn: async () => {
      const invoke = await invokePromise;
      try {
        const result = await invoke<T>(loadCommand);
        return result;
      } catch (error) {
        console.error(`Failed to load setting "${key}" from Tauri:`, error);
        return null;
      }
    },
  };
}

/**
 * 创建使用数据库存储的设置项（带 localStorage 缓存）
 * 
 * 通过统一的用户设置 API 保存到数据库，同时使用 localStorage 作为缓存层
 * 
 * @example
 * ```ts
 * const themeConfig = createDatabaseSetting({
 *   key: 'settings.general.theme',
 *   defaultValue: 'system',
 * });
 * ```
 */
export function createDatabaseSetting<T>(params: {
  key: string;
  defaultValue: T;
}): SettingsConfig<T> {
  const { key, defaultValue } = params;
  
  // 从 key 解析模块名 (settings.{module}.{field})
  const parseModule = (settingKey: string): string => {
    const parts = settingKey.split('.');
    if (parts.length >= 2 && parts[0] === 'settings') {
      return parts[1]; // general, notification, privacy, security
    }
    return 'general'; // 默认模块
  };
  
  // 推断值类型
  const inferType = (value: unknown): string => {
    if (Array.isArray(value)) return 'array';
    if (value === null) return 'string';
    const type = typeof value;
    if (type === 'object') return 'object';
    return type; // string, number, boolean
  };
  
  // 动态导入 Tauri API
  const invokePromise = import('@tauri-apps/api/core').then(m => m.invoke);
  
  return {
    key,
    defaultValue,
    saveFn: async (value: T) => {
      try {
        const invoke = await invokePromise;
        
        // 保存到数据库 - 使用 DTO 方式
        await invoke('user_setting_save', {
          command: {
            key,
            value,
            settingType: inferType(value),
            module: parseModule(key),
          }
        });
        
        // 同时保存到 localStorage 作为缓存
        localStorage.setItem(key, JSON.stringify(value));
      } catch (error) {
        console.error(`Failed to save setting "${key}" to database:`, error);
        throw error;
      }
    },
    loadFn: async () => {
      try {
        // 优先从 localStorage 读取（快速）
        const cached = localStorage.getItem(key);
        if (cached !== null) {
          try {
            return JSON.parse(cached) as T;
          } catch {
            // 缓存解析失败，继续从数据库读取
          }
        }
        
        // 从数据库读取
        const invoke = await invokePromise;
        const result = await invoke<T | null>('user_setting_get', { key });
        
        if (result !== null) {
          // 回填 localStorage 缓存
          localStorage.setItem(key, JSON.stringify(result));
          return result;
        }
        
        return null;
      } catch (error) {
        console.error(`Failed to load setting "${key}" from database:`, error);
        
        // 尝试从 localStorage 恢复
        const cached = localStorage.getItem(key);
        if (cached !== null) {
          try {
            return JSON.parse(cached) as T;
          } catch {
            return null;
          }
        }
        
        return null;
      }
    },
  };
}
