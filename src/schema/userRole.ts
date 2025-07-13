import { z } from 'zod';

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
