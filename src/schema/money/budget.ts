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

export const BudgetSchema = z.object({
  serialNum: SerialNumSchema,
  accountSerialNum: SerialNumSchema,
  name: NameSchema,
  description: DescriptionSchema,
  category: CategorySchema,
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
