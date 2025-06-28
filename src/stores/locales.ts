import { createStore } from '@tauri-store/vue';
import { ref, readonly, watchEffect } from 'vue';

interface LocaleState {
  currentLocale: string | null;
  [key: string]: any;
}

// 创建持久化 store，默认值
const localeStore = createStore<LocaleState>('locale', {
  currentLocale: null,
});

// 本地响应式引用
const locale = ref({ ...localeStore.value });

// 初始化函数，加载持久化数据
export async function startLocaleStore() {
  await localeStore.$tauri.start();
  locale.value = { ...localeStore.value };
}

// 监听 store 变化，更新本地响应式数据
watchEffect(() => {
  locale.value = { ...localeStore.value };
});

// 获取当前语言
export function getCurrentLocale(): string | null {
  return locale.value.currentLocale;
}

// 更新语言，并同步到持久化 store
export function updateLocale(newLocale: string | null) {
  localeStore.value.currentLocale = newLocale;
  locale.value = { ...localeStore.value };
}

// 导出只读状态防止误修改
export const localeState = readonly(locale);

export { localeStore };
