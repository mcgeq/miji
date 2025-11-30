import { z } from 'zod';

export const UserStatusSchema = z.enum([
  'Active',
  'Inactive',
  'Suspended',
  'Banned',
  'Pending',
  'Deleted',
]);

export type UserStatus = z.infer<typeof UserStatusSchema>;
