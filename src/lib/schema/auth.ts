// src/lib/schema/auth.ts
import { z } from 'zod';

export const RegisterSchema = z.object({
  username: z.string().min(1, '请输入名称'),
  email: z.string().email('邮箱格式不正确'),
  password: z.string().min(6, '密码至少 6 位'),
  code: z.string(),
});

export const LoginSchema = z.object({
  email: z.string().email('邮箱格式不正确'),
  password: z.string().min(6, '密码至少 6 位'),
});
