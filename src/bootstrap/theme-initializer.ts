// src/bootstrap/theme-initializer.ts
import { useThemeStore } from '@/stores/theme';

/**
 * 主题初始化器
 * 负责主题的加载和应用
 */
export class ThemeInitializer {
  /**
   * 初始化并应用主题
   */
  async initialize(): Promise<void> {
    try {
      const themeStore = useThemeStore();

      // 如果主题store还没有初始化，先初始化
      if (!themeStore.isInitializing && !themeStore.isLoading) {
        await themeStore.init();
      }

      // 应用主题到DOM
      this.applyTheme();

      // 调试信息
      if (themeStore.debugThemeState) {
        themeStore.debugThemeState();
      }
    } catch (error) {
      console.error('Failed to initialize theme:', error);
    }
  }

  /**
   * 应用主题到 DOM
   */
  private applyTheme(): void {
    if (typeof document === 'undefined') return;

    const themeStore = useThemeStore();
    const effectiveTheme = themeStore.getEffectiveThemeValue();

    const root = document.documentElement;
    root.classList.remove('theme-light', 'theme-dark');
    root.classList.add(`theme-${effectiveTheme}`);
    root.style.colorScheme = effectiveTheme;

    // 设置 meta theme-color（用于移动端浏览器）
    const metaThemeColor = document.querySelector('meta[name="theme-color"]');
    if (metaThemeColor) {
      metaThemeColor.setAttribute(
        'content',
        effectiveTheme === 'dark' ? '#1a1a1a' : '#ffffff',
      );
    }
  }
}
