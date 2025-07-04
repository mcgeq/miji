import { z } from 'zod/v4';
import { SerialNumSchema, DateTimeSchema, DateSchema } from '@/schema/common';

export const PeriodRecordsSchema = z.object({
  serialNum: SerialNumSchema,
  startDate: DateSchema,
  endDate: DateSchema,
  createdAt: DateTimeSchema,
  updatedAt: DateTimeSchema.optional().nullable(),
});

export type PeriodRecords = z.infer<typeof PeriodRecordsSchema>;
