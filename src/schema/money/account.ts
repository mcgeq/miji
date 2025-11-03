import { z } from 'zod';
import {
  CurrencySchema,
  DateTimeSchema,
  DescriptionSchema,
  NameSchema,
  SerialNumSchema,
} from '../common';
import { AccountTypeSchema } from './money.e';

export const BaseAccountFields = z.object({
  serialNum: SerialNumSchema,
  name: NameSchema,
  description: DescriptionSchema,
  type: AccountTypeSchema,
  balance: z.string(),
  initialBalance: z.string(),
  isShared: z.boolean(),
  ownerId: SerialNumSchema.nullable().optional(),
  isActive: z.boolean(),
  isVirtual: z.boolean().default(false), // 为旧数据提供默认值，migration 已设置默认值
  color: z.string().nullable().optional(),
  createdAt: DateTimeSchema,
  updatedAt: DateTimeSchema.optional().nullable(),
});

export const AccountSchema = BaseAccountFields.extend({
  currency: CurrencySchema,
});

export const CreateAccountRequestSchema = BaseAccountFields.pick({
  name: true,
  description: true,
  type: true,
  initialBalance: true,
  isShared: true,
  ownerId: true,
  isActive: true,
  color: true,
})
  .extend({
    currency: z.string().length(3),
  })
  .strict();

export const UpdateAccountRequestSchema = CreateAccountRequestSchema.partial();

export type Account = z.infer<typeof AccountSchema>;
export type CreateAccountRequest = z.infer<typeof CreateAccountRequestSchema>;
export type UpdateAccountRequest = z.infer<typeof UpdateAccountRequestSchema>;
