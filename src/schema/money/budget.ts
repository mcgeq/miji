import { z } from 'zod/v4';
import {
  CategorySchema,
  DateSchema,
  DateTimeSchema,
  NameSchema,
  RepeatPeriodSchema,
  SerialNumSchema,
} from '../common';

export const BudgetSchema = z.object({
  serialNum: SerialNumSchema,
  accountSerialNum: SerialNumSchema,
  name: NameSchema,
  Category: CategorySchema,
  amount: z.string(),
  repeatPeriod: RepeatPeriodSchema,
  startDate: DateSchema,
  endDate: DateSchema,
  usedAmount: z.string(),
  isActive: z.boolean(),
  createdAt: DateTimeSchema,
  updatedAt: DateTimeSchema.optional().nullable(),
});

export type Budget = z.infer<typeof BudgetSchema>;
