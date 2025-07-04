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
    ['flex-juster-center', 'flex justify-center items-center'],
    [
      'modal-btn-x',
      'mt-2 text-sm text-gray-500 hover:text-gray-700 dark:hover:text-gray-300 flex justify-center',
    ],
    [
      'modal-btn-icon',
      'w-full rounded-xl py-2 px-2 bg-blue-600 hover:bg-blue-700 flex justify-center',
    ],
    [
      'modal-mask',
      'fixed inset-0 bg-black/60 z-50 backdrop-blur-sm px-4 flex justify-center items-center',
    ],
    [
      'modal-mask-window',
      'bg-white/70 dark:bg-gray-900/80 p-6 rounded-2xl shadow-xl w-40 flex flex-col gap-4 border border-white/20 dark:border-gray-700/30',
    ],
    ['wh-5', 'w-5 h-5'],
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
});
