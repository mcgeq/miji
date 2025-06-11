// src/lib/schema/auth.ts
import { z } from 'zod';

export const RegisterSchema = z.object({
  username: z.string().nonempty('请输入用户名').min(3, '用户名至少3位'),
  email: z.string().nonempty('请输入邮箱').email('邮箱格式不正确'),
  password: z.string().nonempty('请输入密码').min(6, '密码至少 6 位'),
  code: z.string(),
});

export const LoginSchema = z.object({
  email: z.string().nonempty('请输入邮箱').email('邮箱格式不正确'),
  password: z.string().nonempty('请输入密码'),
});
