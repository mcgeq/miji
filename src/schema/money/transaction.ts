import { z } from 'zod';
import {
  CurrencySchema,
  DateSchema,
  DateTimeSchema,
  SerialNumSchema,
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
  category: z.string(),
  subCategory: z.string().optional().nullable(),
  tags: z.array(TagsSchema),
  splitMembers: z.array(FamilyMemberSchema).optional(),
  paymentMethod: PaymentMethodSchema,
  actualPayerAccount: AccountTypeSchema,
  relatedTransactionSerialNum: SerialNumSchema.optional(),
  isDeleted: z.boolean().default(false),
  createdAt: DateTimeSchema,
  updatedAt: DateTimeSchema.optional().nullable(),
  // 分期相关字段
  isInstallment: z.boolean().optional().default(false),
  firstDueDate: DateSchema.optional().nullable(),
  totalPeriods: z.number().optional().default(0),
  remainingPeriods: z.number().optional().default(0),
  installmentAmount: z.number().optional().default(0),
  remainingPeriodsAmount: z.number().optional().default(0),
  installmentPlanSerialNum: z.string().optional().nullable(),
  // 家庭记账本关联（支持多个）
  familyLedgerSerialNums: z.array(SerialNumSchema).optional().default([]),
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
  // 分期相关字段
  isInstallment: true,
  firstDueDate: true,
  totalPeriods: true,
  remainingPeriods: true,
  installmentAmount: true,
  remainingPeriodsAmount: true,
  // 家庭记账本关联（支持多个）
  familyLedgerSerialNums: true,
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

// 后端API响应类型定义
interface InstallmentCalculationDetail {
  period: number;
  amount: number;
  due_date: string; // YYYY-MM-DD format
  status?: string;
  paid_date?: string;
  paid_amount?: number;
}

export interface InstallmentCalculationResponse {
  installment_amount: number;
  details: InstallmentCalculationDetail[];
}

export interface InstallmentCalculationRequest {
  total_amount: number;
  total_periods: number;
  first_due_date: string; // YYYY-MM-DD format
}

export type Transaction = z.infer<typeof TransactionSchema>;
export type TransactionCreate = z.infer<typeof TransactionCreateSchema>;
export type TransactionUpdate = z.infer<typeof TransactionUpdateSchema>;
export type TransferCreate = z.infer<typeof TransferCreateSchema>;
