import { z } from 'zod/v4';
import {
  SerialNumSchema,
  DateTimeSchema,
  DateSchema,
} from '@/lib/schema/common';

export const PeriodPmsRecordsSchema = z.object({
  serial_num: SerialNumSchema,
  period_serial_num: SerialNumSchema,
  start_date: DateSchema,
  end_date: DateSchema,
  created_at: DateTimeSchema,
  updated_at: DateTimeSchema.optional().nullable(),
});

export type PeriodPmsRecords = z.infer<typeof PeriodPmsRecordsSchema>;
