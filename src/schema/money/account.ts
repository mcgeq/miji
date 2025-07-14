import { z } from 'zod';
import {
  CurrencySchema,
  DateTimeSchema,
  DescriptionSchema,
  NameSchema,
  SerialNumSchema,
} from '../common';
import { AccountTypeSchema } from './money.e';

export const AccountSchema = z.object({
  serialNum: SerialNumSchema,
  name: NameSchema,
  description: DescriptionSchema,
  type: AccountTypeSchema,
  balance: z.string(),
  currency: CurrencySchema,
  isShared: z.boolean(),
  ownerId: SerialNumSchema,
  isActive: z.boolean(),
  color: z.string(),
  createdAt: DateTimeSchema,
  updatedAt: DateTimeSchema.optional().nullable(),
});

export type Account = z.infer<typeof AccountSchema>;
