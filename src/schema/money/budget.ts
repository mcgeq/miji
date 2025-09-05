import { z } from 'zod';
import {
  AlertThresholdSchema,
  AttachmentSchema,
  BudgetTypeSchema,
  CategorySchema,
  CurrencySchema,
  DateSchema,
  DateTimeSchema,
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
export const BudgetScopeTypeSchema = z.enum([
  'Category',
  'Account',
  'Hybrid',
  'RuleBased',
]);

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
  accountSerialNum: SerialNumSchema,
  name: NameSchema,
  description: DescriptionSchema,
  amount: z.number(),
  currency: CurrencySchema,
  repeatPeriod: RepeatPeriodSchema,
  startDate: DateSchema,
  endDate: DateSchema,
  usedAmount: z.number(),
  isActive: z.boolean(),
  alertEnabled: z.boolean(),
  alertThreshold: AlertThresholdSchema.optional(),
  color: z.string(),
  account: AccountSchema.optional().nullable(),
  currentPeriodUsed: z.number().min(0).optional(),
  currentPeriodStart: DateSchema.optional(),
  budgetType: BudgetTypeSchema.optional(),
  progress: z.number().min(0).max(100).optional(),
  linkedGoal: SerialNumSchema.optional(),
  reminders: z.array(ReminderSchema).optional(),
  priority: z.number().int().min(-128).max(127).optional(),
  tags: z.array(z.string()).optional(),
  autoRollover: z.boolean().optional(),
  rolloverHistory: z.array(RolloverRecordSchema).optional(),
  sharingSettings: SharingSettingsSchema.optional(),
  attachments: z.array(AttachmentSchema).optional(),
  budgetScopeType: BudgetScopeTypeSchema,
  accountScope: AccountScopeSchema.optional().nullable(),
  categoryScope: z.array(CategorySchema),
  advancedRules: z.array(BudgetRuleSchema).optional().nullable(),
  createdAt: DateTimeSchema,
  updatedAt: DateTimeSchema.optional().nullable(),
});

export const BudgetCreateSchema = BudgetSchema.pick({
  description: true,
  accountSerialNum: true,
  name: true,
  amount: true,
  repeatPeriod: true,
  startDate: true,
  endDate: true,
  usedAmount: true,
  isActive: true,
  alertEnabled: true,
  alertThreshold: true,
  color: true,
  budgetType: true,
  budgetScopeType: true, // 新增
  accountScope: true, // 新增
  categoryScope: true, // 新增
  advancedRules: true, // 新增
})
  .extend({
    currency: z.string().length(3),
  })
  .strict();

export const BudgetUpdateSchema = BudgetSchema.omit({
  serialNum: true,
  currency: true,
  createdAt: true,
  updatedAt: true,
})
  .extend({
    currency: z.string().length(3),
  })
  .partial();

export type Budget = z.infer<typeof BudgetSchema>;
export type BudgetCreate = z.infer<typeof BudgetCreateSchema>;
export type BudgetUpdate = z.infer<typeof BudgetUpdateSchema>;
