// src/lib/i18n.ts
import { register, init, getLocaleFromNavigator } from 'svelte-i18n';

// 注册语言文件
register('zh', () => import('$lib/locales/zh.json'));
register('en', () => import('$lib/locales/en.json'));

init({
  fallbackLocale: 'zh',
  initialLocale: getLocaleFromNavigator(),
  loadingDelay: 200,
  warnOnMissingMessages: true,
});
