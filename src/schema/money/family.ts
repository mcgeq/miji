import { z } from 'zod';
import {
  CurrencySchema,
  DateTimeSchema,
  DescriptionSchema,
  NameSchema,
  SerialNumSchema,
} from '../common';
import { UserRoleSchema } from '../userRole';

export const FamilyMemberSchema = z.object({
  serialNum: SerialNumSchema,
  name: NameSchema,
  role: UserRoleSchema,
  isPrimary: z.boolean(),
  permissions: z.string(),
  createdAt: DateTimeSchema,
  updatedAt: DateTimeSchema.optional().nullable(),
});

export const FamilyLedgerSchema = z.object({
  serialNum: SerialNumSchema,
  description: DescriptionSchema,
  baseCurrency: CurrencySchema,
  members: z.array(FamilyMemberSchema),
  accounts: z.string(),
  transactions: z.string(),
  budgets: z.string(),
  auditLogs: z.string(),
  createdAt: DateTimeSchema,
  updatedAt: DateTimeSchema.optional().nullable(),
});

export type FamilyLedger = z.infer<typeof FamilyLedgerSchema>;
export type FamilyMember = z.infer<typeof FamilyMemberSchema>;
