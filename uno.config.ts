import { resolve } from 'node:path';
import { FileSystemIconLoader } from '@iconify/utils/lib/loader/node-loaders';
import presetAttributify from '@unocss/preset-attributify';
import presetIcons from '@unocss/preset-icons';
import presetWebFonts from '@unocss/preset-web-fonts';
import { createLocalFontProcessor } from '@unocss/preset-web-fonts/local';
import presetWind3 from '@unocss/preset-wind3';
import { defineConfig } from '@unocss/vite';
import { transformerDirectives, transformerVariantGroup } from 'unocss';

const iconDirectory = resolve(__dirname, 'icons');

export default defineConfig({
  shortcuts: [
    { logo: 'i-logos-vue w-6em h-6em transform transition-800' },
    ['flex-center', 'flex justify-center items-center'],
    ['flex-between', 'flex justify-between items-center'],
    ['flex-start', 'flex justify-start items-center'],
    ['flex-end', 'flex justify-end items-center'],

    // hidden
    ['show-on-desktop', 'hidden md:block'],
    ['show-on-mobile', 'block md:hidden'],
    // Button variants
    [
      'btn-base',
      'px-4 py-2 rounded-xl font-medium transition-all duration-200 hover:scale-105 active:scale-95 focus:outline-none',
    ],
    [
      'btn-primary',
      'btn-base bg-blue-600 hover:bg-blue-700 text-gray-500 shadow-md',
    ],
    [
      'btn-secondary',
      'btn-base bg-gray-100 hover:bg-gray-200 text-gray-700 dark:bg-gray-700 dark:hover:bg-gray-600 dark:text-gray-200',
    ],
    ['btn-danger', 'btn-base bg-red-500 hover:bg-red-600 text-white shadow-md'],
    [
      'btn-success',
      'btn-base bg-green-500 hover:bg-green-600 text-white shadow-md',
    ],
    [
      'btn-icon',
      'p-2 rounded-full transition-all duration-200 hover:scale-110 active:scale-95 focus:outline-none',
    ],
    [
      'btn-ghost',
      'btn-base bg-transparent hover:bg-gray-100 dark:hover:bg-gray-800 text-gray-700 dark:text-gray-300',
    ],

    // Card variants
    [
      'card-base',
      'bg-white dark:bg-gray-800 rounded-2xl shadow-sm border border-gray-200 dark:border-gray-700',
    ],
    ['card-hover', 'card-base hover:shadow-md transition-shadow duration-200'],
    [
      'card-glass',
      'bg-white/70 dark:bg-gray-900/80 backdrop-blur-lg border border-white/20 dark:border-gray-700/30',
    ],

    // Input variants
    [
      'input-base',
      'px-4 py-2 border border-gray-300 dark:border-gray-600 rounded-xl bg-white dark:bg-gray-800 text-gray-900 dark:text-white placeholder-gray-400 dark:placeholder-gray-500 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-all duration-200',
    ],
    ['input-sm', 'input-base px-2 py-1 text-sm'],
    ['input-lg', 'input-base px-4 py-3 text-lg'],

    // Modal variants
    [
      'modal-overlay',
      'fixed inset-0 bg-black/60 z-50 backdrop-blur-sm flex-center px-4',
    ],
    ['modal-content', 'card-glass p-6 rounded-2xl shadow-xl max-w-md w-full'],

    // 优化后的模态框按钮 - 柔和配色
    [
      'modal-btn-close',
      'px-3 py-2 rounded-lg font-medium border border-gray-200 dark:border-gray-600 bg-gray-50 dark:bg-gray-700 text-gray-600 dark:text-gray-300 hover:border-gray-300 dark:hover:border-gray-500 hover:bg-gray-100 dark:hover:bg-gray-600 hover:text-gray-700 dark:hover:text-gray-200 focus:outline-none focus:ring-2 focus:ring-gray-200 dark:focus:ring-gray-600 focus:border-transparent active:scale-98 transition-all duration-200 flex items-center justify-center gap-1.5',
    ],
    [
      'modal-btn-save',
      'px-3 py-2 rounded-lg font-medium border border-blue-200 dark:border-blue-600 bg-blue-50 dark:bg-blue-900/30 text-blue-700 dark:text-blue-300 hover:border-blue-300 dark:hover:border-blue-500 hover:bg-blue-100 dark:hover:bg-blue-900/50 hover:text-blue-800 dark:hover:text-blue-200 focus:outline-none focus:ring-2 focus:ring-blue-200 dark:focus:ring-blue-600 focus:border-transparent active:scale-98 transition-all duration-200 flex items-center justify-center gap-1.5',
    ],

    // Action button variants
    [
      'action-btn',
      'btn-icon text-gray-400 hover:text-blue-500 transition-colors duration-200 disabled:text-gray-300 disabled:cursor-not-allowed',
    ],
    [
      'action-btn-danger',
      'btn-icon text-red-400 hover:text-red-600 transition-colors duration-200 disabled:text-gray-300 disabled:cursor-not-allowed',
    ],
    [
      'action-btn-success',
      'btn-icon text-green-400 hover:text-green-600 transition-colors duration-200 disabled:text-gray-300 disabled:cursor-not-allowed',
    ],

    // Text variants
    ['text-muted', 'text-gray-500 dark:text-gray-400'],
    ['text-primary', 'text-blue-600 dark:text-blue-400'],
    ['text-danger', 'text-red-600 dark:text-red-400'],
    ['text-success', 'text-green-600 dark:text-green-400'],

    // Transition variants
    ['transition-fast', 'transition-all duration-150'],
    ['transition-normal', 'transition-all duration-200'],
    ['transition-slow', 'transition-all duration-300'],

    // Size utilities
    ['wh-4', 'w-4 h-4'],
    ['wh-5', 'w-5 h-5'],
    ['wh-6', 'w-6 h-6'],
    ['wh-8', 'w-8 h-8'],
    ['wh-10', 'w-10 h-10'],
    ['wh-12', 'w-12 h-12'],

    // Legacy shortcuts (for backward compatibility) - 使用优化后的样式
    ['flex-juster-center', 'flex justify-center items-center'],
    ['flex-justify-center', 'flex justify-center items-center'],

    // 优化后的遗留按钮样式 - 柔和配色
    [
      'modal-btn-x',
      'px-3 py-2 rounded-lg font-medium border border-gray-200 dark:border-gray-600 bg-gray-50 dark:bg-gray-700 text-gray-600 dark:text-gray-300 hover:border-gray-300 dark:hover:border-gray-500 hover:bg-gray-100 dark:hover:bg-gray-600 hover:text-gray-700 dark:hover:text-gray-200 focus:outline-none focus:ring-2 focus:ring-gray-200 dark:focus:ring-gray-600 focus:border-transparent active:scale-98 transition-all duration-200 flex items-center justify-center gap-1.5 min-w-[2.5rem] min-h-[2.5rem]',
    ],
    [
      'modal-btn-check',
      'px-3 py-2 rounded-lg font-medium border border-blue-200 dark:border-blue-600 bg-blue-50 dark:bg-blue-900/30 text-blue-700 dark:text-blue-300 hover:border-blue-300 dark:hover:border-blue-500 hover:bg-blue-100 dark:hover:bg-blue-900/50 hover:text-blue-800 dark:hover:text-blue-200 focus:outline-none focus:ring-2 focus:ring-blue-200 dark:focus:ring-blue-600 focus:border-transparent active:scale-98 transition-all duration-200 flex items-center justify-center gap-1.5 min-w-[2.5rem] min-h-[2.5rem]',
    ],

    [
      'modal-btn-icon',
      'w-full rounded-xl py-2 px-2 bg-blue-600 hover:bg-blue-700 flex-center text-white transition-colors duration-200',
    ],
    ['modal-mask', 'modal-overlay'],
    ['modal-mask-window', 'modal-content w-40 flex flex-col gap-4'],
    // 更新 modal-mask-window-money 定义
    [
      'modal-mask-window-money',
      'max-h-90vh min-h-0 overflow-y-auto bg-white rounded-lg p-6 w-full max-w-md mx-4 scrollbar-hide flex flex-col',
    ],
    // 添加滚动条隐藏的快捷方式
    [
      'scrollbar-hide',
      'scrollbar-width-none -ms-overflow-style-none [&::-webkit-scrollbar]:display-none',
    ],
    // 可选：添加平滑滚动
    ['scroll-smooth', 'scroll-behavior-smooth'],
    // 可选：为 Modal 内容区域单独定义样式
    ['modal-content-scrollable', 'flex-1 overflow-y-auto scrollbar-hide'],
    // 可选：Modal 头部固定样式
    ['modal-header-fixed', 'flex-shrink-0 pb-4 border-b border-gray-200'],
    // 可选：Modal 底部固定样式
    ['modal-footer-fixed', 'flex-shrink-0 pt-4 border-t border-gray-200'],
    ['modal-input-select', 'input-base'],
    [
      'money-option-btn',
      'wh-8 bg-white rounded cursor-pointer flex-center transition-all text-xs hover:bg-gray-50',
    ],
    // filter
    ['filter-flex-wrap', 'flex p-2 border border-gray-200 rounded-md items-center gap-2']
  ],
  rules: [
    [/^scrollbar-width-(.+)$/, ([, c]) => ({ 'scrollbar-width': c })],
    [/^-ms-overflow-style-(.+)$/, ([, c]) => ({ '-ms-overflow-style': c })],
  ],
  presets: [
    presetWind3(),
    presetAttributify(),
    presetIcons({
      extraProperties: {
        display: 'inline-block',
        'vertical-align': 'middle',
      },
      collections: {
        custom: FileSystemIconLoader(iconDirectory),
      },
    }),
    presetWebFonts({
      provider: 'google',
      fonts: {
        sans: 'Roboto',
        mono: ['Fira Code', 'Fira Mono:400,700'],
        lobster: 'Lobster',
        lato: [
          {
            name: 'Lato',
            weights: ['400', '700'],
            italic: true,
          },
          {
            name: 'sans-serif',
            provider: 'none',
          },
        ],
      },
      processors: createLocalFontProcessor(),
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
});
