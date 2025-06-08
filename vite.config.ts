import UnoCSS from '@unocss/svelte-scoped/vite';
import { resolve } from 'node:path';
import { defineConfig } from 'vite';
import { sveltekit } from '@sveltejs/kit/vite';
import transformerDirectives from '@unocss/transformer-directives';
import transformerVariantGroup from '@unocss/transformer-variant-group';
import { getAllConfigFiles } from './getAllConfigFiles';

const host = process.env.TAURI_DEV_HOST;

// https://vitejs.dev/config/
export default defineConfig(async () => ({
  plugins: [
    UnoCSS({
      injectReset: '@unocss/reset/tailwind.css',
      cssFileTransformers: [transformerDirectives(), transformerVariantGroup()],
      configOrPath: {
        configDeps: getAllConfigFiles('./src/shortcuts'),
      },
    }),
    sveltekit(),
  ],
  resolve: {
    alias: {
      '@': resolve(__dirname, 'src'),
    },
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
}));
