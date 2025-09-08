import { z } from 'zod';
import {
  DateTimeSchema,
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
  priority: PrioritySchema, // 建议改为 z.enum(['Low', 'Medium', ...])
  status: StatusSchema,
  repeat: RepeatPeriodSchema,
  completedAt: DateTimeSchema.nullable(),
  assigneeId: NullableStringSchema,
  progress: z.number().min(0).max(100),
  location: NullableStringSchema,
  ownerId: SerialNumSchema.nullable(),
  isArchived: z.union([z.literal(0), z.literal(1)]),
  isPinned: z.union([z.literal(0), z.literal(1)]),
  estimateMinutes: z.number().int().nonnegative().nullable(),
  reminderCount: z.number().int().nonnegative(),
  parentId: SerialNumSchema.nullable(),
  subtaskOrder: z.number().int().nullable(),
});

export type Todo = z.infer<typeof TodoSchema>;
export type TodoRemain = Todo & { remainingTime: string };
