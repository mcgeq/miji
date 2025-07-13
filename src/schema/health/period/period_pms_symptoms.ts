import { z } from 'zod';
import {
  SerialNumSchema,
  DateTimeSchema,
  IntensitySchema,
  SymptomsTypeSchema,
} from '@/schema/common';

export const PeriodPmsSymptomsSchema = z.object({
  serialNum: SerialNumSchema,
  periodPmsRecordsSerialNum: SerialNumSchema,
  symptomType: SymptomsTypeSchema,
  intensity: IntensitySchema,
  createdAt: DateTimeSchema,
  updatedAt: DateTimeSchema.optional().nullable(),
});

export type PeriodPmsSymptoms = z.infer<typeof PeriodPmsSymptomsSchema>;
