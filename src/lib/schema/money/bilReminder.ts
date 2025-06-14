import { z } from 'zod/v4';
import {
  DateTimeSchema,
  NameSchema,
  RepeatPeriodSchema,
  SerialNumSchema,
} from '../common';

export const BilReminderSchema = z.object({
  serial_num: SerialNumSchema,
  name: NameSchema,
  amount: z.string(),
  due_date: DateTimeSchema,
  repeat_period: RepeatPeriodSchema,
  is_paid: z.boolean(),
  related_transaction_serial_num: SerialNumSchema,
  created_at: DateTimeSchema,
  updated_at: DateTimeSchema.optional().nullable(),
});

export type BilReminder = z.infer<typeof BilReminderSchema>;
