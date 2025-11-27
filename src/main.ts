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
import { Lg } from './utils/debugLog';

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
  try {
    Lg.i('Main', '=== 应用启动开始 ===');
    Lg.i('Main', `环境: ${import.meta.env.MODE}`);
    Lg.i('Main', `基础路径: ${import.meta.env.BASE_URL}`);

    // 创建 Vue 应用
    Lg.i('Main', '创建 Vue 应用实例...');
    const app = createApp(App);

    // 配置 Pinia
    Lg.i('Main', '配置 Pinia...');
    const pinia = createPinia();
    pinia.use(createPlugin());
    app.use(pinia);
    Lg.i('Main', '✓ Pinia 配置完成');

    // 配置路由
    Lg.i('Main', '配置路由...');
    app.use(router);
    Lg.i('Main', '✓ 路由配置完成');

    // 配置 Toast
    Lg.i('Main', '配置 Toast...');
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
      // 提升层级到最高，确保在所有 modal 之上（Modal 最高 z-index: 999999）
      containerClassName: '!z-[99999999] pointer-events-none',
    });
    Lg.i('Main', '✓ Toast 配置完成');

    // 配置国际化
    Lg.i('Main', '配置国际化...');
    const i18n = await initI18n();
    app.use(i18n);
    Lg.i('Main', '✓ 国际化配置完成');

    // 注册全局指令
    Lg.i('Main', '注册全局指令...');
    app.directive('permission', vPermission);
    app.directive('has-value', vHasValue);
    Lg.i('Main', '✓ 全局指令注册完成');

    // 初始化 Money Store 事件监听器
    Lg.i('Main', '初始化 Money Store 事件监听器...');
    initMoneyStores();
    Lg.i('Main', '✓ Money Store 事件监听器初始化完成');

    // 启动应用
    Lg.i('Main', '开始应用引导程序...');
    const bootstrapper = new AppBootstrapper();
    await bootstrapper.bootstrap(app);
    Lg.i('Main', '=== 应用启动完成 ===');
  } catch (error) {
    console.error('应用启动失败:', error);
    // 显示错误信息到页面
    document.body.innerHTML = `
      <div style="display: flex; flex-direction: column; align-items: center; justify-content: center; height: 100vh; font-family: sans-serif; padding: 20px;">
        <h1 style="color: #ef4444; margin-bottom: 16px;">❌ 应用启动失败</h1>
        <p style="color: #6b7280; margin-bottom: 8px;">错误信息:</p>
        <pre style="background: #f3f4f6; padding: 16px; border-radius: 8px; max-width: 600px; overflow: auto;">${error instanceof Error ? error.message : String(error)}</pre>
        <button onclick="window.location.reload()" style="margin-top: 20px; padding: 8px 16px; background: #3b82f6; color: white; border: none; border-radius: 6px; cursor: pointer;">重新加载</button>
      </div>
    `;
    throw error;
  }
}

// 运行应用
main();
