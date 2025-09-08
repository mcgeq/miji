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
  amount: z.number(),
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

export const BilReminderCreateSchema = BilReminderSchema.pick({
  name: true,
  enabled: true,
  type: true,
  description: true,
  category: true,
  amount: true,
  dueDate: true,
  billDate: true,
  remindDate: true,
  repeatPeriod: true,
  isPaid: true,
  priority: true,
  advanceValue: true,
  advanceUnit: true,
  color: true,
  relatedTransactionSerialNum: true,
}).extend({
  currency: z.string().length(3),

}).strict();

export const BilReminderUpdateSchema = BilReminderCreateSchema.partial();
export const BilReminderFiltersSchema = BilReminderSchema.omit({
  serialNum: true,
  amount: true,
  createdAt: true,
  updatedAt: true,
}).partial();

export type BilReminder = z.infer<typeof BilReminderSchema>;
export type BilReminderCreate = z.infer<typeof BilReminderCreateSchema>;
export type BilReminderUpdate = z.infer<typeof BilReminderUpdateSchema>;
export type BilReminderFilters = z.infer<typeof BilReminderFiltersSchema>;
