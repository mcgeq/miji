import { defineStore } from 'pinia';
// stores/theme.ts
import { Lg } from '@/utils/debugLog';

// =============================================================================
// 类型定义
// =============================================================================

export type ThemeMode = 'light' | 'dark' | 'system';

interface ThemeOption {
  value: ThemeMode;
  label: string;
  icon: string;
}

// =============================================================================
// 常量定义
// =============================================================================

const DEFAULT_THEME: ThemeMode = 'system';

const THEME_OPTIONS: readonly ThemeOption[] = Object.freeze([
  { value: 'light', label: '浅色', icon: 'sun' },
  { value: 'dark', label: '深色', icon: 'moon' },
  { value: 'system', label: '跟随系统', icon: 'monitor' },
] as const);

// =============================================================================
// 工具函数
// =============================================================================

/**
 * 检查是否为开发环境
 */
function isDevelopment(): boolean {
  return (
    import.meta.env?.DEV === true ||
      import.meta.env?.MODE === 'development' ||
        (typeof window !== 'undefined' && window.location?.hostname === 'localhost')
  );
}

/**
 * 安全的控制台日志输出
 */
function safeLog(message: string, data?: any): void {
  if (isDevelopment()) {
    console.warn(message, data || '');
  }
}

/**
 * 获取系统主题偏好
 */
function getSystemTheme(): 'light' | 'dark' {
  try {
    if (typeof window === 'undefined' || !window.matchMedia) {
      return 'light';
    }

    return window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
  } catch (error) {
    console.error('Failed to get system theme:', error);
    return 'light';
  }
}

/**
 * 应用主题到DOM
 */
function applyThemeToDOM(theme: 'light' | 'dark'): void {
  try {
    if (typeof document === 'undefined') {
      return;
    }

    const root = document.documentElement;

    // 移除现有的主题类
    root.classList.remove('theme-light', 'theme-dark');

    // 添加新的主题类
    root.classList.add(`theme-${theme}`);

    // 设置 color-scheme 属性
    root.style.colorScheme = theme;

    // 设置 meta theme-color（用于移动端浏览器）
    const metaThemeColor = document.querySelector('meta[name="theme-color"]');
    if (metaThemeColor) {
      metaThemeColor.setAttribute('content', theme === 'dark' ? '#1a1a1a' : '#ffffff');
    }

    safeLog(`Theme applied to DOM: ${theme}`);
  } catch (error) {
    console.error('Failed to apply theme to DOM:', error);
  }
}

/**
 * 获取实际应用的主题（考虑系统偏好）
 */
function getEffectiveTheme(themeMode: ThemeMode): 'light' | 'dark' {
  if (themeMode === 'system') {
    return getSystemTheme();
  }
  return themeMode;
}

/**
 * 监听系统主题变化
 */
function watchSystemThemeChange(callback: (theme: 'light' | 'dark') => void): () => void {
  try {
    if (typeof window === 'undefined' || !window.matchMedia) {
      return () => { };
    }

    const mediaQuery = window.matchMedia('(prefers-color-scheme: dark)');

    const handleChange = (e: MediaQueryListEvent) => {
      callback(e.matches ? 'dark' : 'light');
    };

    // 添加监听器
    mediaQuery.addEventListener('change', handleChange);

    // 返回清理函数
    return () => {
      mediaQuery.removeEventListener('change', handleChange);
    };
  } catch (error) {
    console.error('Failed to watch system theme changes:', error);
    return () => { };
  }
}

// =============================================================================
// Pinia Store with Tauri Persistence
// =============================================================================

/**
 * Pinia store for theme management with Tauri persistence
 * 使用 @tauri-store/pinia 提供持久化和响应式支持
 */
export const useThemeStore = defineStore(
  'theme',
  () => {
    // 状态
    const currentTheme = ref<ThemeMode>(DEFAULT_THEME);
    const isLoading = ref<boolean>(false);
    const isInitializing = ref<boolean>(false);

    // 系统主题监听器清理函数
    let systemThemeCleanup: (() => void) | null = null;

    // 计算属性
    const currentThemeInfo = computed((): ThemeOption => {
      return THEME_OPTIONS.find(t => t.value === currentTheme.value) || THEME_OPTIONS[0];
    });

    const effectiveTheme = computed((): 'light' | 'dark' => {
      return getEffectiveTheme(currentTheme.value);
    });

    const themeOptions = computed((): readonly ThemeOption[] => {
      return THEME_OPTIONS;
    });

    const isDarkMode = computed((): boolean => {
      return effectiveTheme.value === 'dark';
    });

    const isLightMode = computed((): boolean => {
      return effectiveTheme.value === 'light';
    });

    const isSystemMode = computed((): boolean => {
      return currentTheme.value === 'system';
    });

    // 方法
    async function init(): Promise<void> {
      if (isInitializing.value) {
        return;
      }

      try {
        isInitializing.value = true;
        isLoading.value = true;

        // @tauri-store/pinia 会自动加载持久化的数据
        // 如果没有保存的主题，使用默认主题
        if (!currentTheme.value) {
          await setTheme(DEFAULT_THEME);
        } else {
          // 等待下一个tick确保响应式更新完成
          await nextTick();
          // 应用当前主题
          const themeToApply = getEffectiveTheme(currentTheme.value);
          applyThemeToDOM(themeToApply);

          // 额外检查：确保DOM确实被更新
          setTimeout(() => {
            const root = document.documentElement;
            if (!root.classList.contains(`theme-${themeToApply}`)) {
              console.warn('Theme class not applied, retrying...');
              applyThemeToDOM(themeToApply);
            }
          }, 100);
        }

        // 设置系统主题监听器
        setupSystemThemeWatcher();

        safeLog('Theme store initialized successfully', {
          currentTheme: currentTheme.value,
          effectiveTheme: effectiveTheme.value,
        });
      } catch (error) {
        console.error('Theme store initialization failed:', error);
        await setTheme(DEFAULT_THEME);
      } finally {
        isLoading.value = false;
        isInitializing.value = false;
      }
    }

    async function setTheme(newTheme: ThemeMode): Promise<boolean> {
      try {
        isLoading.value = true;

        // 更新状态（会自动持久化）
        currentTheme.value = newTheme;

        // 应用主题到DOM
        applyThemeToDOM(effectiveTheme.value);

        // 重新设置系统主题监听器
        setupSystemThemeWatcher();

        safeLog(`Theme set to: ${newTheme}`, {
          effectiveTheme: effectiveTheme.value,
        });
        return true;
      } catch (error) {
        console.error('Failed to set theme:', error);
        return false;
      } finally {
        isLoading.value = false;
      }
    }

    function setupSystemThemeWatcher(): void {
      // 清理现有的监听器
      if (systemThemeCleanup) {
        systemThemeCleanup();
        systemThemeCleanup = null;
      }

      // 只有在系统模式下才需要监听系统主题变化
      if (currentTheme.value === 'system') {
        systemThemeCleanup = watchSystemThemeChange(systemTheme => {
          safeLog('System theme changed:', systemTheme);
          applyThemeToDOM(systemTheme);
        });
      }
    }

    async function toggleTheme(): Promise<void> {
      const newTheme = currentTheme.value === 'light' ? 'dark' : 'light';
      await setTheme(newTheme);
    }

    async function resetToDefault(): Promise<void> {
      await setTheme(DEFAULT_THEME);
    }

    function getCurrentTheme(): ThemeMode {
      return currentTheme.value || DEFAULT_THEME;
    }

    function getEffectiveThemeValue(): 'light' | 'dark' {
      return effectiveTheme.value;
    }

    // 清理函数
    function cleanup(): void {
      if (systemThemeCleanup) {
        systemThemeCleanup();
        systemThemeCleanup = null;
      }
    }

    // 调试函数
    function debugThemeState(): void {
      const root = document.documentElement;
      const appliedClasses = Array.from(root.classList).filter(cls => cls.startsWith('theme-'));
      const colorScheme = root.style.colorScheme;

      Lg.i('Theme Debug Info:', {
        currentTheme: currentTheme.value,
        effectiveTheme: effectiveTheme.value,
        appliedClasses,
        colorScheme,
        isDarkMode: isDarkMode.value,
        isSystemMode: isSystemMode.value,
      });
    }

    return {
      // 状态
      currentTheme,
      isLoading,
      isInitializing,

      // 计算属性
      currentThemeInfo,
      effectiveTheme,
      themeOptions,
      isDarkMode,
      isLightMode,
      isSystemMode,

      // 方法
      init,
      setTheme,
      toggleTheme,
      resetToDefault,
      getCurrentTheme,
      getEffectiveThemeValue,
      cleanup,
      debugThemeState,
    };
  },
  {
    // 官方推荐：启用 saveOnChange
    // 文档：https://tb.dev.br/tauri-store/plugin-pinia/guide/persisting-state
    tauri: {
      saveOnChange: true, // 状态变化时自动保存
      saveStrategy: 'debounce', // 使用防抖策略
      saveInterval: 300, // 300ms 防抖延迟
    },
  },
);

// =============================================================================
// 向后兼容性导出
// =============================================================================

/**
 * @deprecated 使用 useThemeStore() 替代
 * 为了向后兼容而保留
 */
export async function startThemeStore(): Promise<void> {
  const store = useThemeStore();
  // 启动 Tauri store 持久化和同步
  await store.$tauri.start();
  // 初始化 store 逻辑
  await store.init();
}

/**
 * @deprecated 使用 useThemeStore().getCurrentTheme() 替代
 */
export function getCurrentTheme(): ThemeMode {
  const store = useThemeStore();
  return store.getCurrentTheme();
}

/**
 * @deprecated 使用 useThemeStore().setTheme() 替代
 */
export function updateTheme(newTheme: ThemeMode | null): void {
  const store = useThemeStore();
  store.setTheme(newTheme || DEFAULT_THEME);
}

/**
 * @deprecated 使用 useThemeStore().resetToDefault() 替代
 */
export function resetTheme(): void {
  const store = useThemeStore();
  store.resetToDefault();
}

// 导出类型定义
export type { ThemeOption };
