import { z } from 'zod';
import {
  AmountSchema,
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
  // 扩展字段
  userSerialNum: SerialNumSchema.optional().nullable(), // 关联用户
  avatar: z.string().optional().nullable(), // 头像URL
  colorTag: z.string().optional().nullable(), // 颜色标识
  // 统计字段
  totalPaid: AmountSchema.default(0), // 总支付金额
  totalOwed: AmountSchema.default(0), // 总应分摊金额
  netBalance: AmountSchema.default(0), // 净余额
  transactionCount: z.number().int().min(0).default(0), // 参与交易数
  splitCount: z.number().int().min(0).default(0), // 分摊记录数
  lastActiveAt: DateTimeSchema.optional().nullable(), // 最后活跃时间
  createdAt: DateTimeSchema,
  updatedAt: DateTimeSchema.optional().nullable(),
});

export const FamilyMemberCreateSchema = FamilyMemberSchema.pick({
  name: true,
  role: true,
  isPrimary: true,
  permissions: true,
  userSerialNum: true,
  avatar: true,
  colorTag: true,
}).strict();
export const FamilyMemberUpdateSchema = FamilyMemberCreateSchema.partial();

// 账本类型枚举
export const LedgerTypeSchema = z.enum([
  'PERSONAL', // 个人账本
  'FAMILY', // 家庭账本
  'SHARED', // 共享账本
  'PROJECT', // 项目账本
]);

// 结算周期枚举
export const SettlementCycleSchema = z.enum([
  'WEEKLY', // 每周
  'MONTHLY', // 每月
  'QUARTERLY', // 每季度
  'YEARLY', // 每年
  'MANUAL', // 手动结算
]);

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
  // 扩展字段
  ledgerType: LedgerTypeSchema.default('FAMILY'), // 账本类型
  settlementCycle: SettlementCycleSchema.default('MONTHLY'), // 结算周期
  autoSettlement: z.boolean().default(false), // 自动结算
  settlementDay: z.number().int().min(1).max(31).default(1), // 结算日
  defaultSplitRule: SerialNumSchema.optional().nullable(), // 默认分摊规则
  // 统计字段
  totalIncome: AmountSchema.default(0), // 总收入
  totalExpense: AmountSchema.default(0), // 总支出
  sharedExpense: AmountSchema.default(0), // 共同支出
  personalExpense: AmountSchema.default(0), // 个人支出
  pendingSettlement: AmountSchema.default(0), // 待结算金额
  memberCount: z.number().int().min(0).default(0), // 成员数量
  activeTransactionCount: z.number().int().min(0).default(0), // 活跃交易数
  lastSettlementAt: DateTimeSchema.optional().nullable(), // 最后结算时间
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
  ledgerType: true,
  settlementCycle: true,
  autoSettlement: true,
  settlementDay: true,
  defaultSplitRule: true,
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

// 新增类型导出
export type LedgerType = z.infer<typeof LedgerTypeSchema>;
export type SettlementCycle = z.infer<typeof SettlementCycleSchema>;
