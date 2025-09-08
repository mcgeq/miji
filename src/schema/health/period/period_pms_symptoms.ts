import { z } from 'zod';
import {
  DateTimeSchema,
  IntensitySchema,
  SerialNumSchema,
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
