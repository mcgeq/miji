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
}, {
  // 自定义规则
  rules: {
    // 配置 perfectionist 的 import 排序，与 Biome 规则一致
    'perfectionist/sort-imports': [
      'error',
      {
        'type': 'natural',
        'order': 'asc',
        'ignoreCase': true,
        'newlinesBetween': 'never',
        'maxLineLength': undefined,
        'groups': [
          'builtin',
          'external',
          'internal',
          'parent',
          'sibling',
          'index',
          'object',
          'type'
        ],
        'customGroups': {
          'value': {
            'internal': '^@/'
          }
        },
        'internalPattern': ['^@/']
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
    ],

    // 关闭原生的 no-unused-vars 规则
    'no-unused-vars': 'off',
    '@typescript-eslint/no-unused-vars': 'off',

    // 使用 unused-imports 插件来处理未使用的导入和变量
    'unused-imports/no-unused-imports': 'error',
    'unused-imports/no-unused-vars': [
      'error',
      {
        'vars': 'all',
        'varsIgnorePattern': '^_',
        'args': 'after-used',
        'argsIgnorePattern': '^_',
        'caughtErrors': 'all',
        'caughtErrorsIgnorePattern': '^_',
        'destructuredArrayIgnorePattern': '^_',
        'ignoreRestSiblings': true
      }
    ]
  }
});
