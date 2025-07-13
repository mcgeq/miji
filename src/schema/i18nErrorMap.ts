// src/schema/i18nErrorMap.ts
import type { z } from 'zod';
import { $t } from '../i18n/utils';

// Define the error map with explicit types
export const i18nErrorMap: z.core.$ZodErrorMap = (
  issue: z.core.$ZodRawIssue<z.core.$ZodIssue>,
): { message: string } => {
  switch (issue.code) {
    case 'invalid_type':
      return { message: $t('errors.required') };
    case 'too_small':
      if ('minimum' in issue) {
        return { message: $t('errors.min', { min: issue.minimum }) };
      }
      return { message: $t('errors.required') };
    case 'too_big':
      if ('maximum' in issue) {
        return { message: $t('errors.max', { max: issue.maximum }) };
      }
      return { message: $t('errors.invalid') };
    case 'invalid_format':
      if ('format' in issue) {
        if (issue.format === 'email') {
          return { message: $t('errors.email') };
        }
        if (issue.format === 'regex') {
          return { message: $t('errors.password') };
        }
      }
      return { message: issue.message ?? $t('errors.invalid') };
    case 'custom':
      return { message: issue.message ?? $t('errors.required') };
    default:
      return { message: issue.message ?? $t('errors.invalid') };
  }
};
