import { z } from 'zod/v4';
import { UserRoleSchema } from './userRole';
import { UserStatusSchema } from './userStatus';
import { DateTimeSchema, NameSchema, SerialNumSchema } from './common';

export const UserSchema = z.object({
  serialNum: SerialNumSchema,
  name: NameSchema,
  email: z.email(),
  phone: z.string().length(11).optional().nullable(),
  password: z.string(),
  avatarUrl: z.string().optional().nullable(),
  lastLoginAt: DateTimeSchema,
  isVerified: z.boolean(),
  role: UserRoleSchema,
  status: UserStatusSchema,
  emailVerifiedAt: DateTimeSchema.optional().nullable(),
  phoneVerifiedAt: DateTimeSchema.optional().nullable(),
  bio: z.string().optional().nullable(),
  language: z.string().optional().nullable(),
  timezone: z.string().optional().nullable(),
  lastActiveAt: DateTimeSchema.optional().nullable(),
  deletedAt: DateTimeSchema.optional().nullable(),
  createdAt: DateTimeSchema,
  updatedAt: DateTimeSchema.optional().nullable(),
});

export type User = z.infer<typeof UserSchema>;

export type AuthUser = {
  serialNum: string;
  name: string;
  email: string;
  avatarUrl: string | null;
  role: string;
  timezone: string;
  language?: string;
};

export interface TokenResponse {
  token: string;
  expiresAt: number; // UNIX timestamp (秒)
}

export enum TokenStatus {
  Valid = 'Valid',
  Expired = 'Expired',
  Invalid = 'Invalid',
}
