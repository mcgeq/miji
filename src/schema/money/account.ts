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
  ownerId: SerialNumSchema,
  isActive: z.boolean(),
  color: z.string(),
  createdAt: DateTimeSchema,
  updatedAt: DateTimeSchema.optional().nullable(),
});

export const AccountSchema = BaseAccountFields.extend({
  SerialNum: SerialNumSchema,
}).strict();

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

export const UpdateAccountRequestSchema = BaseAccountFields.pick({
  serialNum: true,
  name: true,
  description: true,
  type: true,
  isShared: true,
  ownerId: true,
  color: true,
  isActive: true,
  initialBalance: true,
})
  .extend({
    currency: z.string().length(3),
  })
  .strict();

export const BaseAccountResponseSchema = BaseAccountFields.extend({
  currency: CurrencySchema,
}).strict();

export type Account = z.infer<typeof AccountSchema>;
export type CreateAccountRequest = z.infer<typeof CreateAccountRequestSchema>;
export type UpdateAccountRequest = z.infer<typeof UpdateAccountRequestSchema>;
export type AccountResponseWithRelations = z.infer<
  typeof BaseAccountResponseSchema
>;
