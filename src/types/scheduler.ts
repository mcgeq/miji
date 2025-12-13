/**
 * 调度器配置相关类型定义
 */

/**
 * 调度器任务类型
 */
export enum SchedulerTaskType {
  /** 交易处理 */
  TransactionProcess = 'TransactionProcess',
  /** 待办自动创建 */
  TodoAutoCreate = 'TodoAutoCreate',
  /** 待办提醒检查 */
  TodoReminderCheck = 'TodoReminderCheck',
  /** 账单提醒检查 */
  BillReminderCheck = 'BillReminderCheck',
  /** 经期提醒 */
  PeriodReminder = 'PeriodReminder',
  /** 排卵期提醒 */
  OvulationReminder = 'OvulationReminder',
  /** PMS提醒 */
  PmsReminder = 'PmsReminder',
  /** 预算自动创建 */
  BudgetAutoCreate = 'BudgetAutoCreate',
}

/**
 * 任务类型标签映射
 */
export const TASK_TYPE_LABELS: Record<SchedulerTaskType, string> = {
  [SchedulerTaskType.TransactionProcess]: '交易处理',
  [SchedulerTaskType.TodoAutoCreate]: '待办自动创建',
  [SchedulerTaskType.TodoReminderCheck]: '待办提醒检查',
  [SchedulerTaskType.BillReminderCheck]: '账单提醒检查',
  [SchedulerTaskType.PeriodReminder]: '经期提醒',
  [SchedulerTaskType.OvulationReminder]: '排卵期提醒',
  [SchedulerTaskType.PmsReminder]: 'PMS提醒',
  [SchedulerTaskType.BudgetAutoCreate]: '预算自动创建',
};

/**
 * 任务类型描述
 */
export const TASK_TYPE_DESCRIPTIONS: Record<SchedulerTaskType, string> = {
  [SchedulerTaskType.TransactionProcess]: '自动处理分期交易到期提醒',
  [SchedulerTaskType.TodoAutoCreate]: '根据规则自动创建重复待办',
  [SchedulerTaskType.TodoReminderCheck]: '检查并发送待办事项提醒',
  [SchedulerTaskType.BillReminderCheck]: '检查并发送账单到期提醒',
  [SchedulerTaskType.PeriodReminder]: '在经期开始前几天发送提醒',
  [SchedulerTaskType.OvulationReminder]: '在排卵期到来时发送提醒',
  [SchedulerTaskType.PmsReminder]: '在可能出现经前症状时发送提醒',
  [SchedulerTaskType.BudgetAutoCreate]: '根据规则自动创建周期预算',
};

/**
 * 任务类型图标
 */
export const TASK_TYPE_ICONS: Record<SchedulerTaskType, string> = {
  [SchedulerTaskType.TransactionProcess]: '💰',
  [SchedulerTaskType.TodoAutoCreate]: '📝',
  [SchedulerTaskType.TodoReminderCheck]: '⏰',
  [SchedulerTaskType.BillReminderCheck]: '📅',
  [SchedulerTaskType.PeriodReminder]: '🌸',
  [SchedulerTaskType.OvulationReminder]: '💝',
  [SchedulerTaskType.PmsReminder]: '💆‍♀️',
  [SchedulerTaskType.BudgetAutoCreate]: '💳',
};

/**
 * 平台类型
 */
export type PlatformType = 'desktop' | 'mobile' | 'android' | 'ios';

/**
 * 调度器配置
 */
export interface SchedulerConfig {
  /** 配置ID */
  serialNum: string;
  /** 用户ID（null表示全局配置） */
  userSerialNum?: string;
  /** 任务类型 */
  taskType: SchedulerTaskType;
  /** 是否启用 */
  enabled: boolean;
  /** 执行间隔（秒） */
  intervalSeconds: number;
  /** 最大重试次数 */
  maxRetryCount: number;
  /** 重试延迟（秒） */
  retryDelaySeconds: number;
  /** 平台限定 */
  platform?: PlatformType;
  /** 电量阈值（移动端） */
  batteryThreshold?: number;
  /** 是否需要网络 */
  networkRequired: boolean;
  /** 仅Wi-Fi */
  wifiOnly: boolean;
  /** 活动时段开始 */
  activeHoursStart?: string;
  /** 活动时段结束 */
  activeHoursEnd?: string;
  /** 优先级 1-10 */
  priority: number;
  /** 配置描述 */
  description?: string;
  /** 是否为默认配置 */
  isDefault: boolean;
  /** 创建时间 */
  createdAt: string;
  /** 更新时间 */
  updatedAt: string;
}

/**
 * 调度器配置更新请求
 */
export interface SchedulerConfigUpdateRequest {
  /** 配置ID */
  serialNum: string;
  /** 是否启用 */
  enabled?: boolean;
  /** 执行间隔（秒） */
  intervalSeconds?: number;
  /** 最大重试次数 */
  maxRetryCount?: number;
  /** 重试延迟（秒） */
  retryDelaySeconds?: number;
  /** 电量阈值 */
  batteryThreshold?: number;
  /** 是否需要网络 */
  networkRequired?: boolean;
  /** 仅Wi-Fi */
  wifiOnly?: boolean;
  /** 活动时段开始 */
  activeHoursStart?: string;
  /** 活动时段结束 */
  activeHoursEnd?: string;
  /** 优先级 */
  priority?: number;
  /** 配置描述 */
  description?: string;
}

/**
 * 调度器配置创建请求
 */
export interface SchedulerConfigCreateRequest {
  /** 用户ID */
  userSerialNum?: string;
  /** 任务类型 */
  taskType: SchedulerTaskType;
  /** 是否启用 */
  enabled: boolean;
  /** 执行间隔（秒） */
  intervalSeconds: number;
  /** 平台限定 */
  platform?: PlatformType;
  /** 最大重试次数 */
  maxRetryCount?: number;
  /** 重试延迟（秒） */
  retryDelaySeconds?: number;
  /** 电量阈值 */
  batteryThreshold?: number;
  /** 是否需要网络 */
  networkRequired?: boolean;
  /** 仅Wi-Fi */
  wifiOnly?: boolean;
  /** 活动时段开始 */
  activeHoursStart?: string;
  /** 活动时段结束 */
  activeHoursEnd?: string;
  /** 优先级 */
  priority?: number;
  /** 配置描述 */
  description?: string;
}

/**
 * 间隔范围配置
 */
export interface IntervalRange {
  min: number;
  max: number;
  step: number;
  default: number;
}

/**
 * 任务类型的间隔范围
 */
export const TASK_INTERVAL_RANGES: Record<SchedulerTaskType, IntervalRange> = {
  [SchedulerTaskType.TransactionProcess]: {
    min: 300, // 5分钟
    max: 86400, // 24小时
    step: 300, // 5分钟
    default: 7200, // 2小时
  },
  [SchedulerTaskType.TodoAutoCreate]: {
    min: 300,
    max: 86400,
    step: 300,
    default: 7200,
  },
  [SchedulerTaskType.TodoReminderCheck]: {
    min: 60, // 1分钟
    max: 3600, // 1小时
    step: 60, // 1分钟
    default: 60, // 桌面端1分钟，移动端在组件中判断
  },
  [SchedulerTaskType.BillReminderCheck]: {
    min: 60,
    max: 3600,
    step: 60,
    default: 60,
  },
  [SchedulerTaskType.PeriodReminder]: {
    min: 3600, // 1小时
    max: 86400, // 1天
    step: 3600, // 1小时
    default: 43200, // 12小时
  },
  [SchedulerTaskType.OvulationReminder]: {
    min: 3600, // 1小时
    max: 86400, // 1天
    step: 3600, // 1小时
    default: 43200, // 12小时
  },
  [SchedulerTaskType.PmsReminder]: {
    min: 3600, // 1小时
    max: 86400, // 1天
    step: 3600, // 1小时
    default: 43200, // 12小时
  },
  [SchedulerTaskType.BudgetAutoCreate]: {
    min: 300,
    max: 86400,
    step: 300,
    default: 7200,
  },
};

/**
 * 格式化间隔时间
 * @param seconds 秒数
 * @returns 格式化后的字符串
 */
export function formatInterval(seconds: number): string {
  if (seconds < 60) {
    return `${seconds}秒`;
  }
  if (seconds < 3600) {
    const minutes = Math.floor(seconds / 60);
    return `${minutes}分钟`;
  }
  if (seconds < 86400) {
    const hours = Math.floor(seconds / 3600);
    return `${hours}小时`;
  }
  const days = Math.floor(seconds / 86400);
  return `${days}天`;
}

/**
 * 检测当前平台
 * @returns 平台类型
 */
export function detectPlatform(): PlatformType {
  const userAgent = navigator.userAgent.toLowerCase();

  if (/android/.test(userAgent)) {
    return 'android';
  }
  if (/iphone|ipad|ipod/.test(userAgent)) {
    return 'ios';
  }
  if (/mobile/.test(userAgent)) {
    return 'mobile';
  }
  return 'desktop';
}

/**
 * 检测是否为移动端
 * @returns 是否为移动端
 */
export function isMobilePlatform(): boolean {
  const platform = detectPlatform();
  return platform === 'mobile' || platform === 'android' || platform === 'ios';
}
