import { z } from 'zod';
import { DateTimeSchema, ReminderTypeSchema, SerialNumSchema } from '../common';

export const ReminderSchema = z.object({
  serialNum: SerialNumSchema,
  todoSerialNum: SerialNumSchema,
  remindAt: DateTimeSchema,
  type: ReminderTypeSchema.optional().nullable(),
  isSent: z.boolean(),
  createdAt: DateTimeSchema,
  updatedAt: DateTimeSchema.optional().nullable(),
  // 新增提醒执行相关字段
  reminderMethod: z.string().optional().nullable(),
  retryCount: z.number(),
  lastRetryAt: DateTimeSchema.optional().nullable(),
  snoozeCount: z.number(),
  escalationLevel: z.number(),
  notificationId: z.string().optional().nullable(),
});

export const ReminderCreateSchema = ReminderSchema.omit({
  serialNum: true,
  createdAt: true,
  updatedAt: true,
});

export const ReminderUpdateSchema = ReminderCreateSchema.partial();

export type Reminder = z.infer<typeof ReminderSchema>;
export type ReminderCreate = z.infer<typeof ReminderCreateSchema>;
export type ReminderUpdate = z.infer<typeof ReminderUpdateSchema>;
