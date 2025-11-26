import { resolve } from 'node:path';
import { env } from 'node:process';
import VueI18n from '@intlify/unplugin-vue-i18n/vite';
import Vue from '@vitejs/plugin-vue';
// UnoCSS已移除
import AutoImport from 'unplugin-auto-import/vite';
import Components from 'unplugin-vue-components/vite';
import { VueRouterAutoImports } from 'unplugin-vue-router';
import VueRouter from 'unplugin-vue-router/vite';
import { defineConfig } from 'vite';
import vueDevTools from 'vite-plugin-vue-devtools';
import tailwindcss from '@tailwindcss/vite';

const host = env.TAURI_DEV_HOST;
function LucideResolver(componentName: string) {
  if (componentName.startsWith('Lucide')) {
    return {
      name: componentName.slice(6), // e.g. LucideHome -> Home
      from: 'lucide-vue-next',
    };
  }
  return null;
}

// https://vitejs.dev/config/
export default defineConfig({
  // Tauri 需要使用相对路径，避免打包后白屏
  base: './',
  plugins: [
    tailwindcss(),
    VueRouter({
      extensions: ['.vue', '.md'],
      dts: 'src/typed-router.d.ts',
    }),
    Vue({
      template: {
        compilerOptions: {
          whitespace: 'preserve',
        },
      },
    }),
    Components({
      dts: true,
      resolvers: [LucideResolver],
    }),
    AutoImport({
      include: [/\.[jt]sx?$/, /\.vue$/, /\.vue\?vue/, /\.md$/],
      imports: [
        'vue',
        'vue-i18n',
        '@vueuse/core',
        'pinia',
        VueRouterAutoImports,
        {
          // add any other imports you were relying on
          'vue-router/auto': ['useLink'],
        },
      ],
      dts: 'src/auto-imports.d.ts',
      dirs: ['src/stores', 'src/composables'],
      vueTemplate: true,
    }),
    // https://github.com/intlify/bundle-tools/tree/main/packages/unplugin-vue-i18n
    VueI18n({
      runtimeOnly: true,
      compositionOnly: true,
      fullInstall: true,
      include: [resolve(__dirname, './src/locales/**')],
    }),
    vueDevTools(),
  ],
  resolve: {
    alias: {
      '@': resolve(__dirname, 'src'),
    },
  },
  css: {
    postcss: './postcss.config.mjs',
  },
  // Vite options tailored for Tauri development and only applied in `tauri dev` or `tauri build`
  //
  // 1. prevent vite from obscuring rust errors
  clearScreen: false,
  // 2. tauri expects a fixed port, fail if that port is not available
  server: {
    port: 9428,
    strictPort: true,
    host: host || false,
    hmr: host
      ? {
        protocol: 'ws',
        host,
        port: 9429,
      }
      : undefined,
    watch: {
      // 3. tell vite to ignore watching `src-tauri`
      ignored: ['**/src-tauri/**'],
    },
  },
  build: {
    rollupOptions: {
      output: {
        manualChunks: (id: string) => {
          // Vite 7.x 优化的 chunk 分割策略
          // 核心Vue相关库
          if (id.includes('vue') && !id.includes('node_modules')) {
            return 'vue-core';
          }
          // 第三方库分组
          if (id.includes('node_modules')) {
            // Vue 生态系统
            if (id.includes('vue') || id.includes('vue-router') || id.includes('pinia')) {
              return 'vue-vendor';
            }
            // UI 组件库
            if (id.includes('lucide-vue-next') || id.includes('@vueuse/core')) {
              return 'ui-vendor';
            }
            // 国际化
            if (id.includes('vue-i18n') || id.includes('@intlify')) {
              return 'i18n-vendor';
            }
            // 工具库
            if (id.includes('date-fns') || id.includes('es-toolkit') || id.includes('lru-cache')) {
              return 'utils-vendor';
            }
            // 表单验证
            if (id.includes('vee-validate') || id.includes('zod')) {
              return 'form-vendor';
            }
            // Tauri
            if (id.includes('@tauri-apps')) {
              return 'tauri-vendor';
            }
            // 图表库
            if (id.includes('echarts') || id.includes('vue-echarts')) {
              return 'chart-vendor';
            }
            // Toast 通知
            if (id.includes('vue-toastification')) {
              return 'toast-vendor';
            }
            // 其他第三方库
            return 'vendor';
          }

          // 应用代码分组
          // 注意: 不对 stores 和 features 进行独立打包，避免循环依赖导致的初始化错误
          if (id.includes('/src/')) {
            if (id.includes('/src/utils/')) {
              return 'utils';
            }
          }
        },
      },
    },
    // 增加chunk大小警告限制到1.5MB
    chunkSizeWarningLimit: 1500,
    // 启用代码分割
    target: 'esnext',
    minify: 'esbuild',
    // 启用CSS代码分割
    cssCodeSplit: true,
  },
  // 优化依赖预构建 - Vite 7.x 优化
  optimizeDeps: {
    include: [
      'vue',
      'vue-router',
      'pinia',
      '@vueuse/core',
      'lucide-vue-next',
      'vue-i18n',
      'date-fns',
      'es-toolkit',
      'vee-validate',
      'zod',
      '@tauri-apps/api',
    ],
    exclude: ['@tauri-apps/api'],
    // Vite 7.x 新增：强制预构建
    force: false,
  },
});
