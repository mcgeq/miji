import { z } from 'zod/v4';
import { UserRoleSchema } from './userRole';
import { UserStatusSchema } from './userStatus';
import {
  DateTimeSchema,
  NameSchema,
  passwordRegex,
  SerialNumSchema,
} from './common';

export const UserSchema = z.object({
  serial_num: SerialNumSchema,
  name: NameSchema,
  email: z.email(),
  phone: z.string().length(11).optional().nullable(),
  password: z.string().regex(passwordRegex, {
    error:
      'Password mut be at least 8 characters and include uppercase, lowercase, number, and special character.',
  }),
  avatar_url: z.string().optional().nullable(),
  last_login_at: DateTimeSchema,
  is_verified: z.boolean(),
  role: UserRoleSchema,
  status: UserStatusSchema,
  email_verified_at: DateTimeSchema.optional().nullable(),
  phone_verified_at: DateTimeSchema.optional().nullable(),
  bio: z.string().optional().nullable(),
  language: z.string().optional().nullable(),
  timezone: z.string().optional().nullable(),
  last_active_at: DateTimeSchema.optional().nullable(),
  deleted_at: DateTimeSchema.optional().nullable(),
  created_at: DateTimeSchema,
  updated_at: DateTimeSchema.optional().nullable(),
});

export type User = z.infer<typeof UserSchema>;
