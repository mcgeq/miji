import { z } from 'zod';
import {
  DateSchema,
  DateTimeSchema,
  ExerciseIntensitySchema,
  FlowLevelSchema,
  SerialNumSchema,
} from '@/schema/common';

// 扩展经期相关类型定义
export const MoodSchema = z.enum(['Happy', 'Sad', 'Angry', 'Anxious', 'Calm', 'Irritable']);
export type Mood = z.infer<typeof MoodSchema>;

export const PainTypeSchema = z.enum([
  'Cramp',
  'Headache',
  'BackPain',
  'BreastTenderness',
  'Bloating',
]);
export type PainType = z.infer<typeof PainTypeSchema>;
export const ContraceptionMethodSchema = z.enum(['None', 'Condom', 'Pill', 'Iud', 'Other']);
export type ContraceptionMethod = z.infer<typeof ContraceptionMethodSchema>;
export const PeriodPhaseSchema = z.enum(['Menstrual', 'Follicular', 'Ovulation', 'Luteal']);
export type PeriodPhase = z.infer<typeof PeriodPhaseSchema>;

// 增强的经期记录类型
export const PeriodDailyRecordsSchema = z.object({
  serialNum: SerialNumSchema,
  periodSerialNum: SerialNumSchema,
  date: DateSchema,
  flowLevel: FlowLevelSchema.optional().nullable(),
  sexualActivity: z.boolean(),
  contraceptionMethod: ContraceptionMethodSchema.optional(),
  exerciseIntensity: ExerciseIntensitySchema,
  diet: z.string(),
  mood: MoodSchema.optional().nullable(),
  waterIntake: z.number().min(0).max(5000).optional(), // ml
  sleepHours: z.number().min(0).max(24).optional(),
  notes: z.string().max(500).optional(),
  createdAt: DateTimeSchema,
  updatedAt: DateTimeSchema.optional().nullable(),
});
export const PeriodDailyRecordCreateSchema = PeriodDailyRecordsSchema.omit({
  serialNum: true,
  createdAt: true,
  updatedAt: true,
}).strict();
export const PeriodDailyRecordUpdateSchema = PeriodDailyRecordCreateSchema.partial().nullable();

export type PeriodDailyRecords = z.infer<typeof PeriodDailyRecordsSchema>;
export type PeriodDailyRecordCreate = z.infer<typeof PeriodDailyRecordCreateSchema>;
export type PeriodDailyRecordUpdate = z.infer<typeof PeriodDailyRecordUpdateSchema>;
