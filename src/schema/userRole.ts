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

export const MemberUserRoleSchema = z.enum([
  'Owner',
  'Admin',
  'Member',
  'Viewer',
]);

export type UserRole = z.infer<typeof UserRoleSchema>;
export type MemberUserRole = z.infer<typeof MemberUserRoleSchema>;
