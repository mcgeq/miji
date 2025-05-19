import {
  defineConfig,
  presetAttributify,
  presetIcons,
  presetWebFonts,
} from 'unocss';
export default defineConfig({
  // ...UnoCSS options
  presets: [
    presetAttributify(),
    presetIcons({
      scale: 1.2,
      warn: true,
    }),
    presetWebFonts({
      fonts: {
        sans: 'DM Sans',
        serif: 'Dm Serif Display',
        mono: 'Dm Mono',
      },
    }),
  ],
});
