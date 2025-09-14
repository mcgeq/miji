import { z } from 'zod';
import { DateSchema, DateTimeSchema, SerialNumSchema } from '@/schema/common';
import type { PeriodPhase } from './period_daily_records';
import type { Intensity, SymptomsType } from '@/schema/common';

export const PeriodRecordsSchema = z.object({
  serialNum: SerialNumSchema,
  notes: z.string(),
  startDate: DateSchema,
  endDate: DateSchema,
  createdAt: DateTimeSchema,
  updatedAt: DateTimeSchema.optional().nullable(),
});

export const PeriodRecordCreateSchema = PeriodRecordsSchema.pick({
  notes: true,
  startDate: true,
  endDate: true,
}).strict();

export const PeriodRecordUpdateSchema = PeriodRecordCreateSchema.partial();

// 经期统计数据类型
export interface PeriodStats {
  averageCycleLength: number;
  averagePeriodLength: number;
  nextPredictedDate: string;
  currentPhase: PeriodPhase;
  daysUntilNext: number;
}

// 经期日历事件类型
export interface PeriodCalendarEvent {
  date: string;
  type:
    | 'period'
    | 'ovulation'
    | 'fertile'
    | 'pms'
    | 'predicted-period'
    | 'predicted-ovulation'
    | 'predicted-fertile';
  intensity?: Intensity;
  symptoms?: SymptomsType[];
  isPredicted?: boolean;
}

export const PeriodSettingsSchema = z.object({
  serialNum: SerialNumSchema,
  averageCycleLength: z.number().int().positive(),
  averagePeriodLength: z.number().int().positive(),
  notifications: z.object({
    periodReminder: z.boolean(),
    ovulationReminder: z.boolean(),
    pmsReminder: z.boolean(),
    reminderDays: z.number().int().nonnegative(),
  }),
  privacy: z.object({
    dataSync: z.boolean(),
    analytics: z.boolean(),
  }),
  createdAt: DateTimeSchema,
  updatedAt: DateTimeSchema.optional().nullable(),
});

export const PeriodSettingsCreateSchema = PeriodSettingsSchema.omit({
  serialNum: true,
  createdAt: true,
  updatedAt: true,
}).strict();

export const PeriodSettingsUpdateSchema = PeriodRecordCreateSchema.partial();

export type PeriodRecords = z.infer<typeof PeriodRecordsSchema>;
export type PeriodRecordCreate = z.infer<typeof PeriodRecordCreateSchema>;
export type PeriodRecordUpdate = z.infer<typeof PeriodRecordUpdateSchema>;
export type PeriodSettings = z.infer<typeof PeriodSettingsSchema>;
export type PeriodSettingsCreate = z.infer<typeof PeriodSettingsCreateSchema>;
export type PeriodSettingsUpdate = z.infer<typeof PeriodSettingsUpdateSchema>;
