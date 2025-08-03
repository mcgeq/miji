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
});

export type Reminder = z.infer<typeof ReminderSchema>;
