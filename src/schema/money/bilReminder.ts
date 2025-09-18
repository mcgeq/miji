import { z } from 'zod';
import {
  CurrencySchema,
  DateTimeSchema,
  DescriptionSchema,
  NameSchema,
  PrioritySchema,
  RepeatPeriodSchema,
  SerialNumSchema,
} from '../common';

export const ReminderTypesSchema = z.enum([
  // 财务相关
  'Bill',
  'Income',
  'Budget',
  'Investment',
  'Savings',
  'Tax',
  'Insurance',
  'Loan',

  // 目标与计划
  'Goal',
  'Milestone',
  'Review',

  // 健康生活
  'Health',
  'Exercise',
  'Medicine',
  'Diet',
  'Sleep',

  // 工作学习
  'Work',
  'Deadline',
  'Meeting',
  'Study',
  'Exam',
  'Training',

  // 生活事务
  'Shopping',
  'Maintenance',
  'Renewal',
  'Travel',
  'Event',
  'Birthday',
  'Anniversary',
  'Call',

  // 文档证件
  'Document',
  'Passport',
  'License',

  // 家庭生活
  'Family',
  'Pet',
  'Chores',

  // 兴趣爱好
  'Hobby',
  'Reading',
  'Music',

  // 技术相关
  'Backup',
  'Security',

  // 通用分类
  'Important',
  'Urgent',
  'Routine',
  'Custom',
  'Other',
]);

export const FinanceTypesSchema = z.enum([
  'Bill',
  'Income',
  'Budget',
  'Investment',
  'Savings',
  'Tax',
  'Insurance',
  'Loan',
]);

export const BilReminderSchema = z.object({
  serialNum: SerialNumSchema,
  name: NameSchema,
  enabled: z.boolean(),
  type: ReminderTypesSchema,
  description: DescriptionSchema.optional().nullable(),
  category: z.string(),
  amount: z.number().optional(),
  currency: CurrencySchema.optional().nullable(),
  dueAt: DateTimeSchema,
  billDate: DateTimeSchema.optional().nullable(),
  remindDate: DateTimeSchema,
  repeatPeriod: RepeatPeriodSchema,
  isPaid: z.boolean(),
  priority: PrioritySchema,
  advanceValue: z.number().optional(),
  advanceUnit: z.string().optional(),
  color: z.string(),
  relatedTransactionSerialNum: SerialNumSchema.optional().nullable(),
  isDeleted: z.boolean(),
  createdAt: DateTimeSchema,
  updatedAt: DateTimeSchema.optional().nullable(),
});

export const BilReminderCreateSchema = BilReminderSchema.pick({
  name: true,
  enabled: true,
  type: true,
  description: true,
  category: true,
  amount: true,
  dueAt: true,
  billDate: true,
  remindDate: true,
  repeatPeriod: true,
  isPaid: true,
  isDeleted: true,
  priority: true,
  advanceValue: true,
  advanceUnit: true,
  color: true,
  relatedTransactionSerialNum: true,
})
  .extend({
    currency: z.string().length(3),
  })
  .strict();

export const BilReminderUpdateSchema = BilReminderCreateSchema.partial();
export const BilReminderFiltersSchema = BilReminderSchema.omit({
  serialNum: true,
  amount: true,
  createdAt: true,
  updatedAt: true,
}).partial();

export type BilReminder = z.infer<typeof BilReminderSchema>;
export type BilReminderCreate = z.infer<typeof BilReminderCreateSchema>;
export type BilReminderUpdate = z.infer<typeof BilReminderUpdateSchema>;
export type BilReminderFilters = z.infer<typeof BilReminderFiltersSchema>;
export type ReminderTypes = z.infer<typeof ReminderTypesSchema>;
