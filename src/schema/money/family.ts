import { z } from 'zod';
import {
  CurrencySchema,
  DateTimeSchema,
  DescriptionSchema,
  NameSchema,
  SerialNumSchema,
} from '../common';
import { MemberUserRoleSchema } from '../userRole';

export const FamilyMemberSchema = z.object({
  serialNum: SerialNumSchema,
  name: NameSchema,
  role: MemberUserRoleSchema,
  isPrimary: z.boolean(),
  permissions: z.string(),
  createdAt: DateTimeSchema,
  updatedAt: DateTimeSchema.optional().nullable(),
});

export const FamilyLedgerSchema = z.object({
  serialNum: SerialNumSchema,
  name: z.string(),
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

export const FamilyLedgerAccountSchema = z.object({
  serialNum: SerialNumSchema,
  familyLedgerSerialNum: SerialNumSchema,
  accountSerialNum: SerialNumSchema,
  createdAt: DateTimeSchema,
  updatedAt: DateTimeSchema.optional().nullable(),
});

export const FamilyLedgerTransactionSchema = z.object({
  serialNum: SerialNumSchema, // Added serialNum
  familyLedgerSerialNum: SerialNumSchema,
  transactionSerialNum: SerialNumSchema,
  createdAt: DateTimeSchema,
  updatedAt: DateTimeSchema.optional().nullable(),
});

export const FamilyLedgerMemberSchema = z.object({
  serialNum: SerialNumSchema, // Added serialNum
  familyLedgerSerialNum: SerialNumSchema,
  familyMemberSerialNum: SerialNumSchema,
  createdAt: DateTimeSchema,
  updatedAt: DateTimeSchema.optional().nullable(),
});

export type FamilyLedger = z.infer<typeof FamilyLedgerSchema>;
export type FamilyMember = z.infer<typeof FamilyMemberSchema>;
export type FamilyLedgerAccount = z.infer<typeof FamilyLedgerAccountSchema>;
export type FamilyLedgerTransaction = z.infer<
  typeof FamilyLedgerTransactionSchema
>;
export type FamilyLedgerMember = z.infer<typeof FamilyLedgerMemberSchema>;
