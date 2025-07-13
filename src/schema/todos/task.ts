import { z } from 'zod';
import { SerialNumSchema } from '../common';

export const TaskSchema = z.object({
  taskSerialNum: SerialNumSchema,
  dependsOnTaskSerialNum: SerialNumSchema,
});

export type Task = z.infer<typeof TaskSchema>;
