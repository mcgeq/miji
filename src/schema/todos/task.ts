import { z } from 'zod/v4';
import { SerialNumSchema } from '../common';

export const TaskSchema = z.object({
  taskSerialNum: SerialNumSchema,
  dependsOnTaskSerialNum: SerialNumSchema,
});

export type Task = z.infer<typeof TaskSchema>;
