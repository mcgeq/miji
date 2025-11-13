import { z } from 'zod';
import {
  AmountSchema,
  DateTimeSchema,
  DescriptionSchema,
  SerialNumSchema,
} from '../common';

// 分摊规则类型枚举
export const SplitRuleTypeSchema = z.enum([
  'EQUAL', // 均摊
  'PERCENTAGE', // 按比例
  'FIXED_AMOUNT', // 固定金额
  'WEIGHTED', // 按权重
]);

// 分摊规则配置
export const SplitRuleConfigSchema = z.object({
  serialNum: SerialNumSchema,
  familyLedgerSerialNum: SerialNumSchema,
  name: z.string().min(1).max(100),
  description: DescriptionSchema.optional(),
  ruleType: SplitRuleTypeSchema,
  isTemplate: z.boolean().default(false),
  isActive: z.boolean().default(true),
  participants: z.array(z.object({
    memberSerialNum: SerialNumSchema,
    percentage: z.number().min(0).max(100).optional(),
    fixedAmount: AmountSchema.optional(),
    weight: z.number().min(0).optional(),
  })),
  createdAt: DateTimeSchema,
  updatedAt: DateTimeSchema.optional().nullable(),
});

export const SplitRuleConfigCreateSchema = SplitRuleConfigSchema.pick({
  familyLedgerSerialNum: true,
  name: true,
  description: true,
  ruleType: true,
  isTemplate: true,
  participants: true,
}).strict();

export const SplitRuleConfigUpdateSchema = SplitRuleConfigCreateSchema.partial();

// 分摊记录
export const SplitRecordSchema = z.object({
  serialNum: SerialNumSchema,
  transactionSerialNum: SerialNumSchema,
  familyLedgerSerialNum: SerialNumSchema,
  ruleConfigSerialNum: SerialNumSchema.optional(),
  totalAmount: AmountSchema,
  splitDetails: z.array(z.object({
    memberSerialNum: SerialNumSchema,
    amount: AmountSchema,
    percentage: z.number().min(0).max(100).optional(),
    isPaid: z.boolean().default(false),
    paidAt: DateTimeSchema.optional().nullable(),
  })),
  createdAt: DateTimeSchema,
  updatedAt: DateTimeSchema.optional().nullable(),
});

export const SplitRecordCreateSchema = SplitRecordSchema.pick({
  transactionSerialNum: true,
  familyLedgerSerialNum: true,
  ruleConfigSerialNum: true,
  totalAmount: true,
  splitDetails: true,
}).strict();

export const SplitRecordUpdateSchema = SplitRecordCreateSchema.partial();

// 债务关系
export const DebtRelationSchema = z.object({
  serialNum: SerialNumSchema,
  familyLedgerSerialNum: SerialNumSchema,
  creditorMemberSerialNum: SerialNumSchema, // 债权人
  debtorMemberSerialNum: SerialNumSchema, // 债务人
  amount: AmountSchema,
  description: DescriptionSchema.optional(),
  relatedTransactionSerialNum: SerialNumSchema.optional(),
  relatedSplitRecordSerialNum: SerialNumSchema.optional(),
  isSettled: z.boolean().default(false),
  settledAt: DateTimeSchema.optional().nullable(),
  createdAt: DateTimeSchema,
  updatedAt: DateTimeSchema.optional().nullable(),
});

export const DebtRelationCreateSchema = DebtRelationSchema.pick({
  familyLedgerSerialNum: true,
  creditorMemberSerialNum: true,
  debtorMemberSerialNum: true,
  amount: true,
  description: true,
  relatedTransactionSerialNum: true,
  relatedSplitRecordSerialNum: true,
}).strict();

export const DebtRelationUpdateSchema = DebtRelationCreateSchema.partial();

// 结算记录
export const SettlementRecordSchema = z.object({
  serialNum: SerialNumSchema,
  familyLedgerSerialNum: SerialNumSchema,
  settlementDate: DateTimeSchema,
  periodStart: DateTimeSchema,
  periodEnd: DateTimeSchema,
  settlements: z.array(z.object({
    fromMemberSerialNum: SerialNumSchema,
    toMemberSerialNum: SerialNumSchema,
    amount: AmountSchema,
    relatedDebtSerialNums: z.array(SerialNumSchema),
  })),
  totalSettlementAmount: AmountSchema,
  notes: DescriptionSchema.optional(),
  createdAt: DateTimeSchema,
  updatedAt: DateTimeSchema.optional().nullable(),
});

export const SettlementRecordCreateSchema = SettlementRecordSchema.pick({
  familyLedgerSerialNum: true,
  settlementDate: true,
  periodStart: true,
  periodEnd: true,
  settlements: true,
  totalSettlementAmount: true,
  notes: true,
}).strict();

export const SettlementRecordUpdateSchema = SettlementRecordCreateSchema.partial();

// 分摊结果（用于计算和预览）
export const SplitResultSchema = z.object({
  memberSerialNum: SerialNumSchema,
  memberName: z.string(),
  amount: AmountSchema,
  percentage: z.number().min(0).max(100),
});

// 结算建议
export const SettlementSuggestionSchema = z.object({
  fromMemberSerialNum: SerialNumSchema,
  fromMemberName: z.string(),
  toMemberSerialNum: SerialNumSchema,
  toMemberName: z.string(),
  amount: AmountSchema,
  relatedDebts: z.array(z.object({
    debtSerialNum: SerialNumSchema,
    originalAmount: AmountSchema,
    settledAmount: AmountSchema,
  })),
});

// 成员财务统计
export const MemberFinancialStatsSchema = z.object({
  memberSerialNum: SerialNumSchema,
  memberName: z.string(),
  totalPaid: AmountSchema, // 总支付金额
  totalOwed: AmountSchema, // 总应分摊金额
  netBalance: AmountSchema, // 净余额（正数表示债权，负数表示债务）
  pendingSettlement: AmountSchema, // 待结算金额
  transactionCount: z.number().int().min(0), // 参与交易数
  splitCount: z.number().int().min(0), // 分摊记录数
});

// 家庭账本统计
export const FamilyLedgerStatsSchema = z.object({
  familyLedgerSerialNum: SerialNumSchema,
  totalIncome: AmountSchema,
  totalExpense: AmountSchema,
  sharedExpense: AmountSchema, // 共同支出
  personalExpense: AmountSchema, // 个人支出
  pendingSettlement: AmountSchema, // 待结算总额
  memberCount: z.number().int().min(0),
  activeTransactionCount: z.number().int().min(0),
  memberStats: z.array(MemberFinancialStatsSchema),
});

// 类型导出
export type SplitRuleType = z.infer<typeof SplitRuleTypeSchema>;
export type SplitRuleConfig = z.infer<typeof SplitRuleConfigSchema>;
export type SplitRuleConfigCreate = z.infer<typeof SplitRuleConfigCreateSchema>;
export type SplitRuleConfigUpdate = z.infer<typeof SplitRuleConfigUpdateSchema>;

export type SplitRecord = z.infer<typeof SplitRecordSchema>;
export type SplitRecordCreate = z.infer<typeof SplitRecordCreateSchema>;
export type SplitRecordUpdate = z.infer<typeof SplitRecordUpdateSchema>;

export type DebtRelation = z.infer<typeof DebtRelationSchema>;
export type DebtRelationCreate = z.infer<typeof DebtRelationCreateSchema>;
export type DebtRelationUpdate = z.infer<typeof DebtRelationUpdateSchema>;

export type SettlementRecord = z.infer<typeof SettlementRecordSchema>;
export type SettlementRecordCreate = z.infer<typeof SettlementRecordCreateSchema>;
export type SettlementRecordUpdate = z.infer<typeof SettlementRecordUpdateSchema>;

export type SplitResult = z.infer<typeof SplitResultSchema>;
export type SettlementSuggestion = z.infer<typeof SettlementSuggestionSchema>;
export type MemberFinancialStats = z.infer<typeof MemberFinancialStatsSchema>;
export type FamilyLedgerStats = z.infer<typeof FamilyLedgerStatsSchema>;
