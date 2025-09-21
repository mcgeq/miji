import { resolve } from 'node:path';
import { env } from 'node:process';
import { FileSystemIconLoader } from '@iconify/utils/lib/loader/node-loaders';
import { defineConfig } from '@unocss/vite';
import { presetAttributify, presetIcons, presetWind4, transformerDirectives, transformerVariantGroup } from 'unocss';

const iconDirectory = resolve(__dirname, 'icons');
// 在构建时确定环境，避免运行时依赖
const isProduction = env.NODE_ENV === 'production';
const isDevelopment = env.NODE_ENV === 'development';

export default defineConfig({
  shortcuts: [
  ],
  rules: [
    [/^scrollbar-width-(.+)$/, ([, c]) => ({ 'scrollbar-width': c })],
    [/^-ms-overflow-style-(.+)$/, ([, c]) => ({ '-ms-overflow-style': c })],
  ],
  presets: [
    presetWind4(),
    presetAttributify(),
    presetIcons({
      extraProperties: {
        'display': 'inline-block',
        'vertical-align': 'middle',
      },
      collections: {
        custom: FileSystemIconLoader(iconDirectory),
      },
      // 在 Android 上确保图标正确显示
      warn: isDevelopment,
    }),
  ],
  transformers: [transformerDirectives(), transformerVariantGroup()],
  theme: {
    colors: {
      primary: {
        50: '#eff6ff',
        100: '#dbeafe',
        200: '#bfdbfe',
        300: '#93c5fd',
        400: '#60a5fa',
        500: '#3b82f6',
        600: '#2563eb',
        700: '#1d4ed8',
        800: '#1e40af',
        900: '#1e3a8a',
      },
    },
    maxHeight: {
      '90vh': '90vh',
      '80vh': '80vh',
      '70vh': '70vh',
    },
    animation: {
      'fade-in': 'fadeIn 0.3s ease-in-out',
      'slide-up': 'slideUp 0.3s ease-out',
      'bounce-in': 'bounceIn 0.5s ease-out',
    },
    keyframes: {
      fadeIn: {
        '0%': { opacity: '0' },
        '100%': { opacity: '1' },
      },
      slideUp: {
        '0%': { transform: 'translateY(10px)', opacity: '0' },
        '100%': { transform: 'translateY(0)', opacity: '1' },
      },
      bounceIn: {
        '0%': { transform: 'scale(0.3)', opacity: '0' },
        '50%': { transform: 'scale(1.05)' },
        '70%': { transform: 'scale(0.9)' },
        '100%': { transform: 'scale(1)', opacity: '1' },
      },
    },
  },
  // 生产环境优化
  ...(isProduction && {
    // 确保关键样式始终包含
    safelist: [
      // 基础布局类
      'flex',
      'flex-col',
      'flex-row',
      'flex-center',
      'flex-between',
      'hidden',
      'block',
      'inline-block',
      // 响应式显示类
      'show-on-desktop',
      'show-on-mobile',
      'md:block',
      'md:hidden',
      // 按钮样式
      'btn-base',
      'btn-primary',
      'btn-secondary',
      'btn-danger',
      'btn-success',
      // 模态框样式
      'modal-overlay',
      'modal-content',
      'modal-btn-close',
      'modal-btn-save',
      // 卡片样式
      'card-base',
      'card-hover',
      'card-glass',
      // 输入框样式
      'input-base',
      'input-sm',
      'input-lg',
      // 文本颜色
      'text-muted',
      'text-primary',
      'text-danger',
      'text-success',
      // 过渡效果
      'transition-fast',
      'transition-normal',
      'transition-slow',
      // 滚动条相关
      'scrollbar-hide',
      'scroll-smooth',
      // 深色模式相关
      'dark:bg-gray-800',
      'dark:text-white',
      'dark:border-gray-700',
    ],
  }),
  // 预检样式 - 针对 Android WebView 优化
  preflights: [
    {
      getCSS: () => `
        * {
          box-sizing: border-box;
        }
        
        html {
          -webkit-text-size-adjust: 100%;
          -webkit-tap-highlight-color: transparent;
          -webkit-touch-callout: none;
          -webkit-user-select: none;
          user-select: none;
        }
        
        body {
          margin: 0;
          line-height: inherit;
          -webkit-font-smoothing: antialiased;
          -moz-osx-font-smoothing: grayscale;
          overflow-x: hidden;
        }
        
        /* Android WebView 特殊优化 */
        @supports (-webkit-touch-callout: none) {
          body {
            -webkit-overflow-scrolling: touch;
          }
        }
        
        /* 确保自定义滚动条样式在 Android 上正确工作 */
        .scrollbar-hide {
          scrollbar-width: none;
          -ms-overflow-style: none;
        }
        
        .scrollbar-hide::-webkit-scrollbar {
          display: none;
        }
        
        /* 修复 Android 上的点击高亮问题 */
        * {
          -webkit-tap-highlight-color: rgba(0,0,0,0);
          -webkit-focus-ring-color: rgba(0,0,0,0);
        }
        
        /* 确保模态框在移动设备上正确显示 */
        .modal-overlay {
          position: fixed;
          top: 0;
          left: 0;
          right: 0;
          bottom: 0;
          z-index: 9999;
        }
        
        /* 确保UnoCSS基础样式正确应用 */
        .uno-layer-base {
          z-index: -1;
        }
        
        /* 移动端视口高度修复 */
        @supports (height: 100dvh) {
          .h-screen {
            height: 100dvh;
          }
        }
        
        /* 修复Android上的输入框样式 */
        input, textarea, select {
          -webkit-appearance: none;
          appearance: none;
          background-color: transparent;
        }
        
        /* 确保图标正确显示 */
        [class*="i-"], .iconify {
          display: inline-block;
          vertical-align: middle;
        }
      `,
    },
  ],
  // 开发工具配置 - 使用构建时常量
  inspector: isDevelopment,
  // 确保样式正确提取
  extractors: [
    {
      name: 'custom-extractor',
      extract: ctx => {
        const { code } = ctx;

        // 匹配所有可能的类名，包括动态生成的
        const matches = code.match(/[\w:-]+/g) || [];
        // 匹配 class 属性中的类名
        const classMatches = code.match(/class\w*=['"`]([^'"`]*)['"`]/g) || [];

        const classNames = classMatches
          .map((match: string) =>
            match.replace(/class\w*=['"`]([^'"`]*)['"`]/, '$1').split(' '),
          )
          .flat();
        return [...matches, ...classNames].filter(Boolean);
      },
    },
  ],
});
