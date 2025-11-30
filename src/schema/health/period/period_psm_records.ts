import { z } from 'zod';
import { DateSchema, DateTimeSchema, SerialNumSchema } from '@/schema/common';

export const PeriodPmsRecordsSchema = z.object({
  serialNum: SerialNumSchema,
  periodSerialNum: SerialNumSchema,
  startDate: DateSchema,
  endDate: DateSchema,
  createdAt: DateTimeSchema,
  updatedAt: DateTimeSchema.optional().nullable(),
});

export type PeriodPmsRecords = z.infer<typeof PeriodPmsRecordsSchema>;
