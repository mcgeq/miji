import { resolve } from 'node:path';
import { env } from 'node:process';
import VueI18n from '@intlify/unplugin-vue-i18n/vite';
import Vue from '@vitejs/plugin-vue';
import UnoCSS from 'unocss/vite';
import AutoImport from 'unplugin-auto-import/vite';
import Components from 'unplugin-vue-components/vite';
import { VueRouterAutoImports } from 'unplugin-vue-router';
import VueRouter from 'unplugin-vue-router/vite';
import { defineConfig } from 'vite';
import vueDevTools from 'vite-plugin-vue-devtools';

const host = env.TAURI_DEV_HOST;
function LucideResolver(componentName: string) {
  if (componentName.startsWith('Lucide')) {
    return {
      name: componentName.slice(6), // e.g. LucideHome -> Home
      from: 'lucide-vue-next',
    };
  }
  return null;
};

// https://vitejs.dev/config/
export default defineConfig(async () => ({
  plugins: [
    UnoCSS({
      mode: 'global',
      instanceof: env.NODE_ENV === 'development',
    }),
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
    // 确保CSS正确处理
    preprocessorOptions: {
      scss: {
        charset: false,
      },
      css: {
        charset: false,
      },
    },
  },
  build: {
    cssCodeSplit: false,
    rollupOptions: {
      output: {
        assetFileNames: assertInfo => {
          if (assertInfo.name && assertInfo.name.endsWith('css')) {
            return 'assets/style.[hash].css';
          }
          return 'assets/[name].[hash].[ext]';
        },
        // 确保chunk命名一致
        chunkFileNames: 'assets/[name].[hash].js',
        entryFileNames: 'assets/[name].[hash].js',
        // 手动控制chunk分割
        manualChunks: undefined,
      },
      // 外部依赖处理
      external: id => {
        // 确保所有CSS都被正确包含
        if (id.includes('.css') || id.includes('uno.css')) {
          return false;
        }
        return false;
      },
    },
  },
  // 优化依赖处理
  optimizeDeps: {
    include: [
      'vue',
      'vue-router',
      'pinia',
      'vue-i18n',
      '@vueuse/core',
      'vue-toastification',
    ],
    exclude: [
      // 排除可能导致问题的依赖
    ],
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
  test: {
    include: ['test/**/*.test.ts'],
    environment: 'jsdom',
  },
}));
