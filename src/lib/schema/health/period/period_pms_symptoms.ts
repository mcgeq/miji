import { z } from 'zod/v4';
import {
  SerialNumSchema,
  DateTimeSchema,
  IntensitySchema,
  SymptomsTypeSchema,
} from '@/lib/schema/common';

export const PeriodPmsSymptomsSchema = z.object({
  serial_num: SerialNumSchema,
  period_pms_records_serial_num: SerialNumSchema,
  symptom_type: SymptomsTypeSchema,
  intensity: IntensitySchema,
  created_at: DateTimeSchema,
  updated_at: DateTimeSchema.optional().nullable(),
});

export type PeriodPmsSymptoms = z.infer<typeof PeriodPmsSymptomsSchema>;
