// postcss.config.mjs
import postcssImport from 'postcss-import';
import postcssPresetEnv from 'postcss-preset-env';
import postcssNested from 'postcss-nested';
import autoprefixer from 'autoprefixer';
import cssnano from 'cssnano';

const isProduction = process.env.NODE_ENV === 'production';

export default {
  plugins: [
    postcssImport(),
    postcssPresetEnv({
      stage: 1,
      features: {
        'custom-properties': true,
        'relative-color-syntax': true, // 启用相对颜色语法支持
        'oklab-function': true, // 启用 oklch 函数支持
      },
    }),
    postcssNested(),
    autoprefixer({
      overrideBrowserslist: ['last 2 versions', 'not dead', '> 1%'],
    }),
    ...(isProduction
      ? [cssnano({ preset: 'default' })]
      : []),
    ],
};
