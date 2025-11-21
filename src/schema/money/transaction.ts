import { z } from 'zod';
import {
  AmountSchema,
  CategoryNameSchema,
  CurrencySchema,
  DateSchema,
  DateTimeSchema,
  SerialNumSchema,
  SubCategoryNameSchema,
  TransactionStatusSchema,
  TransactionTypeSchema,
} from '../common';
import { TagsSchema } from '../tags';
import { AccountSchema } from './account';
import { AccountTypeSchema, PaymentMethodSchema } from './money.e';

// 分摊成员 Schema（扩展支持自定义金额和付款人）
export const SplitMemberSchema = z.object({
  serialNum: SerialNumSchema,
  name: z.string(),
  // 新增：自定义分摊金额（可选，不填则平均分摊）
  amount: AmountSchema.optional(),
  // 新增：付款人ID（可选，不填则为自己）
  payerSerialNum: SerialNumSchema.optional(),
  // 新增：分摊百分比（可选，用于按百分比分摊）
  percentage: z.number().min(0).max(100).optional(),
  // 新增：权重（可选，用于按权重分摊）
  weight: z.number().int().min(1).optional(),
  // 扩展字段
  avatar: z.string().optional().nullable(),
  colorTag: z.string().optional().nullable(),
});

export type SplitMember = z.infer<typeof SplitMemberSchema>;

// 分摊配置 Schema
export const SplitConfigSchema = z.object({
  enabled: z.boolean(),
  splitType: z.enum(['EQUAL', 'PERCENTAGE', 'FIXED_AMOUNT', 'WEIGHTED']),
  members: z.array(z.object({
    memberSerialNum: SerialNumSchema,
    memberName: z.string(),
    amount: z.number(),
    percentage: z.number().optional(),
    weight: z.number().optional(),
  })),
});

export type SplitConfig = z.infer<typeof SplitConfigSchema>;

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
  // 使用 CategoryNameSchema 确保类型约束
  category: CategoryNameSchema,
  subCategory: SubCategoryNameSchema.optional().nullable(),
  tags: z.array(TagsSchema),
  splitMembers: z.array(SplitMemberSchema).optional(),
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
  // 分摊配置（可选）
  splitConfig: SplitConfigSchema.optional(),
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
  // 分摊配置
  splitConfig: true,
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
