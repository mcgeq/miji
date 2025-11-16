/**
 * 预算分配相关类型定义
 * Phase 6: 家庭预算管理
 */

// ============================================================================
// 枚举类型
// ============================================================================

/**
 * 分配类型
 */
export enum AllocationType {
  /** 固定金额 */
  FIXED_AMOUNT = 'FIXED_AMOUNT',
  /** 百分比 */
  PERCENTAGE = 'PERCENTAGE',
  /** 共享池 */
  SHARED = 'SHARED',
  /** 动态分配 */
  DYNAMIC = 'DYNAMIC',
}

/**
 * 超支限额类型
 */
export enum OverspendLimitType {
  /** 无限制 */
  NONE = 'NONE',
  /** 百分比限制 */
  PERCENTAGE = 'PERCENTAGE',
  /** 固定金额限制 */
  FIXED_AMOUNT = 'FIXED_AMOUNT',
}

/**
 * 分配状态
 */
export enum AllocationStatus {
  /** 活动中 */
  ACTIVE = 'ACTIVE',
  /** 已暂停 */
  PAUSED = 'PAUSED',
  /** 已完成 */
  COMPLETED = 'COMPLETED',
}

/**
 * 预警类型
 */
export enum AlertType {
  /** 预警 */
  WARNING = 'WARNING',
  /** 已超支 */
  EXCEEDED = 'EXCEEDED',
}

// ============================================================================
// 预警配置
// ============================================================================

/**
 * 预警配置
 */
export interface AlertConfig {
  /** 多级预警阈值 */
  thresholds: number[];
  /** 提醒方式 */
  methods: ('notification' | 'email' | 'sms')[];
  /** 接收人 */
  recipients: string[];
  /** 免打扰时段 */
  quietHours?: {
    start: string;
    end: string;
  };
}

// ============================================================================
// 核心接口
// ============================================================================

/**
 * 预算分配响应
 */
export interface BudgetAllocationResponse {
  serialNum: string;
  budgetSerialNum: string;
  categorySerialNum?: string;
  categoryName?: string;
  memberSerialNum?: string;
  memberName?: string;
  allocatedAmount: number;
  usedAmount: number;
  remainingAmount: number;
  usagePercentage: number;
  percentage?: number;
  isExceeded: boolean;

  // 分配规则
  allocationType: AllocationType;
  ruleConfig?: Record<string, any>;

  // 超支控制
  allowOverspend: boolean;
  overspendLimitType?: OverspendLimitType;
  overspendLimitValue?: number;
  canOverspendMore: boolean;

  // 预警设置
  alertEnabled: boolean;
  alertThreshold: number;
  alertConfig?: AlertConfig;
  isWarning: boolean;

  // 管理字段
  priority: number;
  isMandatory: boolean;
  status: AllocationStatus;
  notes?: string;

  createdAt: string;
  updatedAt?: string;
}

/**
 * 创建预算分配请求
 */
export interface BudgetAllocationCreateRequest {
  categorySerialNum?: string;
  memberSerialNum?: string;
  allocatedAmount?: number;
  percentage?: number;

  // 分配规则
  allocationType?: AllocationType;
  ruleConfig?: Record<string, any>;

  // 超支控制
  allowOverspend?: boolean;
  overspendLimitType?: OverspendLimitType;
  overspendLimitValue?: number;

  // 预警设置
  alertEnabled?: boolean;
  alertThreshold?: number;
  alertConfig?: AlertConfig;

  // 管理字段
  priority?: number;
  isMandatory?: boolean;
  notes?: string;
}

/**
 * 更新预算分配请求
 */
export interface BudgetAllocationUpdateRequest {
  allocatedAmount?: number;
  percentage?: number;

  allocationType?: AllocationType;
  ruleConfig?: Record<string, any>;

  allowOverspend?: boolean;
  overspendLimitType?: OverspendLimitType;
  overspendLimitValue?: number;

  alertEnabled?: boolean;
  alertThreshold?: number;
  alertConfig?: AlertConfig;

  priority?: number;
  isMandatory?: boolean;
  status?: AllocationStatus;
  notes?: string;
}

/**
 * 预算使用记录请求
 */
export interface BudgetUsageRequest {
  budgetSerialNum: string;
  allocationSerialNum?: string;
  amount: number;
  transactionSerialNum: string;
}

/**
 * 预算预警响应
 */
export interface BudgetAlertResponse {
  budgetSerialNum: string;
  budgetName: string;
  alertType: AlertType;
  usagePercentage: number;
  remainingAmount: number;
  message: string;
}

/**
 * 预算调整建议
 */
export interface BudgetAdjustmentSuggestion {
  budgetSerialNum: string;
  currentAmount: number;
  suggestedAmount: number;
  reason: string;
  historicalUsage: number;
  projectedUsage: number;
}

// ============================================================================
// 辅助类型
// ============================================================================

/**
 * 分配统计信息
 */
export interface AllocationStatistics {
  totalAllocated: number;
  totalUsed: number;
  totalRemaining: number;
  overallUsagePercentage: number;
  exceededCount: number;
  warningCount: number;
  activeCount: number;
}

/**
 * 成员预算摘要
 */
export interface MemberBudgetSummary {
  memberSerialNum: string;
  memberName: string;
  totalAllocated: number;
  totalUsed: number;
  totalRemaining: number;
  usagePercentage: number;
  allocations: BudgetAllocationResponse[];
}

/**
 * 分类预算摘要
 */
export interface CategoryBudgetSummary {
  categorySerialNum: string;
  categoryName: string;
  totalAllocated: number;
  totalUsed: number;
  totalRemaining: number;
  usagePercentage: number;
  allocations: BudgetAllocationResponse[];
}

/**
 * 预算分配查询选项
 */
export interface BudgetAllocationQueryOptions {
  budgetSerialNum: string;
  status?: AllocationStatus;
  memberSerialNum?: string;
  categorySerialNum?: string;
  isExceeded?: boolean;
  isWarning?: boolean;
}

// ============================================================================
// 表单相关
// ============================================================================

/**
 * 分配表单数据
 */
export interface AllocationFormData {
  // 基础信息
  target: 'member' | 'category' | 'both';
  memberSerialNum?: string;
  categorySerialNum?: string;

  // 金额设置
  amountType: 'fixed' | 'percentage';
  allocatedAmount?: number;
  percentage?: number;

  // 超支控制
  allowOverspend: boolean;
  overspendLimitType: OverspendLimitType;
  overspendLimitValue?: number;

  // 预警设置
  alertEnabled: boolean;
  alertThreshold: number;
  useAdvancedAlert: boolean;
  alertConfig?: AlertConfig;

  // 管理
  priority: number;
  isMandatory: boolean;
  notes?: string;
}

/**
 * 表单验证规则
 */
export interface AllocationFormRules {
  [key: string]: any;
}
