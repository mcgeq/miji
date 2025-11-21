import { z } from 'zod';
import {
  AlertThresholdSchema,
  AttachmentSchema,
  BudgetTypeSchema,
  CategoryNameSchema,
  CurrencySchema,
  DateSchema,
  DateTimeSchema,
  DecimalLikeSchema,
  DescriptionSchema,
  NameSchema,
  ReminderSchema,
  RepeatPeriodSchema,
  RolloverRecordSchema,
  SerialNumSchema,
  SharingSettingsSchema,
} from '../common';
import { AccountSchema } from './account';

// 新增预算范围类型定义
export const BudgetScopeTypeSchema = z.enum(['Category', 'Account', 'Hybrid', 'RuleBased']);

// 新增账户范围定义
export const AccountScopeSchema = z.object({
  includedAccounts: z.array(SerialNumSchema),
  excludedAccounts: z.array(SerialNumSchema).optional(),
  accountTypes: z.array(z.string()).optional(),
  includeAllOfType: z.boolean().optional(),
});

// 新增预算规则类型定义
export const BudgetRuleTypeSchema = z.enum([
  'DescriptionContains',
  'AmountGreaterThan',
  'AmountLessThan',
  'HasTag',
  'PaymentMethod',
]);

// 新增预算规则定义
export const BudgetRuleSchema = z.object({
  ruleType: BudgetRuleTypeSchema,
  value: z.string(),
  inverse: z.boolean().optional(),
});

export const BudgetSchema = z.object({
  serialNum: SerialNumSchema,
  accountSerialNum: SerialNumSchema.optional().nullable(),
  name: NameSchema,
  description: DescriptionSchema,
  amount: DecimalLikeSchema,
  currency: CurrencySchema,
  repeatPeriodType: z.string(),
  repeatPeriod: RepeatPeriodSchema,
  startDate: DateTimeSchema,
  endDate: DateTimeSchema,
  usedAmount: DecimalLikeSchema,
  isActive: z.boolean(),
  alertEnabled: z.boolean(),
  alertThreshold: AlertThresholdSchema.optional().nullable(),
  color: z.string(),
  account: AccountSchema.optional().nullable(),
  currentPeriodUsed: DecimalLikeSchema.optional().nullable(),
  currentPeriodStart: DateSchema.optional().nullable(),
  budgetType: BudgetTypeSchema.optional().nullable(),
  progress: DecimalLikeSchema.optional().nullable(),
  linkedGoal: SerialNumSchema.optional().nullable(),
  reminders: z.array(ReminderSchema).optional().nullable(),
  priority: z.number().int().min(-128).max(127).optional().nullable(),
  tags: z.array(z.string()).optional().nullable(),
  autoRollover: z.boolean().optional().nullable(),
  rolloverHistory: z.array(RolloverRecordSchema).optional().nullable(),
  sharingSettings: SharingSettingsSchema.optional().nullable(),
  attachments: z.array(AttachmentSchema).optional().nullable(),
  budgetScopeType: BudgetScopeTypeSchema,
  accountScope: AccountScopeSchema.optional().nullable(),
  // 使用 CategoryNameSchema 确保类型约束
  categoryScope: z.array(CategoryNameSchema),
  advancedRules: z.array(BudgetRuleSchema).optional().nullable(),
  createdAt: DateTimeSchema,
  updatedAt: DateTimeSchema.optional().nullable(),
});

// ----------------------
// BudgetCreateSchema
// ----------------------
export const BudgetCreateSchema = BudgetSchema.omit({
  serialNum: true,
  currency: true,
  createdAt: true,
  updatedAt: true,
}).extend({
  currency: z.string().length(3),
});

// ----------------------
// BudgetUpdateSchema
// ----------------------
export const BudgetUpdateSchema = BudgetCreateSchema.partial();

export type Budget = z.infer<typeof BudgetSchema>;
export type BudgetCreate = z.infer<typeof BudgetCreateSchema>;
export type BudgetUpdate = z.infer<typeof BudgetUpdateSchema>;
