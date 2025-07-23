// stores/locales.ts
import { createStore } from '@tauri-store/vue';
import { defineStore } from 'pinia';

// =============================================================================
// 类型定义
// =============================================================================

interface LocaleState {
  currentLocale: string | null;
  [key: string]: any;
}

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
// Tauri Store 核心实现 (保持原有API不变)
// =============================================================================

// 创建持久化 store，默认值
const localeStore = createStore<LocaleState>('locale', {
  currentLocale: null,
});

// 本地响应式引用
const locale = ref({ ...localeStore.value });

// 初始化状态
let isInitialized = false;

// =============================================================================
// 工具函数
// =============================================================================

/**
 * 检查是否为开发环境
 */
function isDevelopment(): boolean {
  return (
    import.meta.env?.DEV === true
      || import.meta.env?.MODE === 'development'
      || (typeof window !== 'undefined' && window.location?.hostname === 'localhost')
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
  }
  catch (error) {
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
  }
  catch (error) {
    console.error(`Failed to load locale messages for ${localeCode}:`, error);
  }
}

// =============================================================================
// 核心API函数 (保持原有接口不变)
// =============================================================================

/**
 * 初始化函数，加载持久化数据
 */
export async function startLocaleStore(): Promise<void> {
  try {
    if (!isInitialized) {
      await localeStore.$tauri.start();
      locale.value = { ...localeStore.value };
      isInitialized = true;
      safeLog('Locale store initialized successfully');
    }
  }
  catch (error) {
    console.error('Failed to start locale store:', error);
    // 设置默认值
    locale.value = { currentLocale: DEFAULT_LOCALE };
    isInitialized = true;
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

    const browserLang
      = navigator.language || navigator.languages?.[0] || DEFAULT_LOCALE;

    // 尝试精确匹配
    if (isSupportedLocale(browserLang)) {
      return browserLang;
    }

    // 尝试匹配语言主部分
    const mainLang = browserLang.split('-')[0];
    const matchedLocale = SUPPORTED_LOCALES.find(
      l => l.code.split('-')[0] === mainLang,
    );

    return matchedLocale?.code || DEFAULT_LOCALE;
  }
  catch (error) {
    console.error('Failed to get browser locale:', error);
    return DEFAULT_LOCALE;
  }
}

/**
 * 获取当前语言
 */
export function getCurrentLocale(): string {
  return locale.value.currentLocale || DEFAULT_LOCALE;
}

/**
 * 更新语言，并同步到持久化 store
 */
export function updateLocale(newLocale: string | null): void {
  try {
    const targetLocale = newLocale || DEFAULT_LOCALE;

    if (!isSupportedLocale(targetLocale)) {
      console.warn(`Unsupported locale: ${targetLocale}, fallback to default`);
      return;
    }

    localeStore.value.currentLocale = targetLocale;
    locale.value = { ...localeStore.value };

    // 更新HTML语言属性
    updateHTMLLang(targetLocale);

    safeLog(`Locale updated to: ${targetLocale}`);
  }
  catch (error) {
    console.error('Failed to update locale:', error);
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

/**
 * 重置为默认语言
 */
export function resetLocale(): void {
  updateLocale(DEFAULT_LOCALE);
}

// =============================================================================
// 响应式监听
// =============================================================================

// 监听 store 变化，更新本地响应式数据
watchEffect(() => {
  if (isInitialized) {
    locale.value = { ...localeStore.value };
  }
});

// =============================================================================
// Pinia Store 集成
// =============================================================================

/**
 * Pinia store for locale management
 * 提供更丰富的响应式API和组合式函数支持
 */
export const useLocaleStore = defineStore('locale', () => {
  // 状态
  const isLoading = ref(false);
  const isInitializing = ref(false);

  // 计算属性
  const currentLocale = computed(() => getCurrentLocale());

  const currentLocaleInfo = computed(() => {
    const code = currentLocale.value;
    return SUPPORTED_LOCALES.find(l => l.code === code) || SUPPORTED_LOCALES[0];
  });

  const currentLocaleName = computed(() => currentLocaleInfo.value.name);
  const currentLocaleFlag = computed(() => currentLocaleInfo.value.flag);

  const supportedLocales = computed(() => SUPPORTED_LOCALES);

  const isRTL = computed(() => {
    // 如果需要支持 RTL 语言，可以在这里添加逻辑
    // const rtlLocales = ['ar', 'he', 'fa'];
    // return rtlLocales.some(lang => currentLocale.value.startsWith(lang));
    return false;
  });

  const setLocale = async (newLocale: string): Promise<boolean> => {
    if (!isSupportedLocale(newLocale)) {
      console.warn(`Unsupported locale: ${newLocale}`);
      return false;
    }

    try {
      isLoading.value = true;

      // 更新核心store
      updateLocale(newLocale);

      // 加载语言包
      await loadLocaleMessages(newLocale);

      safeLog(`Locale set to: ${newLocale}`);
      return true;
    }
    catch (error) {
      console.error('Failed to set locale:', error);
      return false;
    }
    finally {
      isLoading.value = false;
    }
  };

  // 方法
  const init = async (): Promise<void> => {
    if (isInitializing.value)
      return;

    try {
      isInitializing.value = true;
      isLoading.value = true;

      await startLocaleStore();

      const savedLocale = getCurrentLocale();
      if (savedLocale && isSupportedLocale(savedLocale)) {
        // 语言已经通过 startLocaleStore 加载
        updateHTMLLang(savedLocale);
      }
      else {
        // 尝试从浏览器获取语言设置
        const browserLocale = getBrowserLocale();
        await setLocale(browserLocale);
      }

      safeLog('Pinia locale store initialized successfully');
    }
    catch (error) {
      console.error('Pinia locale store initialization failed:', error);
      await setLocale(DEFAULT_LOCALE);
    }
    finally {
      isLoading.value = false;
      isInitializing.value = false;
    }
  };

  const switchToNextLocale = async (): Promise<void> => {
    const currentIndex = SUPPORTED_LOCALES.findIndex(
      l => l.code === currentLocale.value,
    );
    const nextIndex = (currentIndex + 1) % SUPPORTED_LOCALES.length;
    const nextLocale = SUPPORTED_LOCALES[nextIndex].code;

    await setLocale(nextLocale);
  };

  const resetToDefault = async (): Promise<void> => {
    await setLocale(DEFAULT_LOCALE);
  };

  // 监听语言变化
  watch(currentLocale, (newLocale, oldLocale) => {
    if (newLocale !== oldLocale) {
      safeLog(`Locale changed from ${oldLocale} to ${newLocale}`);
      // 这里可以添加语言变化的副作用
      // 例如：触发全局事件、更新第三方库配置等
    }
  });

  return {
    // 状态 (只读)
    currentLocale,
    supportedLocales,
    currentLocaleInfo,
    isLoading: computed(() => isLoading.value),
    isInitializing: computed(() => isInitializing.value),

    // 计算属性
    currentLocaleName,
    currentLocaleFlag,
    isRTL,

    // 方法
    init,
    setLocale,
    getCurrentLocale, // 兼容性方法
    isSupportedLocale,
    getBrowserLocale,
    switchToNextLocale,
    resetToDefault,
    getLocaleName,
    getLocaleFlag,
    getSupportedLocales,
  };
});

// =============================================================================
// 向后兼容性导出
// =============================================================================

// 导出只读状态防止误修改
export const localeState = readonly(locale);

// 导出 store 实例（向后兼容）
export { localeStore };

// 导出类型定义
export type { LocaleState, SupportedLocale };

// 兼容性别名
export const useLocaleStores = useLocaleStore;
