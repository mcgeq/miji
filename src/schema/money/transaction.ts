import { z } from 'zod';
import {
  CategorySchema,
  CurrencySchema,
  DateSchema,
  DateTimeSchema,
  SerialNumSchema,
  SubCategorySchema,
  TransactionStatusSchema,
  TransactionTypeSchema,
} from '../common';
import { TagsSchema } from '../tags';
import { AccountSchema } from './account';
import { FamilyMemberSchema } from './family';
import { AccountTypeSchema, PaymentMethodSchema } from './money.e';

export const TransactionSchema = z.object({
  serialNum: SerialNumSchema,
  transactionType: TransactionTypeSchema,
  transactionStatus: TransactionStatusSchema,
  date: DateSchema, // ISO date string (e.g., "2025-06-12")
  amount: z.number(), // decimal as string, e.g., "1234.56"
  currency: CurrencySchema,
  description: z.string().max(1000).optional(),
  notes: z.string().optional().nullable(),
  accountSerialNum: SerialNumSchema,
  category: CategorySchema,
  subCategory: SubCategorySchema.optional().nullable(),
  tags: z.array(TagsSchema), // JSON value, recommend defining more strictly if needed
  splitMembers: z.array(FamilyMemberSchema).optional(), // JSON value, can be array of { member: string, amount: string } etc.
  paymentMethod: PaymentMethodSchema,
  actualPayerAccount: AccountTypeSchema,
  relatedTransactionSerialNum: SerialNumSchema.optional(),
  idDeleted: z.boolean().default(false),
  createdAt: DateTimeSchema,
  updatedAt: DateTimeSchema.optional().nullable(),
});

export const TransactionWithAccountSchema = TransactionSchema.extend({
  account: AccountSchema,
});

export type Transaction = z.infer<typeof TransactionSchema>;
export type TransactionWithAccount = z.infer<
  typeof TransactionWithAccountSchema
>;
