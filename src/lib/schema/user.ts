import { z } from 'zod/v4';

const UserRoleSchema = z.enum([
  'Admin',
  'User',
  'Moderator',
  'Editor',
  'Guest',
  'Developer',
  'Owner',
]);

const UserStatusSchema = z.enum([
  'Active',
  'Inactive',
  'Suspended',
  'Banned',
  'Pending',
  'Deleted',
]);

const passwordRegex =
  /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$/;

const alphanumericRegex = /^[a-z0-9]+$/;

export const UserSchema = z.object({
  serial_num: z
    .string()
    .length(38, { error: 'Serial number must be 38 character.' })
    .regex(alphanumericRegex, {
      error: 'Serial number must contain only letters and numbers',
    }),
  name: z.string().min(3).max(20),
  email: z.email(),
  phone: z.string().length(11).optional().nullable(),
  password: z.string().regex(passwordRegex, {
    error:
      'Password mut be at least 8 characters and include uppercase, lowercase, number, and special character.',
  }),
  avatar_url: z.string().optional().nullable(),
  last_login_at: z.iso.datetime({ offset: true, local: true, precision: 6 }),
  is_verified: z.boolean(),
  role: UserRoleSchema,
  status: UserStatusSchema,
  email_verified_at: z.iso
    .datetime({ offset: true, local: true, precision: 6 })
    .optional()
    .nullable(),
  phone_verified_at: z.iso
    .datetime({ offset: true, local: true, precision: 6 })
    .optional()
    .nullable(),
  bio: z.string().optional().nullable(),
  language: z.string().optional().nullable(),
  timezone: z.string().optional().nullable(),
  last_active_at: z.iso
    .datetime({ offset: true, local: true, precision: 6 })
    .optional()
    .nullable(),
  deleted_at: z.string().optional().nullable(),
  created_at: z.iso.datetime({ offset: true, local: true, precision: 6 }),
  updated_at: z.iso
    .datetime({ offset: true, local: true, precision: 6 })
    .optional()
    .nullable(),
});

export type User = z.infer<typeof UserSchema>;
export type UserRole = z.infer<typeof UserRoleSchema>;
export type UserStatus = z.infer<typeof UserStatusSchema>;
