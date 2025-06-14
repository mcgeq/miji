import { z } from 'zod/v4';
import {
  SerialNumSchema,
  DateTimeSchema,
  PrioritySchema,
  StatusSchema,
  NullableStringSchema,
} from '../common';

export const TodoSchema = z.object({
  serial_num: SerialNumSchema,
  title: z.string().min(1).max(100),
  description: NullableStringSchema,
  created_at: DateTimeSchema,
  updated_at: DateTimeSchema.optional().nullable(),
  due_at: DateTimeSchema,
  priority: PrioritySchema, // 建议改为 z.enum(['Low', 'Medium', ...])
  status: StatusSchema,
  repeat: NullableStringSchema,
  completed_at: DateTimeSchema.optional().nullable(),
  assignee_id: NullableStringSchema,
  progress: z.number().min(0).max(100),
  location: NullableStringSchema,
  owner_id: SerialNumSchema.optional().nullable(),
  is_archived: z.boolean(),
  is_pinned: z.boolean(),
  estimate_minutes: z.number().int().nonnegative().optional().nullable(),
  reminder_count: z.number().int().nonnegative(),
  parent_id: SerialNumSchema.optional().nullable(),
  subtask_order: z.number().int().optional().nullable(),
});

export type Todo = z.infer<typeof TodoSchema>;
