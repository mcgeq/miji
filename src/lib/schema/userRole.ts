import { z } from 'zod/v4';

export const UserRoleSchema = z.enum([
  'Admin',
  'User',
  'Moderator',
  'Editor',
  'Guest',
  'Developer',
  'Owner',
]);

export type UserRole = z.infer<typeof UserRoleSchema>;
