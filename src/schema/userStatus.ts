import { z } from 'zod/v4';

export const UserStatusSchema = z.enum([
  'Active',
  'Inactive',
  'Suspended',
  'Banned',
  'Pending',
  'Deleted',
]);

export type UserStatus = z.infer<typeof UserStatusSchema>;
