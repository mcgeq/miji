import { createPlugin } from '@tauri-store/pinia';
import { createPinia } from 'pinia';
import { createApp } from 'vue';
import Toast from 'vue-toastification';
import z from 'zod';
import App from './App.vue';
import { AppBootstrapper } from './bootstrap/app-bootstrapper';
import { vPermission } from './directives/permission';
import { vHasValue } from './directives/vHasValue';
import { initI18n } from './i18n/i18n';
import router from './router';
import { i18nErrorMap } from './schema/i18nErrorMap';
import { initMoneyStores } from './stores/money';

// 样式导入
import '@/assets/styles/index.css';
import 'vue-toastification/dist/index.css';

// Zod 配置
z.config({
  localeError: i18nErrorMap,
});

// Android 兼容性修复
if (!Object.hasOwn) {
  Object.hasOwn = (obj, prop) => Object.prototype.hasOwnProperty.call(obj, prop);
}

/**
 * 应用主入口
 */
async function main() {
  // 创建 Vue 应用
  const app = createApp(App);

  // 配置 Pinia
  const pinia = createPinia();
  pinia.use(createPlugin());
  app.use(pinia);

  // 配置路由
  app.use(router);

  // 配置 Toast
  app.use(Toast, {
    position: 'top-right',
    timeout: 5000,
    closeOnClick: true,
    pauseOnFocusLoss: true,
    pauseOnHover: true,
    draggable: true,
    draggablePercent: 0.6,
    showCloseButtonOnHover: false,
    hideProgressBar: false,
    closeButton: 'button',
    icon: true,
    rtl: false,
    teleport: 'body',
    containerClassName: 'z-[2147483647] pointer-events-none',
  });

  // 配置国际化
  const i18n = await initI18n();
  app.use(i18n);

  // 注册全局指令
  app.directive('permission', vPermission);
  app.directive('has-value', vHasValue);

  // 初始化 Money Store 事件监听器
  initMoneyStores();

  // 启动应用
  const bootstrapper = new AppBootstrapper();
  await bootstrapper.bootstrap(app);
}

// 运行应用
main();
