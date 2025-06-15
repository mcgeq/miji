// src/lib/i18n.ts
import {
  register,
  init as svelteInit,
  getLocaleFromNavigator,
  addMessages,
} from 'svelte-i18n';
import { toast } from 'svelte-sonner';
import { getCurrentLocale, localeStore, updateLocale } from '../stores/locales';
import { Lg } from '../utils/debugLog';

// 注册语言文件
register('zh', () => import('$lib/locales/zh.json'));
register('en', () => import('$lib/locales/en.json'));

// 初始化 i18n
export async function init() {
  try {
    // 初始化 localeStore
    const savedLocale = getCurrentLocale();
    const browserLocale = getLocaleFromNavigator();
    const initialLocale = savedLocale || browserLocale || 'zh';

    await svelteInit({
      fallbackLocale: 'zh',
      initialLocale,
      loadingDelay: 200,
      warnOnMissingMessages: true,
    });

    Lg.i('I18n', `i18n initialized with locale: ${initialLocale}`);
  } catch (error) {
    toast.error('语言初始化失败，将使用默认语言', { duration: 5000 });
    Lg.e('I18n', error);
    await svelteInit({
      fallbackLocale: 'zh',
      initialLocale: 'zh',
      loadingDelay: 200,
      warnOnMissingMessages: true,
    });
  }
}

// 切换语言
export async function switchLocale(newLocale: string) {
  try {
    const messages = await import(`$lib/locales/${newLocale}.json`);
    addMessages(newLocale, messages.default);
    updateLocale(newLocale);
    await localeStore.save();
    console.log(`Switched to locale: ${newLocale}`);
    toast.success('语言切换成功', { duration: 3000 });
  } catch (error) {
    console.error(`Failed to switch to locale ${newLocale}:`, error);
    toast.error('切换语言失败', { duration: 3000 });
  }
}
export { getCurrentLocale };
