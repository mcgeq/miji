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
  date: DateSchema,
  amount: z.number(),
  account: AccountSchema,
  currency: CurrencySchema,
  description: z.string().max(1000).optional(),
  notes: z.string().optional().nullable(),
  accountSerialNum: SerialNumSchema,
  category: CategorySchema,
  subCategory: SubCategorySchema.optional().nullable(),
  tags: z.array(TagsSchema),
  splitMembers: z.array(FamilyMemberSchema).optional(),
  paymentMethod: PaymentMethodSchema,
  actualPayerAccount: AccountTypeSchema,
  relatedTransactionSerialNum: SerialNumSchema.optional(),
  idDeleted: z.boolean().default(false),
  createdAt: DateTimeSchema,
  updatedAt: DateTimeSchema.optional().nullable(),
});

export const TransactionCreateSchema = TransactionSchema.pick(
  {
    transactionType: true,
    transactionStatus: true,
    date: true,
    amount: true,
    description: true,
    notes: true,
    accountSerialNum: true,
    category: true,
    subCategory: true,
    tags: true,
    splitMembers: true,
    paymentMethod: true,
    actualPayerAccount: true,
    relatedTransactionSerialNum: true,
    idDeleted: true,
  },
).extend({
  currency: z.string().length(3),
}).strict();

export const TransactionUpdateSchema = TransactionCreateSchema.partial();

export type Transaction = z.infer<typeof TransactionSchema>;
export type TransactionCreate = z.infer<typeof TransactionCreateSchema>;
export type TransactionUpdate = z.infer<typeof TransactionUpdateSchema>;
