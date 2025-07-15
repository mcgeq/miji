import { z } from 'zod';
import {
  CategorySchema,
  DateSchema,
  DateTimeSchema,
  DescriptionSchema,
  NameSchema,
  RepeatPeriodSchema,
  SerialNumSchema,
} from '../common';

export const BudgetSchema = z.object({
  serialNum: SerialNumSchema,
  description: DescriptionSchema,
  accountSerialNum: SerialNumSchema,
  name: NameSchema,
  Category: CategorySchema,
  amount: z.string(),
  repeatPeriod: RepeatPeriodSchema,
  startDate: DateSchema,
  endDate: DateSchema,
  usedAmount: z.string(),
  isActive: z.boolean(),
  color: z.string().optional().nullable(),
  createdAt: DateTimeSchema,
  updatedAt: DateTimeSchema.optional().nullable(),
});

export type Budget = z.infer<typeof BudgetSchema>;
