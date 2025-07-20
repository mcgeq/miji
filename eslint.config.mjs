// eslint.config.mjs
import antfu from '@antfu/eslint-config';

export default antfu({
  // 代码风格配置
  stylistic: {
    indent: 2,
    quotes: 'single',
    semi: true,
    commaDangle: 'always-multiline',
    braceStyle: '1tbs',
    maxLen: 100,
  },

  // 框架支持
  typescript: true,
  vue: true,
  svelte: true,
  astro: true,
  unocss: true,

  // 文件类型支持
  jsonc: false,
  yaml: true,
  toml: true,
  xml: false,

},
);
