import { z } from 'zod/v4';
import {
  CurrencySchema,
  DateTimeSchema,
  DescriptionSchema,
  NameSchema,
  SerialNumSchema,
} from '../common';

export const AccountSchema = z.object({
  serial_num: SerialNumSchema,
  name: NameSchema,
  description: DescriptionSchema,
  balance: z.string(),
  currency: CurrencySchema,
  is_shared: z.boolean(),
  owner_id: SerialNumSchema,
  is_active: z.boolean(),
  created_at: DateTimeSchema,
  updated_at: DateTimeSchema.optional().nullable(),
});

export type Account = z.infer<typeof AccountSchema>;
