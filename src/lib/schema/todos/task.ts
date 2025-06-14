import { z } from 'zod/v4';
import { SerialNumSchema } from '../common';

export const TaskSchema = z.object({
  task_serial_num: SerialNumSchema,
  depends_on_task_serial_num: SerialNumSchema,
});

export type Task = z.infer<typeof TaskSchema>;
