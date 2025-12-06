/**
 * 通知系统类型定义
 * @module types/notification
 * @description 统一通知服务的前端类型定义
 */

/**
 * 通知类型枚举
 */
export enum NotificationType {
  /** 待办提醒 */
  TODO_REMINDER = 'TodoReminder',
  /** 账单提醒 */
  BILL_REMINDER = 'BillReminder',
  /** 经期提醒 */
  PERIOD_REMINDER = 'PeriodReminder',
  /** 排卵期提醒 */
  OVULATION_REMINDER = 'OvulationReminder',
  /** PMS 提醒 */
  PMS_REMINDER = 'PmsReminder',
  /** 系统警报 */
  SYSTEM_ALERT = 'SystemAlert',
}

/**
 * 通知优先级枚举
 */
export enum NotificationPriority {
  /** 低优先级 */
  LOW = 'Low',
  /** 普通优先级 */
  NORMAL = 'Normal',
  /** 高优先级 */
  HIGH = 'High',
  /** 紧急优先级 */
  URGENT = 'Urgent',
}

/**
 * 通知类型的中文名称映射
 */
export const NotificationTypeLabel: Record<NotificationType, string> = {
  [NotificationType.TODO_REMINDER]: '待办提醒',
  [NotificationType.BILL_REMINDER]: '账单提醒',
  [NotificationType.PERIOD_REMINDER]: '经期提醒',
  [NotificationType.OVULATION_REMINDER]: '排卵期提醒',
  [NotificationType.PMS_REMINDER]: 'PMS 提醒',
  [NotificationType.SYSTEM_ALERT]: '系统警报',
};

/**
 * 通知类型的描述映射
 */
export const NotificationTypeDescription: Record<NotificationType, string> = {
  [NotificationType.TODO_REMINDER]: '待办事项到期时的提醒通知',
  [NotificationType.BILL_REMINDER]: '账单到期和逾期的提醒通知',
  [NotificationType.PERIOD_REMINDER]: '经期预测和提醒通知',
  [NotificationType.OVULATION_REMINDER]: '排卵期预测和提醒通知',
  [NotificationType.PMS_REMINDER]: 'PMS 症状提醒和关怀通知',
  [NotificationType.SYSTEM_ALERT]: '重要的系统级别通知',
};

/**
 * 通知类型的图标映射
 */
export const NotificationTypeIcon: Record<NotificationType, string> = {
  [NotificationType.TODO_REMINDER]: 'CheckSquare',
  [NotificationType.BILL_REMINDER]: 'CreditCard',
  [NotificationType.PERIOD_REMINDER]: 'Calendar',
  [NotificationType.OVULATION_REMINDER]: 'Heart',
  [NotificationType.PMS_REMINDER]: 'Activity',
  [NotificationType.SYSTEM_ALERT]: 'AlertCircle',
};

/**
 * 通知优先级的中文名称映射
 */
export const NotificationPriorityLabel: Record<NotificationPriority, string> = {
  [NotificationPriority.LOW]: '低',
  [NotificationPriority.NORMAL]: '普通',
  [NotificationPriority.HIGH]: '高',
  [NotificationPriority.URGENT]: '紧急',
};

/**
 * 通知优先级的颜色映射
 */
export const NotificationPriorityColor: Record<NotificationPriority, string> = {
  [NotificationPriority.LOW]: 'gray',
  [NotificationPriority.NORMAL]: 'blue',
  [NotificationPriority.HIGH]: 'orange',
  [NotificationPriority.URGENT]: 'red',
};

/**
 * 通知设置接口
 */
export interface NotificationSettings {
  /** 序列号 */
  serialNum: string;
  /** 用户 ID */
  userId: string;
  /** 通知类型 */
  notificationType: string;
  /** 是否启用 */
  enabled: boolean;
  /** 免打扰时段开始 (HH:mm 格式) */
  quietHoursStart?: string;
  /** 免打扰时段结束 (HH:mm 格式) */
  quietHoursEnd?: string;
  /** 免打扰日期 (星期几，0-6) */
  quietDays?: string[];
  /** 是否启用声音 */
  soundEnabled: boolean;
  /** 是否启用震动 */
  vibrationEnabled: boolean;
  /** 创建时间 */
  createdAt: string;
  /** 更新时间 */
  updatedAt?: string;
}

/**
 * 通知日志接口
 */
export interface NotificationLog {
  /** 日志 ID */
  id: string;
  /** 通知类型 */
  notificationType: NotificationType;
  /** 用户 ID */
  userId: string;
  /** 标题 */
  title: string;
  /** 内容 */
  body: string;
  /** 优先级 */
  priority: NotificationPriority;
  /** 状态 */
  status: 'Pending' | 'Sent' | 'Failed';
  /** 发送时间 */
  sentAt?: string;
  /** 错误信息 */
  error?: string;
  /** 创建时间 */
  createdAt: string;
  /** 更新时间 */
  updatedAt?: string;
}

/**
 * 通知权限状态
 */
export interface NotificationPermission {
  /** 是否已授予权限 */
  granted: boolean;
  /** 是否支持通知 */
  supported: boolean;
  /** 是否正在请求 */
  requesting: boolean;
}

/**
 * 通知统计信息
 */
export interface NotificationStatistics {
  /** 总发送数 */
  total: number;
  /** 成功数 */
  success: number;
  /** 失败数 */
  failed: number;
  /** 待发送数 */
  pending: number;
  /** 按类型统计 */
  byType: Record<NotificationType, number>;
  /** 按优先级统计 */
  byPriority: Record<NotificationPriority, number>;
}

/**
 * 通知统计仪表板数据（扩展版）
 */
export interface NotificationDashboardData extends NotificationStatistics {
  /** 增长率 */
  growthRate?: number;
  /** 类型分布（数组格式，用于图表） */
  typeDistribution?: Array<{ type: string; count: number }>;
  /** 优先级分布（数组格式，用于图表） */
  priorityDistribution?: Array<{ priority: string; count: number }>;
  /** 每日趋势 */
  dailyTrend?: Array<{ date: string; success: number; failed: number }>;
  /** 最近日志 */
  recentLogs?: NotificationLog[];
}

/**
 * 通知设置表单
 */
export interface NotificationSettingsForm {
  /** 通知类型 */
  notificationType: string;
  /** 是否启用 */
  enabled: boolean;
  /** 免打扰时段开始 (HH:mm 格式) */
  quietHoursStart?: string;
  /** 免打扰时段结束 (HH:mm 格式) */
  quietHoursEnd?: string;
  /** 免打扰日期 (星期几，0-6) */
  quietDays?: string[];
  /** 是否启用声音 */
  soundEnabled?: boolean;
  /** 是否启用震动 */
  vibrationEnabled?: boolean;
}
