// src/i18n/utils.ts

import { i18nInstance } from './i18n';

export function $t(key: string, values?: Record<string, unknown>): string {
  if (!i18nInstance) {
    console.warn('i18n instance not initialized');
    return key;
  }

  // 处理 bigint 值
  if (values) {
    const processedValues: Record<string, unknown> = {};
    for (const k of Object.keys(values)) {
      processedValues[k] = typeof values[k] === 'bigint' ? String(values[k]) : values[k];
    }
    // @ts-expect-error - vue-i18n 类型推断过于复杂
    return i18nInstance.global.t(key, processedValues) as string;
  }

  return i18nInstance.global.t(key) as string;
}
