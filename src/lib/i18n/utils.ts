// src/lib/i18n/utils.ts
import { get } from 'svelte/store';
import { t as svelteI18nT } from 'svelte-i18n';

const t = svelteI18nT;

export function $t(key: string, values?: Record<string, any>): string {
  const translate = get(t);
  if (typeof translate === 'function') {
    // 把 bigint 转成字符串，防止类型不匹配
    if (values) {
      for (const k in values) {
        if (typeof values[k] === 'bigint') {
          values[k] = values[k].toString();
        }
      }
    }
    return translate({ id: key, values: values ?? {} });
  }
  return key;
}
