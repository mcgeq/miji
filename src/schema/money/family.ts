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

export const FamilyMemberCreateSchema = FamilyMemberSchema.pick({
  name: true,
  role: true,
  isPrimary: true,
  permissions: true,
}).strict();
export const FamilyMemberUpdateSchema = FamilyMemberCreateSchema.partial();

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

export const FamilyLedgerCreateSchema = FamilyLedgerSchema.pick({
  name: true,
  description: true,
  members: true,
  accounts: true,
  transactions: true,
  budgets: true,
}).extend({
  baseCurrency: z.string().length(3),
}).strict();

export const FamilyLedgerUpdateSchema = FamilyLedgerCreateSchema.partial();

export const FamilyLedgerAccountSchema = z.object({
  serialNum: SerialNumSchema,
  familyLedgerSerialNum: SerialNumSchema,
  accountSerialNum: SerialNumSchema,
  createdAt: DateTimeSchema,
  updatedAt: DateTimeSchema.optional().nullable(),
});
export const FamilyLedgerAccountCreateSchema = FamilyLedgerAccountSchema.pick({
  familyLedgerSerialNum: true,
  accountSerialNum: true,
}).strict();
export const FamilyLedgerAccountUpdateSchema = FamilyLedgerAccountCreateSchema.partial();

export const FamilyLedgerTransactionSchema = z.object({
  serialNum: SerialNumSchema, // Added serialNum
  familyLedgerSerialNum: SerialNumSchema,
  transactionSerialNum: SerialNumSchema,
  createdAt: DateTimeSchema,
  updatedAt: DateTimeSchema.optional().nullable(),
});
export const FamilyLedgerTransactionCreateSchema = FamilyLedgerTransactionSchema.pick({
  familyLedgerSerialNum: true,
  transactionSerialNum: true,
}).strict();
export const FamilyLedgerTransactionUpdateSchema = FamilyLedgerTransactionCreateSchema.partial();

export const FamilyLedgerMemberSchema = z.object({
  serialNum: SerialNumSchema, // Added serialNum
  familyLedgerSerialNum: SerialNumSchema,
  familyMemberSerialNum: SerialNumSchema,
  createdAt: DateTimeSchema,
  updatedAt: DateTimeSchema.optional().nullable(),
});
export const FamilyLedgerMemberCreateSchema = FamilyLedgerMemberSchema.pick({
  familyLedgerSerialNum: true,
  familyMemberSerialNum: true,
}).strict();
export const FamilyLedgerMemberUpdateSchema = FamilyLedgerMemberCreateSchema.partial();

export type FamilyMember = z.infer<typeof FamilyMemberSchema>;
export type FamilyMemberCreate = z.infer<typeof FamilyMemberCreateSchema>;
export type FamilyMemberUpdate = z.infer<typeof FamilyMemberUpdateSchema>;

export type FamilyLedger = z.infer<typeof FamilyLedgerSchema>;
export type FamilyLedgerCreate = z.infer<typeof FamilyLedgerCreateSchema>;
export type FamilyLedgerUpdate = z.infer<typeof FamilyLedgerUpdateSchema>;

export type FamilyLedgerAccount = z.infer<typeof FamilyLedgerAccountSchema>;
export type FamilyLedgerAccountCreate = z.infer<typeof FamilyLedgerAccountCreateSchema>;
export type FamilyLedgerAccountUpdate = z.infer<typeof FamilyLedgerAccountUpdateSchema>;

export type FamilyLedgerTransaction = z.infer<
  typeof FamilyLedgerTransactionSchema
>;
export type FamilyLedgerTransactionCreate = z.infer<typeof FamilyLedgerTransactionCreateSchema>;
export type FamilyLedgerTransactionUpdate = z.infer<typeof FamilyLedgerTransactionUpdateSchema>;

export type FamilyLedgerMember = z.infer<typeof FamilyLedgerMemberSchema>;
export type FamilyLedgerMemberCreate = z.infer<typeof FamilyLedgerMemberCreateSchema>;
export type FamilyLedgerMemberUpdate = z.infer<typeof FamilyLedgerMemberUpdateSchema>;
