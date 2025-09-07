import { z } from 'zod';
import {
  CategorySchema,
  CurrencySchema,
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
  date: DateTimeSchema,
  amount: z.number(),
  refundAmount: z.number().default(0.0),
  account: AccountSchema,
  currency: CurrencySchema,
  description: z.string().max(1000).optional(),
  notes: z.string().optional().nullable(),
  accountSerialNum: SerialNumSchema,
  toAccountSerialNum: SerialNumSchema.optional().nullable(),
  category: CategorySchema,
  subCategory: SubCategorySchema.optional().nullable(),
  tags: z.array(TagsSchema),
  splitMembers: z.array(FamilyMemberSchema).optional(),
  paymentMethod: PaymentMethodSchema,
  actualPayerAccount: AccountTypeSchema,
  relatedTransactionSerialNum: SerialNumSchema.optional(),
  isDeleted: z.boolean().default(false),
  createdAt: DateTimeSchema,
  updatedAt: DateTimeSchema.optional().nullable(),
});

export const TransactionCreateSchema = TransactionSchema.pick({
  transactionType: true,
  amount: true,
  refundAmount: true,
  accountSerialNum: true,
  toAccountSerialNum: true,
  paymentMethod: true,
  category: true,
  subCategory: true,
  date: true,
  transactionStatus: true,
  description: true,
  notes: true,
  tags: true,
  splitMembers: true,
  actualPayerAccount: true,
  relatedTransactionSerialNum: true,
  isDeleted: true,
})
  .extend({
    currency: z.string().length(3),
  })
  .strict();

export const TransactionUpdateSchema = TransactionCreateSchema.partial();

export const TransferCreateSchema = TransactionSchema.pick({
  transactionType: true,
  amount: true,
  accountSerialNum: true,
  toAccountSerialNum: true,
  paymentMethod: true,
  category: true,
  subCategory: true,
  date: true,
  description: true,
})
  .extend({
    currency: z.string().length(3),
  })
  .strict();

export type Transaction = z.infer<typeof TransactionSchema>;
export type TransactionCreate = z.infer<typeof TransactionCreateSchema>;
export type TransactionUpdate = z.infer<typeof TransactionUpdateSchema>;
export type TransferCreate = z.infer<typeof TransferCreateSchema>;
