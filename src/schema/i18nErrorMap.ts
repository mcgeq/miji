import { $t } from '../i18n/utils';
// src/schema/i18nErrorMap.ts
import type { z } from 'zod';

// Define the error map with explicit types
export const i18nErrorMap: z.core.$ZodErrorMap = (
  issue: z.core.$ZodRawIssue<z.core.$ZodIssue>,
): { message: string } => {
  switch (issue.code) {
    case 'invalid_type':
      return { message: $t('validation.required') };
    case 'too_small':
      if ('minimum' in issue) {
        return { message: $t('validation.min', { min: issue.minimum }) };
      }
      return { message: $t('validation.required') };
    case 'too_big':
      if ('maximum' in issue) {
        return { message: $t('validation.max', { max: issue.maximum }) };
      }
      return { message: $t('validation.invalid') };
    case 'invalid_format':
      if ('format' in issue) {
        if (issue.format === 'email') {
          return { message: $t('validation.email') };
        }
        if (issue.format === 'regex') {
          return { message: $t('validation.password') };
        }
      }
      return { message: issue.message ?? $t('validation.invalid') };
    case 'custom':
      return { message: issue.message ?? $t('validation.required') };
    default:
      return { message: issue.message ?? $t('validation.invalid') };
  }
};
