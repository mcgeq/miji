import { z } from 'zod';
import {
  SerialNumSchema,
  DateSchema,
  DateTimeSchema,
  FlowLevelSchema,
  ExerciseIntensitySchema,
} from '@/schema/common';

export const PeriodDailyRecordsSchema = z.object({
  serialNum: SerialNumSchema,
  periodSerialNum: SerialNumSchema,
  date: DateSchema,
  flowLevel: FlowLevelSchema.optional().nullable(),
  sexualActivity: z.boolean(),
  exerciseIntensity: ExerciseIntensitySchema,
  diet: z.string(),
  createdAt: DateTimeSchema,
  updatedAt: DateTimeSchema.optional().nullable(),
});

export type PeriodDailyRecords = z.infer<typeof PeriodDailyRecordsSchema>;
