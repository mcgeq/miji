import { z } from 'zod/v4';
import {
  DateTimeSchema,
  IntensitySchema,
  SerialNumSchema,
  SymptomsTypeSchema,
} from '@/schema/common';

export const PeriodSymptomsSchema = z.object({
  serialNum: SerialNumSchema,
  periodDailyRecordsSerialNum: SerialNumSchema,
  symptomType: SymptomsTypeSchema,
  intensity: IntensitySchema,
  createdAt: DateTimeSchema,
  updatedAt: DateTimeSchema.optional().nullable(),
});

export type PeriodSymptoms = z.infer<typeof PeriodSymptomsSchema>;
