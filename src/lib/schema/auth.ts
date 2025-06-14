// src/lib/schema/auth.ts
import { z, setErrorMap } from 'zod';
import { i18nErrorMap } from './i18nErrorMap';
import { passwordRegex } from './common';
setErrorMap(i18nErrorMap);

export const RegisterSchema = z.object({
  username: z.string().trim().min(3),
  email: z.string().trim().email(),
  password: z.string().trim().regex(passwordRegex).min(6),
  code: z.string().trim().optional(),
});

export const LoginSchema = z.object({
  email: z.string().trim().email(),
  password: z.string().trim().nonempty(),
});
