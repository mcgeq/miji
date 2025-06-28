// src/schema/i18nErrorMap.ts
import type { ZodErrorMap } from 'zod';
import { $t } from '../i18n/utils';

export const i18nErrorMap: ZodErrorMap = (issue, ctx) => {
  switch (issue.code) {
    case 'invalid_type':
      return { message: $t('errors.required') };
    case 'too_small':
      // 修复：使用 issue.min 而不是 issue.minimum
      if ('minimum' in issue && issue.type === 'string') {
        return { message: $t('errors.min', { min: issue.minimum }) };
      }
      return { message: $t('errors.required') };
    case 'too_big':
      // 修复：使用 issue.max 而不是 issue.maximum
      if ('maximum' in issue && issue.type === 'string') {
        return { message: $t('errors.max', { max: issue.maximum }) };
      }
      return { message: ctx.defaultError };
    case 'invalid_string':
      if (issue.validation === 'email') {
        return { message: $t('errors.email') };
      }
      if (issue.validation === 'regex') {
        return { message: $t('errors.password') };
      }
      return { message: ctx.defaultError };

    case 'custom':
      return { message: issue.message ?? $t('errors.required') };
    default:
      return { message: ctx.defaultError };
  }
};
