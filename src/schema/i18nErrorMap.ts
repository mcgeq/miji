// src/schema/i18nErrorMap.ts
import type { z } from 'zod';
import { $t } from '../i18n/utils';

function handleTooSmall(issue: z.core.$ZodRawIssue<z.core.$ZodIssue>): { message: string } {
  if ('minimum' in issue) {
    return { message: $t('validation.min', { min: issue.minimum }) };
  }
  return { message: $t('validation.required') };
}

function handleTooBig(issue: z.core.$ZodRawIssue<z.core.$ZodIssue>): { message: string } {
  if ('maximum' in issue) {
    return { message: $t('validation.max', { max: issue.maximum }) };
  }
  return { message: $t('validation.invalid') };
}

function handleInvalidFormat(issue: z.core.$ZodRawIssue<z.core.$ZodIssue>): { message: string } {
  if ('format' in issue) {
    if (issue.format === 'email') {
      return { message: $t('validation.email') };
    }
    if (issue.format === 'regex') {
      return { message: $t('validation.password') };
    }
  }
  return { message: issue.message ?? $t('validation.invalid') };
}

// Define the error map with explicit types
export const i18nErrorMap: z.core.$ZodErrorMap = (
  issue: z.core.$ZodRawIssue<z.core.$ZodIssue>,
): { message: string } => {
  switch (issue.code) {
    case 'invalid_type':
      return { message: $t('validation.required') };
    case 'too_small':
      return handleTooSmall(issue);
    case 'too_big':
      return handleTooBig(issue);
    case 'invalid_format':
      return handleInvalidFormat(issue);
    case 'custom':
      return { message: issue.message ?? $t('validation.required') };
    default:
      return { message: issue.message ?? $t('validation.invalid') };
  }
};
