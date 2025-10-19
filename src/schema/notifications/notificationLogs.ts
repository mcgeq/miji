import { z } from 'zod';
import { DateTimeSchema, SerialNumSchema } from '../common';

export const NotificationLogSchema = z.object({
  serialNum: SerialNumSchema,
  reminderSerialNum: SerialNumSchema,
  notificationType: z.string(),
  status: z.string(),
  sentAt: DateTimeSchema.optional().nullable(),
  errorMessage: z.string().optional().nullable(),
  retryCount: z.number(),
  lastRetryAt: DateTimeSchema.optional().nullable(),
  createdAt: DateTimeSchema,
  updatedAt: DateTimeSchema.optional().nullable(),
});

export const NotificationLogCreateSchema = NotificationLogSchema.omit({
  serialNum: true,
  createdAt: true,
  updatedAt: true,
});

export const NotificationLogUpdateSchema = NotificationLogCreateSchema.partial();

export type NotificationLog = z.infer<typeof NotificationLogSchema>;
export type NotificationLogCreate = z.infer<typeof NotificationLogCreateSchema>;
export type NotificationLogUpdate = z.infer<typeof NotificationLogUpdateSchema>;
