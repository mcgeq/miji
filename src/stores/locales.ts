// stores/locales.ts
import { defineStore } from 'pinia';

// =============================================================================
// 类型定义
// =============================================================================

interface SupportedLocale {
  code: string;
  name: string;
  flag: string;
}

// =============================================================================
// 常量定义
// =============================================================================

const DEFAULT_LOCALE = 'zh-CN';

const SUPPORTED_LOCALES: readonly SupportedLocale[] = Object.freeze([
  { code: 'zh-CN', name: '简体中文', flag: '🇨🇳' },
  { code: 'zh-TW', name: '繁體中文', flag: '🇹🇼' },
  { code: 'en-US', name: 'English', flag: '🇺🇸' },
  { code: 'ja-JP', name: '日本語', flag: '🇯🇵' },
  { code: 'ko-KR', name: '한국어', flag: '🇰🇷' },
] as const);

const SUPPORTED_LOCALE_CODES = SUPPORTED_LOCALES.map(l => l.code);

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
 * 更新HTML语言属性
 */
function updateHTMLLang(localeCode: string): void {
  try {
    if (typeof document !== 'undefined') {
      document.documentElement.lang = localeCode;
    }
  } catch (error) {
    console.error('Failed to update HTML lang attribute:', error);
  }
}

/**
 * 动态加载语言包
 */
async function loadLocaleMessages(localeCode: string): Promise<void> {
  try {
    // 这里可以动态导入语言包
    // const messages = await import(`@/locales/${localeCode}.json`)
    // 设置到 i18n 实例中
    safeLog(`Loading locale messages for: ${localeCode}`);
  } catch (error) {
    console.error(`Failed to load locale messages for ${localeCode}:`, error);
  }
}

/**
 * 检查是否为支持的语言
 */
export function isSupportedLocale(localeCode: string): boolean {
  return SUPPORTED_LOCALE_CODES.includes(localeCode);
}

/**
 * 获取浏览器默认语言
 */
export function getBrowserLocale(): string {
  try {
    if (typeof navigator === 'undefined') {
      return DEFAULT_LOCALE;
    }

    const browserLang = navigator.language || navigator.languages?.[0] || DEFAULT_LOCALE;

    // 尝试精确匹配
    if (isSupportedLocale(browserLang)) {
      return browserLang;
    }

    // 尝试匹配语言主部分
    const mainLang = browserLang.split('-')[0];
    const matchedLocale = SUPPORTED_LOCALES.find(l => l.code.split('-')[0] === mainLang);

    return matchedLocale?.code || DEFAULT_LOCALE;
  } catch (error) {
    console.error('Failed to get browser locale:', error);
    return DEFAULT_LOCALE;
  }
}

/**
 * 获取语言显示名称
 */
export function getLocaleName(localeCode: string): string {
  const localeInfo = SUPPORTED_LOCALES.find(l => l.code === localeCode);
  return localeInfo?.name || '简体中文';
}

/**
 * 获取语言旗帜图标
 */
export function getLocaleFlag(localeCode: string): string {
  const localeInfo = SUPPORTED_LOCALES.find(l => l.code === localeCode);
  return localeInfo?.flag || '🇨🇳';
}

/**
 * 获取所有支持的语言列表
 */
export function getSupportedLocales(): readonly SupportedLocale[] {
  return SUPPORTED_LOCALES;
}

// =============================================================================
// Pinia Store with Tauri Persistence
// =============================================================================

/**
 * Pinia store for locale management with Tauri persistence
 * 使用 @tauri-store/pinia 提供持久化和响应式支持
 */
export const useLocaleStore = defineStore(
  'locale',
  () => {
    // 状态
    const currentLocale = ref<string>(DEFAULT_LOCALE);
    const isLoading = ref<boolean>(false);
    const isInitializing = ref<boolean>(false);

    // 计算属性
    const currentLocaleInfo = computed((): SupportedLocale => {
      return SUPPORTED_LOCALES.find(l => l.code === currentLocale.value) || SUPPORTED_LOCALES[0];
    });

    const currentLocaleName = computed((): string => {
      return currentLocaleInfo.value.name;
    });

    const currentLocaleFlag = computed((): string => {
      return currentLocaleInfo.value.flag;
    });

    const supportedLocales = computed((): readonly SupportedLocale[] => {
      return SUPPORTED_LOCALES;
    });

    const isRTL = computed((): boolean => {
      // 如果需要支持 RTL 语言，可以在这里添加逻辑
      // const rtlLocales = ['ar', 'he', 'fa'];
      // return rtlLocales.some(lang => currentLocale.value.startsWith(lang));
      return false;
    });

    // 方法
    async function init(): Promise<void> {
      if (isInitializing.value) return;

      try {
        isInitializing.value = true;
        isLoading.value = true;

        // @tauri-store/pinia 会自动加载持久化的数据
        // 如果没有保存的语言或语言不受支持，使用浏览器语言
        if (!currentLocale.value || !isSupportedLocale(currentLocale.value)) {
          const browserLocale = getBrowserLocale();
          await setLocale(browserLocale);
        } else {
          updateHTMLLang(currentLocale.value);
        }

        safeLog('Locale store initialized successfully', { currentLocale: currentLocale.value });
      } catch (error) {
        console.error('Locale store initialization failed:', error);
        await setLocale(DEFAULT_LOCALE);
      } finally {
        isLoading.value = false;
        isInitializing.value = false;
      }
    }

    async function setLocale(newLocale: string): Promise<boolean> {
      if (!isSupportedLocale(newLocale)) {
        console.warn(`Unsupported locale: ${newLocale}`);
        return false;
      }

      try {
        isLoading.value = true;

        // 更新状态（会自动持久化）
        currentLocale.value = newLocale;

        // 更新HTML语言属性
        updateHTMLLang(newLocale);

        // 加载语言包
        await loadLocaleMessages(newLocale);

        safeLog(`Locale set to: ${newLocale}`);
        return true;
      } catch (error) {
        console.error('Failed to set locale:', error);
        return false;
      } finally {
        isLoading.value = false;
      }
    }

    async function switchToNextLocale(): Promise<void> {
      const currentIndex = SUPPORTED_LOCALES.findIndex(l => l.code === currentLocale.value);
      const nextIndex = (currentIndex + 1) % SUPPORTED_LOCALES.length;
      const nextLocale = SUPPORTED_LOCALES[nextIndex].code;

      await setLocale(nextLocale);
    }

    async function resetToDefault(): Promise<void> {
      await setLocale(DEFAULT_LOCALE);
    }

    function getCurrentLocale(): string {
      return currentLocale.value || DEFAULT_LOCALE;
    }

    return {
      // 状态（不使用 readonly，因为 @tauri-store/pinia 需要写入权限来加载持久化数据）
      currentLocale,
      isLoading,
      isInitializing,

      // 计算属性
      currentLocaleInfo,
      currentLocaleName,
      currentLocaleFlag,
      supportedLocales,
      isRTL,

      // 方法
      init,
      setLocale,
      switchToNextLocale,
      resetToDefault,
      getCurrentLocale,

      // 工具方法
      isSupportedLocale,
      getBrowserLocale,
      getLocaleName,
      getLocaleFlag,
      getSupportedLocales,
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
 * @deprecated 使用 useLocaleStore() 替代
 * 为了向后兼容而保留
 */
export async function startLocaleStore(): Promise<void> {
  const store = useLocaleStore();
  // 启动 Tauri store 持久化和同步
  await store.$tauri.start();
  // 初始化 store 逻辑
  await store.init();
}

/**
 * @deprecated 使用 useLocaleStore().getCurrentLocale() 替代
 */
export function getCurrentLocale(): string {
  const store = useLocaleStore();
  return store.getCurrentLocale();
}

/**
 * @deprecated 使用 useLocaleStore().setLocale() 替代
 */
export function updateLocale(newLocale: string | null): void {
  const store = useLocaleStore();
  store.setLocale(newLocale || DEFAULT_LOCALE);
}

/**
 * @deprecated 使用 useLocaleStore().resetToDefault() 替代
 */
export function resetLocale(): void {
  const store = useLocaleStore();
  store.resetToDefault();
}

// 导出类型定义
export type { SupportedLocale };

// 兼容性别名
export const useLocaleStores = useLocaleStore;
