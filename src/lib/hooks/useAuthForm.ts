// src/lib/hooks/useAuthForm.ts
import { createForm } from 'felte';
import { validator } from '@felte/validator-zod';
import { LoginSchema, RegisterSchema } from '$lib/schema/auth';
import { login, register } from '$lib/api/auth';
import type { ZodSchema } from 'zod';
import { goto } from '$app/navigation';
import { Lg } from '../utils/debugLog';

type AuthMode = 'login' | 'register';

export function useAuthForm(mode: AuthMode = 'login') {
  const schema: ZodSchema = mode === 'login' ? LoginSchema : RegisterSchema;

  const { form, data, errors, isSubmitting, reset } = createForm({
    extend: validator({ schema }),
    onSubmit: async (values) => {
      try {
        if (mode === 'login') {
          await login(values);
        } else {
          await register(values);
        }
        goto('/');
      } catch (err) {
        Lg.e('Auth error:', err);
      }
    },
  });

  return { form, data, errors, isSubmitting, reset };
}
