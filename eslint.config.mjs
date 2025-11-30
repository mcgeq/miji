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
  unocss: false,
  // 文件类型支持
  jsonc: false,
  yaml: true,
  toml: true,
  xml: false,
}, {
  // 自定义规则
  rules: {
    'style/operator-linebreak': 'off', // 禁用操作符换行校验
    'antfu/if-newline': 'off', // 禁用 if 语句换行校验
    'style/brace-style': ['error', '1tbs'],
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
    ],
    // 或者使用更灵活的配置
    'style/arrow-parens': ['error', 'as-needed', {
      'requireForBlockBody': false
    }],
    'style/object-curly-spacing': ['error', 'always'],
    'style/quotes': ['error', 'single', {
      'avoidEscape': true,
      'allowTemplateLiterals': 'never'
    }]
  }
}, {
  files: ['src/utils/debugLog.ts'],
  rules: {
      'no-console': 'off'
    // 允许 debugLog.ts 中使用指定的 console 方法
    // "no-console": ["error", {
    //   "allow": ['info', 'debug', "warn", "error", "log", "group", "groupCollapsed", "table", "trace", 'groupEnd']
    // }]
  }
}, {
  // Markdown 文件配置 - 禁用需要类型信息的 TypeScript 规则
  files: ['**/*.md'],
  rules: {
    '@typescript-eslint/consistent-type-imports': 'off',
    'ts/consistent-type-imports': 'off',
  }
});
