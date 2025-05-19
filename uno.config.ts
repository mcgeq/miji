import {
  defineConfig,
  presetAttributify,
  presetIcons,
  presetWebFonts,
  presetTypography,
  presetWind3,
  transformerDirectives,
  transformerVariantGroup,
} from 'unocss';
export default defineConfig({
  // ...UnoCSS options
  presets: [
    presetWind3(),
    presetAttributify(),
    presetIcons({
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
  transformers: [transformerDirectives(), transformerVariantGroup()],
});
