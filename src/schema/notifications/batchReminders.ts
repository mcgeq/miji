import { z } from 'zod';
import { DateTimeSchema, SerialNumSchema } from '../common';

export const BatchReminderSchema = z.object({
  serialNum: SerialNumSchema,
  name: z.string(),
  description: z.string().optional().nullable(),
  scheduledAt: DateTimeSchema,
  status: z.string(),
  totalCount: z.number(),
  sentCount: z.number(),
  failedCount: z.number(),
  createdAt: DateTimeSchema,
  updatedAt: DateTimeSchema.optional().nullable(),
});

export const BatchReminderCreateSchema = BatchReminderSchema.omit({
  serialNum: true,
  createdAt: true,
  updatedAt: true,
});

export const BatchReminderUpdateSchema = BatchReminderCreateSchema.partial();

export type BatchReminder = z.infer<typeof BatchReminderSchema>;
export type BatchReminderCreate = z.infer<typeof BatchReminderCreateSchema>;
export type BatchReminderUpdate = z.infer<typeof BatchReminderUpdateSchema>;
