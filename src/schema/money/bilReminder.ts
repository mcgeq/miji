import { z } from 'zod/v4';
import {
  DateTimeSchema,
  NameSchema,
  RepeatPeriodSchema,
  SerialNumSchema,
} from '../common';

export const BilReminderSchema = z.object({
  serialNum: SerialNumSchema,
  name: NameSchema,
  amount: z.string(),
  dueDate: DateTimeSchema,
  repeatPeriod: RepeatPeriodSchema,
  isPaid: z.boolean(),
  relatedTransactionSerialNum: SerialNumSchema,
  createdAt: DateTimeSchema,
  updatedAt: DateTimeSchema.optional().nullable(),
});

export type BilReminder = z.infer<typeof BilReminderSchema>;
