import App from './App.vue';
import 'uno.css';
import '@unocss/reset/tailwind.css';
import 'virtual:unocss-devtools';
import Toast from 'vue-toastification';
import {initI18n} from './i18n/i18n';
import router from './router';
import 'vue-toastification/dist/index.css';
import {createPinia} from 'pinia';
import z from 'zod';
import {i18nErrorMap} from './schema/i18nErrorMap';
import {storeStart} from './stores';

const app = createApp(App);

z.config({
  localeError: i18nErrorMap,
});
// Initialize i18n and mount the app
async function bootstrap() {
  try {
    const pinia = createPinia();
    app.use(pinia);
    app.use(router);

    app.use(Toast);

    await storeStart();
    // Wait for i18n to initialize
    const i18n = await initI18n();

    // Register i18n with the app
    app.use(i18n);

    // Load UnoCSS icons after window.onload
    window.onload = () => import('uno:icons.css');
    // Mount the app
    app.mount('#app');
  } catch (error) {
    console.error('Failed to bootstrap app:', error);
  }
}

// Run the bootstrap function
bootstrap();
