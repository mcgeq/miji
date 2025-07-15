import { z } from 'zod';
import {
  CategorySchema,
  CurrencySchema,
  DateTimeSchema,
  DescriptionSchema,
  NameSchema,
  PrioritySchema,
  ReminderTypeSchema,
  RepeatPeriodSchema,
  SerialNumSchema,
} from '../common';

export const BilReminderSchema = z.object({
  serialNum: SerialNumSchema,
  name: NameSchema,
  enabled: z.boolean(),
  type: ReminderTypeSchema,
  description: DescriptionSchema,
  category: CategorySchema,
  amount: z.string(),
  currency: CurrencySchema,
  dueDate: DateTimeSchema,
  billDate: DateTimeSchema,
  remindDate: DateTimeSchema,
  repeatPeriod: RepeatPeriodSchema,
  isPaid: z.boolean(),
  priority: PrioritySchema,
  advanceValue: z.number().optional(),
  advanceUnit: z.string().optional(),
  color: z.string(),
  relatedTransactionSerialNum: SerialNumSchema,
  createdAt: DateTimeSchema,
  updatedAt: DateTimeSchema.optional().nullable(),
});

export type BilReminder = z.infer<typeof BilReminderSchema>;
