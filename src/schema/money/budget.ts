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
import { AccountSchema } from './account';

export const BudgetSchema = z.object({
  serialNum: SerialNumSchema,
  description: DescriptionSchema,
  accountSerialNum: SerialNumSchema,
  name: NameSchema,
  category: CategorySchema,
  amount: z.number(),
  currency: CurrencySchema,
  repeatPeriod: RepeatPeriodSchema,
  startDate: DateSchema,
  endDate: DateSchema,
  usedAmount: z.number(),
  isActive: z.boolean(),
  alertEnabled: z.boolean(),
  alertThreshold: z.string().optional(),
  color: z.string(),
  account: AccountSchema,
  createdAt: DateTimeSchema,
  updatedAt: DateTimeSchema.optional().nullable(),
});

export const BudgetCreateSchema = BudgetSchema.pick({
  description: true,
  accountSerialNum: true,
  name: true,
  category: true,
  amount: true,
  repeatPeriod: true,
  startDate: true,
  endDate: true,
  usedAmount: true,
  isActive: true,
  alertEnabled: true,
  alertThreshold: true,
  color: true,
})
  .extend({
    currency: z.string().length(3),
  })
  .strict();

export const BudgetUpdateSchema = BudgetCreateSchema.partial();

export type Budget = z.infer<typeof BudgetSchema>;
export type BudgetCreate = z.infer<typeof BudgetCreateSchema>;
export type BudgetUpdate = z.infer<typeof BudgetUpdateSchema>;
