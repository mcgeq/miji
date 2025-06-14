import { z } from 'zod/v4';
import {
  DateTimeSchema,
  IntensitySchema,
  SerialNumSchema,
  SymptomsTypeSchema,
} from '@/lib/schema/common';

export const PeriodSymptomsSchema = z.object({
  serial_num: SerialNumSchema,
  period_daily_records_serial_num: SerialNumSchema,
  symptom_type: SymptomsTypeSchema,
  intensity: IntensitySchema,
  created_at: DateTimeSchema,
  updated_at: DateTimeSchema.optional().nullable(),
});

export type PeriodSymptoms = z.infer<typeof PeriodSymptomsSchema>;
