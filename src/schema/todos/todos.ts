import { z } from 'zod';
import {
  DateTimeSchema,
  DecimalLikeSchema,
  NullableStringSchema,
  PrioritySchema,
  RepeatPeriodSchema,
  SerialNumSchema,
  StatusSchema,
} from '../common';

export const TodoSchema = z.object({
  serialNum: SerialNumSchema,
  title: z.string().min(1).max(100),
  description: NullableStringSchema,
  createdAt: DateTimeSchema,
  updatedAt: DateTimeSchema.nullable(),
  dueAt: DateTimeSchema,
  priority: PrioritySchema,
  status: StatusSchema,
  repeatPeriodType: z.string(),
  repeat: RepeatPeriodSchema,
  completedAt: DateTimeSchema.nullable(),
  assigneeId: NullableStringSchema,
  progress: z.number().min(0).max(100),
  location: NullableStringSchema,
  ownerId: SerialNumSchema.nullable(),
  isArchived: z.boolean(),
  isPinned: z.boolean(),
  estimateMinutes: DecimalLikeSchema.nullable(),
  reminderCount: DecimalLikeSchema,
  parentId: SerialNumSchema.nullable(),
  subtaskOrder: DecimalLikeSchema.nullable(),
  // 新增提醒相关字段
  reminderEnabled: z.boolean(),
  reminderAdvanceValue: DecimalLikeSchema.nullable(),
  reminderAdvanceUnit: NullableStringSchema,
  lastReminderSentAt: DateTimeSchema.nullable(),
  reminderFrequency: NullableStringSchema,
  snoozeUntil: DateTimeSchema.nullable(),
  reminderMethods: z.any().nullable(), // JSON对象
  timezone: NullableStringSchema,
  smartReminderEnabled: z.boolean(),
  locationBasedReminder: z.boolean(),
  weatherDependent: z.boolean(),
  priorityBoostEnabled: z.boolean(),
  batchReminderId: SerialNumSchema.nullable(),
});

export const TodoCreateSchema = TodoSchema.omit({
  serialNum: true,
  createdAt: true,
  updatedAt: true,
});
export const TodoUpdateSchema = TodoCreateSchema.partial();

export type Todo = z.infer<typeof TodoSchema>;
export type TodoCreate = z.infer<typeof TodoCreateSchema>;
export type TodoUpdate = z.infer<typeof TodoUpdateSchema>;
