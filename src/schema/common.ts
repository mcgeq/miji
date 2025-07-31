import { z } from 'zod';

export const passwordRegex =
  /^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$/;
export const alphanumericRegex = /^[a-z0-9]+$/;
export const ColorHexRegex = /^0x[0-9a-fA-F]{3,8}$/;
export const NullableStringSchema = z.string().nullable();
export const SerialNumSchema = z
  .string()
  .length(38, { error: 'Serial number must be 38 character.' })
  .regex(alphanumericRegex, {
    error: 'Serial number must contain only letters and numbers',
  });

export const NameSchema = z.string().min(3).max(20);

export const DescriptionSchema = z.string().max(1000);

export const DateTimeSchema = z.iso.datetime({
  offset: true,
  local: true,
  precision: 6,
});

export const DateSchema = z.iso.date();
export const TimesSchema = z.iso.time();
export const CurrencySchema = z.object({
  locale: z.string(),
  code: z.string().length(3),
  symbol: z.string(),
  createdAt: DateTimeSchema,
  updatedAt: DateTimeSchema.optional().nullable(),
});

export type Currency = z.infer<typeof CurrencySchema>;
export const weekdays = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
] as const;
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
    day: z.union([z.number().min(1).max(31), z.literal('last')]), // 指定几号 或 最后一天
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

export type RepeatPeriod = z.infer<typeof RepeatPeriodSchema>;

export type RepeatPeriodType = RepeatPeriod['type'];

export type Weekday = (typeof weekdays)[number];

export const ReminderTypeSchema = z.enum(['Notification', 'Email', 'Popup']);
export type ReminderType = z.infer<typeof ReminderTypeSchema>;

export const TransactionStatusSchema = z.enum([
  'Pending',
  'Completed',
  'Reversed',
]);
export type TransactionStatus = z.infer<typeof TransactionStatusSchema>;

export const TransactionTypeSchema = z.enum(['Income', 'Expense', 'Transfer']);
export type TransactionType = z.infer<typeof TransactionTypeSchema>;

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
export type Category = z.infer<typeof CategorySchema>;

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
export type SubCategory = z.infer<typeof SubCategorySchema>;

// todos
// Exercise Intensity
export const ExerciseIntensitySchema = z.enum([
  'None',
  'Light',
  'Medium',
  'Heavy',
]);
export type ExerciseIntensity = z.infer<typeof ExerciseIntensitySchema>;

// Flow Level
export const FlowLevelSchema = z.enum(['Light', 'Medium', 'Heavy']);
export type FlowLevel = z.infer<typeof FlowLevelSchema>;

// Intensity
export const IntensitySchema = z.enum(['Light', 'Medium', 'Heavy']);
export type Intensity = z.infer<typeof IntensitySchema>;

// Symptoms Type
export const SymptomsTypeSchema = z.enum(['Pain', 'Fatigue', 'MoodSwing']);
export type SymptomsType = z.infer<typeof SymptomsTypeSchema>;

// 优先级 Priority
export const PrioritySchema = z.enum(['Low', 'Medium', 'High', 'Urgent']);
export type Priority = z.infer<typeof PrioritySchema>;

// 状态 Status
export const StatusSchema = z.enum([
  'NotStarted',
  'InProgress',
  'Completed',
  'Cancelled',
  'Overdue',
]);
export type Status = z.infer<typeof StatusSchema>;

export const FilterBtnSchema = z.enum(['YESTERDAY', 'TODAY', 'TOMORROW']);
export type FilterBtn = z.infer<typeof FilterBtnSchema>;

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

export interface SortOptions {
  customOrderBy?: string; // 新增：完整排序 SQL
  sortBy?: string;
  sortDir?: 'ASC' | 'DESC';
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
  income: {
    total: number;
    transfer: number;
  };
  expense: {
    total: number;
    transfer: number;
  };
  transfer?: {
    income: number;
    expense: number;
  };
}
