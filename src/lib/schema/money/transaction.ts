import { z } from 'zod/v4';
import {
  CategorySchema,
  DateSchema,
  DateTimeSchema,
  SerialNumSchema,
  SubCategorySchema,
  TransactionStatusSchema,
  TransactionTypeSchema,
} from '../common';
import { AccountTypeSchema, PaymentMethodSchema } from './money.e';
import { TagsSchema } from '../tags';
import { FamilyMemberSchema } from './family';

export const TransactionSchema = z.object({
  serial_num: SerialNumSchema,
  transaction_type: TransactionTypeSchema,
  transaction_status: TransactionStatusSchema,
  date: DateSchema, // ISO date string (e.g., "2025-06-12")
  amount: z.string(), // decimal as string, e.g., "1234.56"
  currency: z.string(), // currency code (e.g., "USD", "CNY")
  description: z.string().max(1000).optional(),
  notes: z.string().optional().nullable(),
  account_serial_num: SerialNumSchema,
  category: CategorySchema,
  sub_category: SubCategorySchema.optional().nullable(),
  tags: z.array(TagsSchema), // JSON value, recommend defining more strictly if needed
  split_members: z.array(FamilyMemberSchema).optional(), // JSON value, can be array of { member: string, amount: string } etc.
  payment_method: PaymentMethodSchema,
  actual_payer_account: AccountTypeSchema,
  created_at: DateTimeSchema,
  updated_at: DateTimeSchema.optional().nullable(),
});

export type Transaction = z.infer<typeof TransactionSchema>;
