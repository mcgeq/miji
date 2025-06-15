import { RuneStore } from '@tauri-store/svelte';
import { writable } from 'svelte/store';

// 定义状态类型
interface LocaleState {
  currentLocale: string | null;
  [key: string]: any; // 添加索引签名，满足 State 约束
}

// 语言存储
const localeStore = new RuneStore<LocaleState>('locale', {
  currentLocale: null as string | null,
});

// 可订阅的 store
export const locale = writable<LocaleState>(localeStore.state);

// 获取当前语言
export function getCurrentLocale(): string | null {
  return localeStore.state.currentLocale;
}

// 初始化 localeStore
export async function startLocaleStore() {
  await localeStore.start();
  locale.set(localeStore.state); // 同步初始状态
}

// 更新语言
export function updateLocale(newLocale: string | null) {
  localeStore.state.currentLocale = newLocale;
  locale.set(localeStore.state); // 同步到 writable store
}

export { localeStore };
