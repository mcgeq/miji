import { z } from 'zod/v4';

export const passwordRegex =
  /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$/;
export const alphanumericRegex = /^[a-z0-9]+$/;
export const ColorHexRegex = /^0x[0-9a-fA-F]{3,8}$/;
export const NullableStringSchema = z.string().optional().nullable();
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

export const RepeatPeriodSchema = z.enum([
  'Daily',
  'Weekly',
  'Monthy',
  'Quarterly',
  'Yearly',
]);
export type RepeatPeriod = z.infer<typeof RepeatPeriodSchema>;

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
