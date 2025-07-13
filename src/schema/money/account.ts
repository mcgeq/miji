import { z } from 'zod';
import {
  CurrencySchema,
  DateTimeSchema,
  DescriptionSchema,
  NameSchema,
  SerialNumSchema,
} from '../common';

export const AccountSchema = z.object({
  serialNum: SerialNumSchema,
  name: NameSchema,
  description: DescriptionSchema,
  balance: z.string(),
  currency: CurrencySchema,
  isShared: z.boolean(),
  ownerId: SerialNumSchema,
  isActive: z.boolean(),
  createdAt: DateTimeSchema,
  updatedAt: DateTimeSchema.optional().nullable(),
});

export type Account = z.infer<typeof AccountSchema>;
