import { z } from 'zod';
import {
  CategorySchema,
  CurrencySchema,
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
  category: CategorySchema,
  amount: z.string(),
  currency: CurrencySchema,
  repeatPeriod: RepeatPeriodSchema,
  startDate: DateSchema,
  endDate: DateSchema,
  usedAmount: z.string(),
  isActive: z.boolean(),
  alertEnabled: z.boolean(),
  alertThreshold: z.string().optional(),
  color: z.string(),
  createdAt: DateTimeSchema,
  updatedAt: DateTimeSchema.optional().nullable(),
});

export type Budget = z.infer<typeof BudgetSchema>;
