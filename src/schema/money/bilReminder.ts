import { z } from 'zod';
import {
  CategorySchema,
  CurrencySchema,
  DateTimeSchema,
  DescriptionSchema,
  NameSchema,
  RepeatPeriodSchema,
  SerialNumSchema,
} from '../common';

export const BilReminderSchema = z.object({
  serialNum: SerialNumSchema,
  name: NameSchema,
  description: DescriptionSchema,
  category: CategorySchema,
  amount: z.string(),
  currency: CurrencySchema,
  dueDate: DateTimeSchema,
  billDate: DateTimeSchema,
  remindDate: DateTimeSchema,
  repeatPeriod: RepeatPeriodSchema,
  isPaid: z.boolean(),
  color: z.string().optional().nullable(),
  relatedTransactionSerialNum: SerialNumSchema,
  createdAt: DateTimeSchema,
  updatedAt: DateTimeSchema.optional().nullable(),
});

export type BilReminder = z.infer<typeof BilReminderSchema>;
