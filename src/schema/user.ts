import { z } from 'zod';
import { DateTimeSchema, NameSchema, SerialNumSchema } from './common';
import { UserRoleSchema } from './userRole';
import { UserStatusSchema } from './userStatus';

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

export const CreateUserRequestSchema = UserSchema.pick({
  name: true,
  email: true,
  phone: true,
  password: true,
  avatarUrl: true,
  isVerified: true,
  role: true,
  status: true,
  bio: true,
  language: true,
  timezone: true,
});

export const UpdateUserRequestSchema = UserSchema.pick({
  serialNum: true,
  name: true,
  email: true,
  phone: true,
  password: true,
  avatarUrl: true,
  isVerified: true,
  role: true,
  status: true,
  bio: true,
  language: true,
  timezone: true,
  lastLoginAt: true,
  lastActiveAt: true,
}).partial();

export type User = z.infer<typeof UserSchema>;
export type CreateUserRequest = z.infer<typeof CreateUserRequestSchema>;
export type UpdateUserRequest = z.infer<typeof UpdateUserRequestSchema>;

export interface AuthUser {
  serialNum: string;
  name: string;
  email: string;
  avatarUrl: string | null;
  role: string;
  isVerified?: boolean;
  emailVerifiedAt?: string;
  timezone: string;
  language?: string;
}

export interface TokenResponse {
  token: string;
  expiresAt: number; // UNIX timestamp (秒)
}

export enum TokenStatus {
  Valid = 'Valid',
  Expired = 'Expired',
  Invalid = 'Invalid',
}

export interface UserQuery {
  serial_num?: string;
  email?: string;
  phone?: string;
  name?: string;
}
