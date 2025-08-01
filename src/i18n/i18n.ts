// src/i18n/i18n.ts

import { createI18n } from 'vue-i18n';
import zhCNMessages from '@/locales/zh.json';
import { Lg } from '@/utils/debugLog';
import { toast } from '@/utils/toast';
import { getCurrentLocale, updateLocale } from '../stores/locales';

type LocaleType = 'zh-CN' | 'en-US' | 'es-ES';
const i18nInstance = createI18n({
  legacy: false,
  locale: 'zh-CN',
  fallbackLocale: 'zh-CN',
  messages: { 'zh-CN': zhCNMessages, 'en-US': {}, 'es-ES': {} },
  globalInjection: true,
});

async function loadLocaleMessages(locales: LocaleType) {
  try {
    const locale = locales.split('-')[0];
    const messages = await import(`@/locales/${locale}.json`);
    return messages.default;
  }
  catch (error) {
    Lg.e('I18', `Failed to load locale messages for ${locales}:`, error);
    return null;
  }
}

export async function initI18n() {
  try {
    const savedLocale = getCurrentLocale();
    const browserLocale = navigator.language;
    const initialLocale = savedLocale || browserLocale || 'zh-CN';
    const validLocale = ['zh-CN', 'en-US', 'es-ES'].includes(initialLocale)
      ? (initialLocale as LocaleType)
      : ('zh-CN' as LocaleType);
    if (validLocale !== 'zh-CN') {
      const messages = await loadLocaleMessages(validLocale);
      if (messages) {
        i18nInstance.global.setLocaleMessage(validLocale, messages);
        i18nInstance.global.locale.value = validLocale;
      }
    }

    updateLocale(initialLocale);

    return i18nInstance;
  }
  catch (error) {
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
    if (!i18nInstance.global.availableLocales.includes(newLocale)) {
      const messages = await loadLocaleMessages(newLocale);
      if (!messages)
        throw new Error('语言包加载失败');
      i18nInstance.global.setLocaleMessage(newLocale, messages);
    }
    if (i18nInstance) {
      // 断言 global.locale 是 Ref<string>
      const localeRef = i18nInstance.global.locale as Ref<string>;
      localeRef.value = newLocale;
    }
    updateLocale(newLocale);
    toast.success('语言切换成功');
  }
  catch (error) {
    toast.error('切换语言失败');
    Lg.e('I18', `Failed to switch to locale ${newLocale}:`, error);
  }
}

export { i18nInstance };
