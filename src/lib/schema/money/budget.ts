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
  serial_num: SerialNumSchema,
  account_serial_num: SerialNumSchema,
  name: NameSchema,
  Category: CategorySchema,
  amount: z.string(),
  repeat_period: RepeatPeriodSchema,
  start_date: DateSchema,
  end_date: DateSchema,
  used_amount: z.string(),
  is_active: z.boolean(),
  created_at: DateTimeSchema,
  updated_at: DateTimeSchema.optional().nullable(),
});

export type Budget = z.infer<typeof BudgetSchema>;
