import { z } from 'zod';
import { DateTimeSchema, SerialNumSchema } from '../common';

export const NotificationSettingsSchema = z.object({
  serialNum: SerialNumSchema,
  userId: SerialNumSchema,
  notificationType: z.string(),
  enabled: z.boolean(),
  quietHoursStart: z.string().optional().nullable(), // Time as string
  quietHoursEnd: z.string().optional().nullable(), // Time as string
  quietDays: z.any().optional().nullable(), // JSON array of day numbers (0-6)
  soundEnabled: z.boolean(),
  vibrationEnabled: z.boolean(),
  createdAt: DateTimeSchema,
  updatedAt: DateTimeSchema.optional().nullable(),
});

export const NotificationSettingsCreateSchema = NotificationSettingsSchema.omit({
  serialNum: true,
  createdAt: true,
  updatedAt: true,
});

export const NotificationSettingsUpdateSchema = NotificationSettingsCreateSchema.partial();

export type NotificationSettings = z.infer<typeof NotificationSettingsSchema>;
export type NotificationSettingsCreate = z.infer<typeof NotificationSettingsCreateSchema>;
export type NotificationSettingsUpdate = z.infer<typeof NotificationSettingsUpdateSchema>;
