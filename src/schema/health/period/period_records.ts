import {z} from 'zod';
import {
  SerialNumSchema,
  DateTimeSchema,
  DateSchema,
  Intensity,
  SymptomsType,
} from '@/schema/common';
import {PeriodPhase} from './period_daily_records';

export const PeriodRecordsSchema = z.object({
  serialNum: SerialNumSchema,
  notes: z.string(),
  startDate: DateSchema,
  endDate: DateSchema,
  createdAt: DateTimeSchema,
  updatedAt: DateTimeSchema.optional().nullable(),
});

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
  type: 'period' | 'ovulation' | 'fertile' | 'pms';
  intensity?: Intensity;
  symptoms?: SymptomsType[];
}

// 经期设置类型
export interface PeriodSettings {
  averageCycleLength: number;
  averagePeriodLength: number;
  notifications: {
    periodReminder: boolean;
    ovulationReminder: boolean;
    pmsReminder: boolean;
    reminderDays: number;
  };
  privacy: {
    dataSync: boolean;
    analytics: boolean;
  };
}
export type PeriodRecords = z.infer<typeof PeriodRecordsSchema>;
