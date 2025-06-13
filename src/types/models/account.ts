import { z } from 'zod';

export const CurrencySchema = z.object({
  code: z.string(),
  symbol: z.string(),
});

export const AccountSchema = z.object({
  serial_num: z.string().length(38),
  name: z.string(),
  description: z.string().max(1000),
  balance: z.string(),
  currency: CurrencySchema,
  is_shared: z.boolean(),
  owner_id: z.string(),
  is_active: z.boolean(),
  created_at: z.string(),
  updated_at: z.string().nullable().optional(),
});

export type Currency = z.infer<typeof CurrencySchema>;
export type Account = z.infer<typeof AccountSchema>;
