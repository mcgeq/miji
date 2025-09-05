import { z } from 'zod';
import type { ZodObject, ZodType } from 'zod';

export const passwordRegex =
  /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$/;
export const alphanumericRegex = /^[a-z0-9]+$/;
export const ColorHexRegex = /^0x[0-9a-fA-F]{3,8}$/;

/**
 * 通用类型转换工具（Zod 4 兼容版）：从源对象中提取目标 Zod Schema 定义的字段，生成目标类型对象
 * @param source 源对象（需包含目标 Schema 的所有字段）
 * @param targetSchema 目标类型的 Zod Schema（定义需要提取的字段）
 * @returns 转换后的目标类型对象（类型为 z.infer<T>）
 */
export function extractFields<
  S extends object,
  T extends ZodObject<{ [K in keyof U]: ZodType<unknown> }>,
  U = z.infer<T>,
>(source: S, targetSchema: T): z.infer<T> {
  // 1. 提取目标 Schema 的所有字段名（Zod 4 中 shape 是 Record<string, ZodTypeAny>）
  const targetKeys = Object.keys(targetSchema.shape) as (keyof z.infer<T>)[];

  // 2. 运行时校验：源对象必须包含所有目标字段（Zod 4 严格模式需要）
  targetKeys.forEach(key => {
    if (!(key in source)) {
      throw new Error(`源对象缺少目标字段: ${String(key)}`);
    }
  });

  // 3. 提取目标字段的值（Zod 4 要求显式类型兼容断言）
  const extracted: Partial<z.infer<T>> = {};
  targetKeys.forEach(key => {
    // 显式断言 key 在源对象和目标类型中的合法性（Zod 4 类型系统更严格）
    const sourceKey = key as keyof S;
    const targetKey = key as keyof z.infer<T>;
    // 提取值并断言类型兼容（Zod 4 会自动校验类型，此处仅为 TypeScript 类型提示）
    extracted[targetKey] = source[
      sourceKey
    ] as unknown as z.infer<T>[typeof targetKey];
  });

  // 4. 通过 Zod 4 的 parse 方法最终校验并返回（自动推导 z.infer<T>）
  return targetSchema.parse(extracted);
}

// ======================
// 基础数据类型定义
// ======================
export const NullableStringSchema = z.string().nullable();
export const SerialNumSchema = z
  .string()
  .length(38, { error: 'Serial number must be 38 character.' })
  .regex(alphanumericRegex, {
    error: 'Serial number must contain only letters and numbers',
  });

export const NameSchema = z
  .string()
  .min(2, { error: 'Name must be at least 3 characters long' })
  .max(20, { error: 'Name must be no more than 20 characters long' });

export const DescriptionSchema = z.string().max(1000, {
  error: 'Description must be no more than 1000 characters long',
});

export const DateTimeSchema = z.iso.datetime({
  offset: true,
  local: true,
  precision: 3,
});

export const DateSchema = z.iso.date();
export const TimesSchema = z.iso.time();

// ======================
// 货币与金融模块
// ======================
export const CurrencySchema = z.object({
  locale: z.string(),
  code: z.string().length(3),
  symbol: z.string(),
  createdAt: DateTimeSchema,
  updatedAt: DateTimeSchema.optional().nullable(),
});
export const CurrencyCreateSchema = CurrencySchema.pick({
  locale: true,
  code: true,
  symbol: true,
}).strict();
export const CurrencyUpdateSchema = CurrencySchema.pick({
  locale: true,
  symbol: true,
}).partial();

export const AccountBalanceSummarySchema = z.object({
  // 分类账户余额
  bankSavingsBalance: z.number(),
  cashBalance: z.number(),
  creditCardBalance: z.number(),
  investmentBalance: z.number(),
  alipayBalance: z.number(),
  weChatBalance: z.number(),
  cloudQuickPassBalance: z.number(),
  otherBalance: z.number(),

  // 总额统计
  totalBalance: z.number(),
  adjustedNetWorth: z.number(),
  totalAssets: z.number(),

  // 额外元数据
  accountCount: z.number(),
  currency: z.string(),
});

// ======================
// 预算与周期模块
// ======================
export const weekdays = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
] as const;
export const MonthlyDaySchema = z.union([
  z.number().int().min(1).max(31),
  z.literal('Last'),
]);
export const RepeatPeriodSchema = z.discriminatedUnion('type', [
  z.object({
    type: z.literal('None'),
  }),
  z.object({
    type: z.literal('Daily'),
    interval: z.number().min(1).default(1), // 每 N 天
  }),
  z.object({
    type: z.literal('Weekly'),
    interval: z.number().min(1).default(1), // 每 N 周
    daysOfWeek: z.array(z.enum(weekdays)).nonempty(),
  }),
  z.object({
    type: z.literal('Monthly'),
    interval: z.number().min(1).default(1), // 每 N 月
    day: MonthlyDaySchema, // 指定几号 或 最后一天
  }),
  z.object({
    type: z.literal('Yearly'),
    interval: z.number().min(1).default(1), // 每 N 年
    month: z.number().min(1).max(12),
    day: z.number().min(1).max(31),
  }),
  z.object({
    type: z.literal('Custom'),
    description: z.string().min(1), // 自定义描述
  }),
]);

export const AlertThresholdSchema = z.union([
  z.object({
    type: z.literal('Percentage'),
    value: z.number().min(0).max(100),
  }),
  z.object({
    type: z.literal('FixedAmount'),
    value: z.number().min(0),
  }),
]);

export const BudgetTypeSchema = z.enum([
  'Standard',
  'SavingGoal',
  'DebtRepayment',
  'Project',
  'Investment',
]);
export const SharingPermissionSchema = z.enum([
  'ViewOnly',
  'Contribute',
  'Manage',
]);
export const NotificationTypeSchema = z.enum([
  'Notification',
  'Email',
  'Popup',
]);
export const ReminderTypeSchema = z.enum([
  'ThresholdAlert',
  'PeriodEnd',
  'ResetReminder',
  'ContributionDue',
]);
export const ReminderSchema = z.object({
  reminderType: ReminderTypeSchema,
  daysBefore: z.number().int().min(1).max(31).optional(),
  threshold: z.number().min(0).optional(),
});
export const RolloverRecordSchema = z.object({
  fromPeriod: DateSchema,
  toPeriod: DateSchema,
  amount: z.number(),
  timestamp: DateTimeSchema,
});
export const SharingSettingsSchema = z.object({
  sharedWith: z.array(SerialNumSchema),
  permissionLevel: SharingPermissionSchema,
});

export const AttachmentSchema = z.object({
  serialNum: SerialNumSchema,
  name: z.string().min(1),
  mimeType: z.string().min(1),
  size: z.number().int().min(0),
  uploadedAt: DateTimeSchema,
});

export const TransactionStatusSchema = z.enum([
  'Pending',
  'Completed',
  'Reversed',
]);

export const TransactionTypeSchema = z.enum(['Income', 'Expense', 'Transfer']);

export const CategorySchema = z.enum([
  'Food', // 餐饮
  'Transport', // 交通
  'Entertainment', // 娱乐
  'Utilities', // 公共事业（水电燃气）
  'Shopping', // 购物
  'Salary', // 工资收入
  'Investment', // 投资收入（股票、基金、房产等）
  'Transfer', // 转账（非收入/支出）
  'Education', // 教育支出（学费、书籍、培训）
  'Healthcare', // 医疗支出（门诊、药品、保险）
  'Insurance', // 保险支出（健康险、车险、人寿险）
  'Savings', // 储蓄收入（银行利息、定期存款）
  'Gift', // 礼品支出/收入（赠送/收到礼物）
  'Loan', // 贷款相关（借款/还款）
  'Business', // 商业支出（办公用品、差旅费）
  'Travel', // 出行（旅游、机票、酒店）
  'Charity', // 慈善捐赠
  'Subscription', // 订阅费（Netflix、会员费）
  'Pet', // 宠物相关（食品、医疗）
  'Home', // 家居用品（家具、装修）
  'Others', // 其他未分类项
]);

export const SubCategorySchema = z.enum([
  // Food（餐饮）
  'Restaurant', // 餐厅用餐
  'Groceries', // 日常杂货
  'Snacks', // 零食小吃

  // Transport（交通）
  'Bus', // 公交车费用
  'Taxi', // 出租车费用
  'Fuel', // 燃油费
  'Train', // 火车票
  'Flight', // 飞机票
  'Parking', // 停车费

  // Entertainment（娱乐）
  'Movies', // 电影票
  'Concerts', // 音乐会
  'Sports', // 体育赛事
  'Gaming', // 游戏消费
  'Streaming', // 流媒体订阅（如 Netflix）

  // Utilities（公共事业）
  'Electricity', // 电费
  'Water', // 水费
  'Gas', // 燃气费
  'Internet', // 网络费
  'Cable', // 有线电视费

  // Shopping（购物）
  'Clothing', // 服装
  'Electronics', // 电子产品
  'HomeDecor', // 家居装饰
  'Furniture', // 家具
  'Toys', // 玩具

  // Salary（工资）
  'MonthlySalary', // 月薪
  'Bonus', // 奖金
  'Overtime', // 加班费
  'Commission', // 提成

  // Investment（投资）
  'StockDividend', // 股票分红
  'BondInterest', // 债券利息
  'PropertyRental', // 房产租金收入
  'CryptoIncome', // 加密货币收益

  // Transfer（转账）
  'AccountTransfer', // 账户间转账
  'LoanRepayment', // 贷款还款
  'InvestmentWithdrawal', // 投资取款

  // Education（教育）
  'Tuition', // 学费
  'Books', // 教材费用
  'Courses', // 培训课程
  'SchoolSupplies', // 学校用品（如文具）

  // Healthcare（医疗）
  'DoctorVisit', // 门诊费用
  'Medications', // 药品费用
  'Hospitalization', // 住院费用
  'Dental', // 牙科费用
  'InsurancePremiums', // 医疗保险保费

  // Insurance（保险）
  'HealthInsurance', // 健康险
  'CarInsurance', // 车险
  'LifeInsurance', // 人寿险

  // Savings（储蓄）
  'BankInterest', // 银行利息
  'FixedDeposit', // 定期存款利息

  // Gift（礼品）
  'GiftSent', // 送出的礼物
  'GiftReceived', // 收到的礼物

  // Loan（贷款）
  'Mortgage', // 房贷还款
  'PersonalLoan', // 个人贷款
  'CreditCardPayment', // 信用卡还款

  // Business（商业）
  'OfficeSupplies', // 办公用品
  'TravelExpenses', // 商务差旅费用
  'Marketing', // 市场营销费用
  'ConsultingFees', // 咨询费

  // Travel（出行）
  'Hotel', // 酒店住宿
  'TourPackage', // 旅游套餐
  'Activities', // 旅游活动费用

  // Charity（慈善）
  'Donation', // 慈善捐赠

  // Subscription（订阅）
  'Netflix', // Netflix 订阅
  'Spotify', // Spotify 订阅
  'Software', // 软件订阅费

  // Pet（宠物）
  'PetFood', // 宠物食品
  'PetVet', // 宠物医疗
  'PetToys', // 宠物玩具

  // Home（家居）
  'Furniture', // 家具（与 Shopping 中的 Furniture 区分）
  'Renovation', // 家居装修
  'HomeMaintenance', // 家居维修

  // Others（其他）
  'Other', // 其他未分类项
]);

// todos
// Exercise Intensity
export const ExerciseIntensitySchema = z.enum([
  'None',
  'Light',
  'Medium',
  'Heavy',
]);

// Flow Level
export const FlowLevelSchema = z.enum(['Light', 'Medium', 'Heavy']);

export const IntensitySchema = z.enum(['Light', 'Medium', 'Heavy']);
export const SymptomsTypeSchema = z.enum(['Pain', 'Fatigue', 'MoodSwing']);
export const PrioritySchema = z.enum(['Low', 'Medium', 'High', 'Urgent']);

// 状态 Status
export const StatusSchema = z.enum([
  'NotStarted',
  'InProgress',
  'Completed',
  'Cancelled',
  'Overdue',
]);

export const FilterBtnSchema = z.enum(['YESTERDAY', 'TODAY', 'TOMORROW']);

export interface DateRange {
  start?: string;
  end?: string;
}

export interface QueryFilters {
  status?: Status;
  createdAtRange?: DateRange;
  completedAtRange?: DateRange;
  dueAtRange?: DateRange;
  orQuery?: boolean;
}

// SortDirection 枚举，匹配后端的 SortDirection
export enum SortDirection {
  Asc = 'Asc',
  Desc = 'Desc',
}

export interface SortOptions {
  customOrderBy?: string; // 新增：完整排序 SQL
  sortBy?: string;
  sortDir?: SortDirection;
  desc?: boolean;
}

export interface UsageDetail {
  count: number;
  serialNums: string[];
}

export interface DefaultColors {
  code: string;
  nameEn: string;
  nameZh: string;
}

export interface IncomeExpense {
  income: AccountTypeSummary;
  expense: AccountTypeSummary;
  transfer: TransferSummary;
}

export interface AccountTypeSummary {
  total: number;
  transfer: number;
  bankSavings?: number;
  cash?: number;
  creditCard?: number;
  investment?: number;
  alipay?: number;
  wechat?: number;
  cloudQuickPass?: number;
  other?: number;
}

export interface TransferSummary {
  income: number;
  expense: number;
}

// 操作类型枚举定义
export const OperationTypeSchema = z.union([
  z.literal('INSERT'),
  z.literal('UPDATE'),
  z.literal('DELETE'),
  z.literal('SOFT_DELETE'),
  z.literal('RESTORE'),
]);

// 主日志架构
export const OperationLogSchema = z.object({
  serial_num: z.string().length(36).describe('UUID 格式的日志唯一标识'),
  recorded_at: DateTimeSchema.describe('ISO 8601 格式的时间戳'),
  operation: OperationTypeSchema.describe('操作类型'),
  table_name: z.string().min(1).describe('操作的目标表'),
  record_id: z.string().min(1).describe('操作的目标记录 ID'),
  actor_id: z.string().min(1).describe('执行操作的主体标识'),

  // JSON 格式的变更数据（可为空）
  changes_json: z.string().optional(),

  // JSON 格式的数据快照（可为空）
  snapshot_json: z.string().optional(),
  // 设备 ID（可为空）
  device_id: z
    .string()
    .max(100)
    .nullable()
    .optional()
    .default(null)
    .describe('操作设备的标识符'),
});

export interface PageQuery<F> {
  currentPage: number;
  pageSize: number;
  sortOptions: SortOptions;
  filter: F;
}

export type MonthlyDay = z.infer<typeof MonthlyDaySchema>;
export type AlertThreshold = z.infer<typeof AlertThresholdSchema>;
export type RepeatPeriod = z.infer<typeof RepeatPeriodSchema>;
export type RepeatPeriodType = RepeatPeriod['type'];
export type Weekday = (typeof weekdays)[number];
export type SharingPermission = z.infer<typeof SharingPermissionSchema>;
export type BudgetType = z.infer<typeof BudgetTypeSchema>;
export type NotificationType = z.infer<typeof NotificationTypeSchema>;
export type ReminderType = z.infer<typeof ReminderTypeSchema>;
export type Reminder = z.infer<typeof ReminderSchema>;
export type RolloverRecord = z.infer<typeof RolloverRecordSchema>;
export type SharingSettings = z.infer<typeof SharingSettingsSchema>;
export type Attachment = z.infer<typeof AttachmentSchema>;
export type TransactionStatus = z.infer<typeof TransactionStatusSchema>;
export type TransactionType = z.infer<typeof TransactionTypeSchema>;
export type Category = z.infer<typeof CategorySchema>;
export type OperationType = z.infer<typeof OperationTypeSchema>;
export type OperationLog = z.infer<typeof OperationLogSchema>;
export type FilterBtn = z.infer<typeof FilterBtnSchema>;
export type Status = z.infer<typeof StatusSchema>;
export type Priority = z.infer<typeof PrioritySchema>;
export type SymptomsType = z.infer<typeof SymptomsTypeSchema>;
export type FlowLevel = z.infer<typeof FlowLevelSchema>;
export type Intensity = z.infer<typeof IntensitySchema>;
export type ExerciseIntensity = z.infer<typeof ExerciseIntensitySchema>;
export type SubCategory = z.infer<typeof SubCategorySchema>;
export type Currency = z.infer<typeof CurrencySchema>;
export type CurrencyCrate = z.infer<typeof CurrencyCreateSchema>;
export type CurrencyUpdate = z.infer<typeof CurrencyUpdateSchema>;
export type AccountBalanceSummary = z.infer<typeof AccountBalanceSummarySchema>;
