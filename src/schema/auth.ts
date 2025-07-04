// src/lib/schema/auth.ts
import { z } from 'zod';
import { passwordRegex } from './common';

export const RegisterSchema = z.object({
  username: z.string().trim().min(3),
  email: z.string().trim().email(),
  password: z.string().trim().regex(passwordRegex).min(6),
  code: z.string().trim().optional().default(''),
});

export const LoginSchema = z.object({
  email: z.string().trim().email(),
  password: z.string().trim().nonempty(),
});
