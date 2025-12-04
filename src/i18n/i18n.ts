// src/i18n/i18n.ts

import { createI18n } from 'vue-i18n';
import enMessagesRaw from '@/locales/en.json?raw';
import zhMessagesRaw from '@/locales/zh.json?raw';
import { useLocaleStore } from '@/stores/locales';
import { Lg } from '@/utils/debugLog';
import { toast } from '@/utils/toast';

type LocaleType = 'zh-CN' | 'en-US' | 'es-ES';

// 解析 JSON 字符串
const zhMessages = JSON.parse(zhMessagesRaw);
const enMessages = JSON.parse(enMessagesRaw);

// Vite 8.0: 初始化时使用静态导入的预加载消息
const i18nInstance = createI18n({
  legacy: false,
  locale: 'zh-CN',
  fallbackLocale: 'zh-CN',
  messages: {
    'zh-CN': zhMessages,
    'en-US': enMessages,
    'es-ES': enMessages,
  },
  globalInjection: true,
});

export async function initI18n() {
  try {
    Lg.i('I18n', '开始初始化国际化...');

    const localeStore = useLocaleStore();
    const savedLocale = localeStore.getCurrentLocale();
    const browserLocale = navigator.language;
    const initialLocale = savedLocale || browserLocale || 'zh-CN';

    Lg.i('I18n', `保存的语言: ${savedLocale || '无'}`);
    Lg.i('I18n', `浏览器语言: ${browserLocale}`);
    Lg.i('I18n', `初始语言: ${initialLocale}`);

    const validLocale = ['zh-CN', 'en-US', 'es-ES'].includes(initialLocale)
      ? (initialLocale as LocaleType)
      : ('zh-CN' as LocaleType);

    Lg.i('I18n', `最终使用语言: ${validLocale}`);

    // 语言包已通过静态导入预加载，直接设置当前语言
    i18nInstance.global.locale.value = validLocale;
    Lg.i('I18n', `✓ 当前语言设置为: ${validLocale}`);

    await localeStore.setLocale(initialLocale);
    Lg.i('I18n', '✓ 国际化初始化完成');

    return i18nInstance;
  } catch (error) {
    Lg.e('I18n', '国际化初始化失败:', error);
    toast.error('语言初始化失败，将使用默认语言');
    console.error('i18n init error:', error);

    return i18nInstance;
  }
}

export async function switchLocale(newLocale: LocaleType) {
  if (!i18nInstance) {
    toast.error('i18n 尚未初始化');
    return;
  }

  try {
    const localeStore = useLocaleStore();
    // 语言包已预加载，直接切换
    const localeRef = i18nInstance.global.locale as Ref<string>;
    localeRef.value = newLocale;
    await localeStore.setLocale(newLocale);
    toast.success('语言切换成功');
    Lg.i('I18n', `✓ 语言已切换至: ${newLocale}`);
  } catch (error) {
    toast.error('切换语言失败');
    Lg.e('I18', `Failed to switch to locale ${newLocale}:`, error);
  }
}

export { i18nInstance };
