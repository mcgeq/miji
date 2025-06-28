import { z } from 'zod/v4';
import { SerialNumSchema, DateTimeSchema, DateSchema } from '@/schema/common';

export const PeriodPmsRecordsSchema = z.object({
  serialNum: SerialNumSchema,
  periodSerialNum: SerialNumSchema,
  startDate: DateSchema,
  endDate: DateSchema,
  createdAt: DateTimeSchema,
  updatedAt: DateTimeSchema.optional().nullable(),
});

export type PeriodPmsRecords = z.infer<typeof PeriodPmsRecordsSchema>;
