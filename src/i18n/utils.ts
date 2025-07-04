// src/i18n/utils.ts

import { i18nInstance } from './i18n';
import type { Composer } from 'vue-i18n';

export function $t(key: string, values?: Record<string, any>): string {
  if (!i18nInstance) {
    console.warn('i18n instance not initialized');
    return key;
  }

  // 强制断言为 Composition 模式下的 t 函数
  const t = i18nInstance.global.t as Composer['t'];

  if (values) {
    Object.keys(values).forEach((k) => {
      if (typeof values[k] === 'bigint') {
        values[k] = values[k].toString();
      }
    });
  }

  return t(key, values ?? {});
}
