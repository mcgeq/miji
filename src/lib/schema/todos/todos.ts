import { z } from 'zod/v4';
import {
  SerialNumSchema,
  DateTimeSchema,
  PrioritySchema,
  StatusSchema,
  NullableStringSchema,
} from '../common';

export const TodoSchema = z.object({
  serialNum: SerialNumSchema,
  title: z.string().min(1).max(100),
  description: NullableStringSchema,
  createdAt: DateTimeSchema,
  updatedAt: DateTimeSchema.optional().nullable(),
  dueAt: DateTimeSchema,
  priority: PrioritySchema, // 建议改为 z.enum(['Low', 'Medium', ...])
  status: StatusSchema,
  repeat: NullableStringSchema,
  completedAt: DateTimeSchema.optional().nullable(),
  assigneeId: NullableStringSchema,
  progress: z.number().min(0).max(100),
  location: NullableStringSchema,
  ownerId: SerialNumSchema.optional().nullable(),
  isArchived: z.boolean(),
  isPinned: z.boolean(),
  estimateMinutes: z.number().int().nonnegative().optional().nullable(),
  reminderCount: z.number().int().nonnegative(),
  parentId: SerialNumSchema.optional().nullable(),
  subtaskOrder: z.number().int().optional().nullable(),
});

export type Todo = z.infer<typeof TodoSchema>;
export type TodoRemain = Todo & { remainingTime: string };
