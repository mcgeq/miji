// eslint.config.mjs
import antfu from '@antfu/eslint-config';

export default antfu({
  // 代码风格配置
  stylistic: false,  // 禁用 ESLint 的样式规则，让 Biome 处理

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
}, {
  // 只保留逻辑相关的规则，不处理格式
  rules: {
    // 禁用所有格式相关的规则
    'style/object-curly-spacing': 'off',
    'style/semi': 'off',
    'style/quotes': 'off',
    'style/comma-dangle': 'off',
    'style/brace-style': 'off',

    // 禁用 import 排序，让 Biome 处理
    'perfectionist/sort-imports': 'off',
    'perfectionist/sort-named-imports': 'off',
    'perfectionist/sort-exports': 'off',

    // 保留重要的 TypeScript 规则
    '@typescript-eslint/consistent-type-imports': [
      'error',
      {
        'prefer': 'type-imports',
        'disallowTypeAnnotations': false,
        'fixStyle': 'separate-type-imports'
      }
    ],

    // 保留重要的代码质量规则
    'no-console': ['warn', { allow: ['warn', 'error'] }],
    'no-debugger': 'error',
    'no-unused-vars': 'off', // 让 TypeScript 处理
    '@typescript-eslint/no-unused-vars': ['error', { argsIgnorePattern: '^_' }]
  }
});
