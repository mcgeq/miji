import { z } from 'zod/v4';
import {
  CurrencySchema,
  DateTimeSchema,
  DescriptionSchema,
  NameSchema,
  SerialNumSchema,
} from '../common';
import { UserRoleSchema } from '../userRole';

export const FamilyMemberSchema = z.object({
  serial_num: SerialNumSchema,
  name: NameSchema,
  role: UserRoleSchema,
  is_primary: z.boolean(),
  permissions: z.string(),
  created_at: DateTimeSchema,
  updated_at: DateTimeSchema.optional().nullable(),
});

export const FamilyLedgerSchema = z.object({
  serial_num: SerialNumSchema,
  description: DescriptionSchema,
  base_currency: CurrencySchema,
  members: z.array(FamilyMemberSchema),
  accounts: z.string(),
  transactions: z.string(),
  budgets: z.string(),
  audit_logs: z.string(),
  created_at: DateTimeSchema,
  updated_at: DateTimeSchema.optional().nullable(),
});

export type FamilyLedger = z.infer<typeof FamilyLedgerSchema>;
export type FamilyMember = z.infer<typeof FamilyMemberSchema>;
