import { z } from 'zod/v4';

export const passwordRegex =
  /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$/;
export const alphanumericRegex = /^[a-z0-9]+$/;
export const ColorHexRegex = /^0x[0-9a-fA-F]{3,8}$/;
export const NullableStringSchema = z.string().nullable();
export const SerialNumSchema = z
  .string()
  .length(38, { error: 'Serial number must be 38 character.' })
  .regex(alphanumericRegex, {
    error: 'Serial number must contain only letters and numbers',
  });

export const NameSchema = z.string().min(3).max(20);

export const DescriptionSchema = z.string().max(1000);

export const DateTimeSchema = z.iso.datetime({
  offset: true,
  local: true,
  precision: 6,
});

export const DateSchema = z.iso.date();
export const TimesSchema = z.iso.time();
export const CurrencySchema = z.object({
  code: z.string().length(3),
  symbol: z.string(),
});

export type Currency = z.infer<typeof CurrencySchema>;
export const weekdays = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
] as const;
export const RepeatPeriodSchema = z.discriminatedUnion('type', [
  z.object({
    type: z.literal('None'),
  }),
  z.object({
    type: z.literal('Daily'),
    interval: z.number().min(1).default(1), // 每 N 天
  }),
  z.object({
    type: z.literal('Weekly'),
    interval: z.number().min(1).default(1), // 每 N 周
    daysOfWeek: z.array(z.enum(weekdays)).nonempty(),
  }),
  z.object({
    type: z.literal('Monthly'),
    interval: z.number().min(1).default(1), // 每 N 月
    day: z.union([z.number().min(1).max(31), z.literal('last')]), // 指定几号 或 最后一天
  }),
  z.object({
    type: z.literal('Yearly'),
    interval: z.number().min(1).default(1), // 每 N 年
    month: z.number().min(1).max(12),
    day: z.number().min(1).max(31),
  }),
  z.object({
    type: z.literal('Custom'),
    description: z.string().min(1), // 自定义描述
  }),
]);

export type RepeatPeriod = z.infer<typeof RepeatPeriodSchema>;

export type RepeatType = RepeatPeriod['type'];

export type Weekday = (typeof weekdays)[number];

export const ReminderTypeSchema = z.enum(['Notification', 'Email', 'Popup']);
export type ReminderType = z.infer<typeof ReminderTypeSchema>;

export const TransactionStatusSchema = z.enum([
  'Pending',
  'Completed',
  'Reversed',
]);
export type TransactionStatus = z.infer<typeof TransactionStatusSchema>;

export const TransactionTypeSchema = z.enum(['Income', 'Expense']);
export type TransactionType = z.infer<typeof TransactionTypeSchema>;

export const CategorySchema = z.enum([
  'Food',
  'Transport',
  'Entertainment',
  'Utilities',
  'Shopping',
  'Salary',
  'Investment',
  'Others',
]);
export type Category = z.infer<typeof CategorySchema>;

export const SubCategorySchema = z.enum([
  'Restaurant',
  'Groceries',
  'Snacks',
  'Bus',
  'Taxi',
  'Fuel',
  'Movies',
  'Concerts',
  'MonthlySalary',
  'Bonus',
  'Other',
]);
export type SubCategory = z.infer<typeof SubCategorySchema>;

// todos
// Exercise Intensity
export const ExerciseIntensitySchema = z.enum([
  'None',
  'Light',
  'Medium',
  'Heavy',
]);
export type ExerciseIntensity = z.infer<typeof ExerciseIntensitySchema>;

// Flow Level
export const FlowLevelSchema = z.enum(['Light', 'Medium', 'Heavy']);
export type FlowLevel = z.infer<typeof FlowLevelSchema>;

// Intensity
export const IntensitySchema = z.enum(['Light', 'Medium', 'Heavy']);
export type Intensity = z.infer<typeof IntensitySchema>;

// Symptoms Type
export const SymptomsTypeSchema = z.enum(['Pain', 'Fatigue', 'MoodSwing']);
export type SymptomsType = z.infer<typeof SymptomsTypeSchema>;

// 优先级 Priority
export const PrioritySchema = z.enum(['Low', 'Medium', 'High', 'Urgent']);
export type Priority = z.infer<typeof PrioritySchema>;

// 状态 Status
export const StatusSchema = z.enum([
  'NotStarted',
  'InProgress',
  'Completed',
  'Cancelled',
  'Overdue',
]);
export type Status = z.infer<typeof StatusSchema>;

export const FilterBtnSchema = z.enum(['YESTERDAY', 'TODAY', 'TOMORROW']);
export type FilterBtn = z.infer<typeof FilterBtnSchema>;

export interface DateRange {
  start?: string;
  end?: string;
}

export interface QueryFilters {
  status?: Status;
  createdAtRange?: DateRange;
  completedAtRange?: DateRange;
  dueAtRange?: DateRange;
}

export type SortOptions = {
  customOrderBy?: string; // 新增：完整排序 SQL
  sortBy?: string;
  sortDir?: 'ASC' | 'DESC';
};

export type UsageDetail = {
  count: number;
  serialNums: string[];
};
