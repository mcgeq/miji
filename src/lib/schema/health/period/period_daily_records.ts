import { z } from 'zod/v4';
import {
  SerialNumSchema,
  DateSchema,
  DateTimeSchema,
  FlowLevelSchema,
  ExerciseIntensitySchema,
} from '@/lib/schema/common';

export const PeriodDailyRecordsSchema = z.object({
  serial_num: SerialNumSchema,
  period_serial_num: SerialNumSchema,
  date: DateSchema,
  flow_level: FlowLevelSchema.optional().nullable(),
  sexual_activity: z.boolean(),
  exercise_intensity: ExerciseIntensitySchema,
  diet: z.string(),
  created_at: DateTimeSchema,
  updated_at: DateTimeSchema.optional().nullable(),
});

export type PeriodDailyRecords = z.infer<typeof PeriodDailyRecordsSchema>;
