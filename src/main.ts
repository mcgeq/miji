import { createPinia } from 'pinia';
import Toast from 'vue-toastification';
import z from 'zod';
import App from './App.vue';
import { initI18n } from './i18n/i18n';
import router from './router';
import { i18nErrorMap } from './schema/i18nErrorMap';
import { storeStart } from './stores';
import '@unocss/reset/tailwind.css';
import 'uno.css';
import 'vue-toastification/dist/index.css';

z.config({
  localeError: i18nErrorMap,
});

const isTauri = '__TAURI__' in window;
const isMobile = /Android|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(
  navigator.userAgent,
);

// 创建前端启动画面（用于移动端）
function createFrontendSplashscreen() {
  const splashscreen = document.createElement('div');
  splashscreen.id = 'frontend-splashscreen';
  splashscreen.innerHTML = `
    <style>
      #frontend-splashscreen {
        position: fixed;
        top: 0;
        left: 0;
        width: 100%;
        height: 100%;
        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        display: flex;
        justify-content: center;
        align-items: center;
        z-index: 9999;
        font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
      }
      
      .splash-container {
        text-align: center;
        color: white;
        display: flex;
        flex-direction: column;
        align-items: center;
        gap: 2rem;
      }
      
      .logo {
        width: 80px;
        height: 80px;
        background: rgba(255, 255, 255, 0.2);
        border-radius: 20px;
        display: flex;
        align-items: center;
        justify-content: center;
        font-size: 2.5rem;
        font-weight: bold;
        backdrop-filter: blur(10px);
        border: 1px solid rgba(255, 255, 255, 0.3);
        animation: pulse 2s infinite;
      }
      
      .app-name {
        font-size: 2rem;
        font-weight: 600;
        margin-bottom: 0.5rem;
        opacity: 0.9;
      }
      
      .loading-text {
        font-size: 0.9rem;
        opacity: 0.7;
        margin-bottom: 1rem;
      }
      
      .spinner {
        width: 40px;
        height: 40px;
        border: 3px solid rgba(255, 255, 255, 0.3);
        border-top: 3px solid white;
        border-radius: 50%;
        animation: spin 1s linear infinite;
      }
      
      .progress-bar {
        width: 200px;
        height: 4px;
        background: rgba(255, 255, 255, 0.3);
        border-radius: 2px;
        overflow: hidden;
        margin-top: 1rem;
      }
      
      .progress-fill {
        height: 100%;
        background: white;
        border-radius: 2px;
        width: 0%;
        animation: progress 3s ease-in-out forwards;
      }
      
      @keyframes spin {
        0% { transform: rotate(0deg); }
        100% { transform: rotate(360deg); }
      }
      
      @keyframes pulse {
        0%, 100% { transform: scale(1); opacity: 1; }
        50% { transform: scale(1.05); opacity: 0.8; }
      }
      
      @keyframes progress {
        0% { width: 0%; }
        30% { width: 30%; }
        60% { width: 60%; }
        90% { width: 90%; }
        100% { width: 100%; }
      }
      
      .fade-out {
        animation: fadeOut 0.5s ease-out forwards;
      }
      
      @keyframes fadeOut {
        from { opacity: 1; }
        to { opacity: 0; }
      }
    </style>
    <div class="splash-container">
      <div class="logo">M</div>
      <div class="app-name">MiJi</div>
      <div class="loading-text">正在加载应用...</div>
      <div class="spinner"></div>
      <div class="progress-bar">
        <div class="progress-fill"></div>
      </div>
    </div>
  `;

  document.body.appendChild(splashscreen);
  return splashscreen;
}

// 关闭前端启动画面
function closeFrontendSplashscreen(splashscreen: HTMLElement | null) {
  if (splashscreen) {
    splashscreen.classList.add('fade-out');
    setTimeout(() => {
      splashscreen.remove();
    }, 500); // 等待淡出动画完成
  }
}

// 预加载UnoCSS图标
async function preloadIcons() {
  try {
    // 直接导入而不是使用window.onload
    await import('uno:icons.css');
  } catch (error) {
    console.warn('Failed to load UnoCSS icons:', error);
  }
}

// 等待DOM和资源完全准备就绪
function waitForReady(): Promise<void> {
  return new Promise(resolve => {
    if (document.readyState === 'complete') {
      resolve();
    } else {
      const onReady = () => {
        document.removeEventListener('DOMContentLoaded', onReady);
        window.removeEventListener('load', onReady);
        resolve();
      };

      document.addEventListener('DOMContentLoaded', onReady);
      window.addEventListener('load', onReady);
    }
  });
}

// Initialize i18n and mount the app
async function bootstrap() {
  let frontendSplash: HTMLElement | null = null;
  try {
    // 在移动端创建前端启动画面
    if (isMobile) {
      frontendSplash = createFrontendSplashscreen();
    }
    // 等待DOM准备就绪
    await waitForReady();
    // 在移动端添加额外延迟确保资源加载完成
    if (isMobile || isTauri) {
      await new Promise(resolve => setTimeout(resolve, 200));
    }
    const app = createApp(App);
    const pinia = createPinia();
    app.use(pinia);
    app.use(router);

    app.use(Toast, {
      // Toast配置，避免在移动端出现问题
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
    });

    await storeStart();
    // Wait for i18n to initialize
    const i18n = await initI18n();

    // Register i18n with the app
    app.use(i18n);

    // 预加载图标（不阻塞应用启动）
    await preloadIcons();

    // Mount the app
    app.mount('#app');

    await handlePostMount();
    // 发射应用准备完成事件给 Tauri 后端（仅桌面端）
    // 关闭启动画面
    if (isMobile) {
      // 移动端：关闭前端启动画面
      closeFrontendSplashscreen(frontendSplash);
    }
  } catch (error) {
    console.error('Failed to bootstrap app:', error);

    // 错误恢复：显示基本的错误信息
    document.body.innerHTML = `
      <div style="
        display: flex; 
        justify-content: center; 
        align-items: center; 
        height: 100vh; 
        font-family: sans-serif;
        text-align: center;
        padding: 20px;
      ">
        <div>
          <h1>App Loading Error</h1>
          <p>Failed to start the application. Please restart the app.</p>
          <button onclick="window.location.reload()" style="
            padding: 10px 20px; 
            margin-top: 20px; 
            background: #007bff; 
            color: white; 
            border: none; 
            border-radius: 5px;
            cursor: pointer;
          ">Reload</button>
        </div>
      </div>
    `;
  }
}

// 后处应挂理用的载;
async function handlePostMount() {
  // 确保UnoCSS样式正确应用
  await new Promise(resolve => setTimeout(resolve, 100));

  // 检查UnoCSS是否正常工作
  const testElement = document.createElement('div');
  testElement.className = 'hidden';
  testElement.style.visibility = 'visible';
  document.body.appendChild(testElement);

  const computed = window.getComputedStyle(testElement);
  if (computed.display !== 'none') {
    console.warn('UnoCSS may not be working correctly');

    // 尝试重新加载CSS
    try {
      const link = document.createElement('link');
      link.rel = 'stylesheet';
      link.href = 'uno.css';
      document.head.appendChild(link);
    } catch (error) {
      console.error('Failed to reload CSS:', error);
    }
  }

  document.body.removeChild(testElement);

  // 在Tauri环境中的额外处理
  if (isTauri) {
    // 防止右键菜单（移动端不需要）
    if (!isMobile) {
      document.addEventListener('contextmenu', e => {
        e.preventDefault();
        return false;
      });
    }

    // 防止拖拽（可选）
    document.addEventListener('dragover', e => e.preventDefault());
    document.addEventListener('drop', e => e.preventDefault());
  }
}

// Run the bootstrap function
bootstrap();
