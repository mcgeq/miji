import {
  defineConfig,
  presetAttributify,
  presetIcons,
  presetWebFonts,
  presetTypography,
  presetWind3,
} from 'unocss';
export default defineConfig({
  // ...UnoCSS options
  presets: [
    presetWind3(),
    presetAttributify(),
    presetIcons({
      prefix: 'i-',
      extraProperties: {
        display: 'inline-block',
        'vertical-align': 'middle',
      },
      scale: 1.2,
      warn: true,
    }),
    presetTypography(),
    presetWebFonts({
      fonts: {
        sans: 'DM Sans',
        serif: 'Dm Serif Display',
        mono: 'Dm Mono',
      },
    }),
  ],
  safelist: ['bg-orange-300', 'prose', 'styled-input'],
});
