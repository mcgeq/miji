import { z } from 'zod';
import {
  CategoryNameSchema,
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
  // 使用 CategoryNameSchema 确保类型约束
  category: CategoryNameSchema,
  amount: z.number().optional(),
  currency: CurrencySchema.optional().nullable(),
  dueAt: DateTimeSchema,
  billDate: DateTimeSchema.optional().nullable(),
  remindDate: DateTimeSchema,
  repeatPeriodType: z.string(),
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
  // 新增高级提醒功能字段
  lastReminderSentAt: DateTimeSchema.optional().nullable(),
  reminderFrequency: z.string().optional().nullable(),
  snoozeUntil: DateTimeSchema.optional().nullable(),
  reminderMethods: z.any().optional().nullable(), // JSON对象
  escalationEnabled: z.boolean(),
  escalationAfterHours: z.number().optional().nullable(),
  timezone: z.string().optional().nullable(),
  smartReminderEnabled: z.boolean(),
  autoReschedule: z.boolean(),
  paymentReminderEnabled: z.boolean(),
  batchReminderId: SerialNumSchema.optional().nullable(),
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
  repeatPeriodType: true,
  repeatPeriod: true,
  isPaid: true,
  isDeleted: true,
  priority: true,
  advanceValue: true,
  advanceUnit: true,
  color: true,
  relatedTransactionSerialNum: true,
  // 新增高级提醒功能字段
  lastReminderSentAt: true,
  reminderFrequency: true,
  snoozeUntil: true,
  reminderMethods: true,
  escalationEnabled: true,
  escalationAfterHours: true,
  timezone: true,
  smartReminderEnabled: true,
  autoReschedule: true,
  paymentReminderEnabled: true,
  batchReminderId: true,
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
