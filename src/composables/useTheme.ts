// composables/useTheme.ts
import { useThemeStore } from '@/stores/theme';

/**
 * 主题相关的组合式函数
 * 提供便捷的主题操作接口
 */
export function useTheme() {
  const themeStore = useThemeStore();

  return {
    // 状态
    currentTheme: themeStore.currentTheme,
    effectiveTheme: themeStore.effectiveTheme,
    isDarkMode: themeStore.isDarkMode,
    isLightMode: themeStore.isLightMode,
    isSystemMode: themeStore.isSystemMode,
    isLoading: themeStore.isLoading,

    // 方法
    setTheme: themeStore.setTheme,
    toggleTheme: themeStore.toggleTheme,
    resetTheme: themeStore.resetToDefault,

    // 工具方法
    getThemeName: (theme: string) => {
      const themeInfo = themeStore.themeOptions.find(t => t.value === theme);
      return themeInfo?.label || theme;
    },
  };
}
