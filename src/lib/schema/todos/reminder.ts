import { z } from 'zod/v4';
import { DateTimeSchema, ReminderTypeSchema, SerialNumSchema } from '../common';
export const ReminderSchema = z.object({
  serial_num: SerialNumSchema,
  todo_serial_num: SerialNumSchema,
  remind_at: DateTimeSchema,
  type: ReminderTypeSchema.optional().nullable(),
  is_sent: z.boolean(),
  created_at: DateTimeSchema,
  updated_at: DateTimeSchema.optional().nullable(),
});

export type Reminder = z.infer<typeof ReminderSchema>;
