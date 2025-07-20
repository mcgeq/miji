// eslint.config.mjs
import antfu from '@antfu/eslint-config';

export default antfu({
  // 代码风格配置
  stylistic: {
    indent: 2,
    quotes: 'single',
    semi: false,  // antfu 默认不使用分号
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
}, {
  // 简化的规则配置，避免正则表达式问题
  rules: {
    // 使用默认的 perfectionist 配置，但调整一些参数
    'perfectionist/sort-imports': [
      'error',
      {
        'type': 'natural',
        'order': 'asc',
        'ignoreCase': true,
        'newlinesBetween': 'never',  // 不在组之间添加空行
        'groups': [
          'builtin',
          'external',
          'internal',
          'parent',
          'sibling',
          'index',
          'object',
          'type'
        ]
      }
    ],

    // 确保类型导入语法正确
    '@typescript-eslint/consistent-type-imports': [
      'error',
      {
        'prefer': 'type-imports',
        'disallowTypeAnnotations': false,
        'fixStyle': 'separate-type-imports'
      }
    ],

    // 确保导入语句中的命名导入也排序
    'perfectionist/sort-named-imports': [
      'error',
      {
        'type': 'natural',
        'order': 'asc',
        'ignoreCase': true
      }
    ]
  }
});
