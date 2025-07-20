// eslint.config.mjs
import antfu from '@antfu/eslint-config'

export default antfu({
  stylistic: {
    indent: 2,
    quotes: 'single',
  },

  // TypeScript and Vue are autodetected, you can also explicitly enable them:
  typescript: true,
  vue: true,
  svelte: true,
  astro: true,
  unocss: true,

  // Disable jsonc and yaml support
  jsonc: false,
  yaml: true,
})
