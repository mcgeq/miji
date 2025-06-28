// src/i18n/i18n.ts

import { createI18n } from 'vue-i18n';
import { getCurrentLocale, updateLocale } from '../stores/locales';
import { Ref } from 'vue';
import { toast } from '@/utils/toast';

let i18nInstance: ReturnType<typeof createI18n> | null = null;

async function loadLocaleMessages(locale: string) {
  try {
    const messages = await import(`@/locales/${locale}.json`);
    return messages.default;
  } catch (error) {
    console.error(`Failed to load locale messages for ${locale}:`, error);
    return null;
  }
}

export async function initI18n() {
  try {
    const savedLocale = getCurrentLocale();
    const browserLocale = navigator.language.split('-')[0];
    const initialLocale = savedLocale || browserLocale || 'zh';

    const messages = await loadLocaleMessages(initialLocale);

    i18nInstance = createI18n({
      legacy: false,
      locale: initialLocale,
      fallbackLocale: 'zh',
      messages: messages ? { [initialLocale]: messages } : {},
      globalInjection: true,
    });

    updateLocale(initialLocale);

    return i18nInstance;
  } catch (error) {
    toast.error('语言初始化失败，将使用默认语言');
    console.error('i18n init error:', error);

    const messages = await loadLocaleMessages('zh');

    i18nInstance = createI18n({
      legacy: false,
      locale: 'zh',
      fallbackLocale: 'zh',
      messages: messages ? { zh: messages } : {},
      globalInjection: true,
    });

    updateLocale('zh');

    return i18nInstance;
  }
}

export async function switchLocale(newLocale: string) {
  if (!i18nInstance) {
    toast.error('i18n 尚未初始化');
    return;
  }

  try {
    if (!i18nInstance.global.availableLocales.includes(newLocale)) {
      const messages = await loadLocaleMessages(newLocale);
      if (!messages) throw new Error('语言包加载失败');
      i18nInstance.global.setLocaleMessage(newLocale, messages);
    }
    if (i18nInstance) {
      // 断言 global.locale 是 Ref<string>
      const localeRef = i18nInstance.global.locale as Ref<string>;
      localeRef.value = newLocale;
    }
    updateLocale(newLocale);
    toast.success('语言切换成功');
    console.log(`Switched to locale: ${newLocale}`);
  } catch (error) {
    toast.error('切换语言失败');
    console.error(`Failed to switch to locale ${newLocale}:`, error);
  }
}

export { i18nInstance };
