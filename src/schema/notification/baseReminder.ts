/**
 * 统一提醒基础类型定义
 * @module schema/notification/baseReminder
 * @description 所有模块提醒功能的通用接口和类型定义
 */

import type { RepeatPeriod } from '@/schema/common';

/**
 * 提醒方式配置
 */
export interface ReminderMethods {
  /** 桌面通知 */
  desktop: boolean;
  /** 移动设备通知 */
  mobile: boolean;
  /** 邮件通知 */
  email: boolean;
  /** 短信通知 */
  sms: boolean;
}

/**
 * 智能提醒配置
 */
export interface SmartReminderConfig {
  /** 是否启用智能提醒 */
  enabled: boolean;
  /** 基于位置的提醒 */
  locationBased?: boolean;
  /** 目标位置 */
  targetLocation?: {
    lat: number;
    lng: number;
    name: string;
    radius?: number; // 触发半径（米）
  };
  /** 天气相关提醒 */
  weatherDependent?: boolean;
  /** 天气条件 */
  weatherCondition?: 'sunny' | 'rainy' | 'cloudy' | 'snowy' | 'any';
  /** 优先级动态增强 */
  priorityBoost?: boolean;
  /** 根据日历繁忙度调整 */
  calendarAware?: boolean;
}

/**
 * 提醒频率类型
 */
export type ReminderFrequency =
  | 'once' // 仅一次
  | '15m' // 每15分钟
  | '1h' // 每小时
  | '1d' // 每天
  | 'daily' // 每日
  | 'weekly' // 每周
  | 'custom'; // 自定义

/**
 * 提前提醒时间单位
 */
export type AdvanceUnit = 'minutes' | 'hours' | 'days' | 'weeks';

/**
 * 提醒状态
 */
export type ReminderStatus =
  | 'pending' // 待发送
  | 'sent' // 已发送
  | 'failed' // 发送失败
  | 'snoozed' // 已推迟
  | 'cancelled' // 已取消
  | 'expired'; // 已过期

/**
 * 基础提醒配置接口
 * 所有模块的提醒配置都应继承此接口
 */
export interface BaseReminderConfig {
  // ==================== 基础配置 ====================

  /** 是否启用提醒 */
  enabled: boolean;

  /** 提前提醒时间值 */
  advanceValue: number;

  /** 提前提醒时间单位 */
  advanceUnit: AdvanceUnit;

  // ==================== 时间配置 ====================

  /** 提醒日期时间 (ISO 8601 格式) */
  remindDate: string;

  /** 到期时间 (ISO 8601 格式) */
  dueAt: string;

  /** 时区 (IANA 时区标识符，如 "Asia/Shanghai") */
  timezone?: string;

  // ==================== 重复配置 ====================

  /** 重复周期 */
  repeatPeriod: RepeatPeriod;

  // ==================== 提醒方式 ====================

  /** 提醒方式配置 */
  reminderMethods: ReminderMethods;

  /** 提醒频率 */
  reminderFrequency: ReminderFrequency;

  // ==================== 智能功能 ====================

  /** 智能提醒配置 */
  smartConfig?: SmartReminderConfig;

  // ==================== 状态信息 ====================

  /** 上次提醒发送时间 (ISO 8601 格式) */
  lastReminderSentAt?: string;

  /** 推迟到指定时间 (ISO 8601 格式) */
  snoozeUntil?: string;

  /** 提醒状态 */
  status?: ReminderStatus;

  /** 发送重试次数 */
  retryCount?: number;
}

/**
 * Money 模块专用提醒配置
 */
export interface BilReminderConfig extends BaseReminderConfig {
  /** 启用升级提醒（未响应时提升优先级） */
  escalationEnabled: boolean;

  /** 升级间隔时间（小时） */
  escalationAfterHours: number;

  /** 自动顺延（逾期后自动重新安排） */
  autoReschedule: boolean;

  /** 支付提醒（支付后自动关闭） */
  paymentReminderEnabled: boolean;

  /** 批量提醒组ID（用于关联多个账单） */
  batchReminderId?: string;
}

/**
 * Todo 模块专用提醒配置
 */
export interface TodoReminderConfig extends BaseReminderConfig {
  /** 批量提醒组ID */
  batchReminderId?: string;

  /** 关联的待办事项标签 */
  tags?: string[];

  /** 是否在完成时自动取消提醒 */
  autoCancelOnComplete?: boolean;
}

/**
 * Period 模块专用提醒配置
 */
export interface PeriodReminderConfig extends BaseReminderConfig {
  /** 提醒类型 */
  reminderType: 'period' | 'ovulation' | 'pms';

  /** 包含健康建议 */
  includeHealthTips: boolean;

  /** 提醒语气风格 */
  toneStyle?: 'professional' | 'friendly' | 'concise';

  /** 提醒内容选项 */
  contentOptions?: {
    includeSymptomReminder: boolean;
    includeProductReminder: boolean;
    includeMoodTracking: boolean;
  };
}

/**
 * 提醒配置默认值
 */
export const DEFAULT_REMINDER_CONFIG: BaseReminderConfig = {
  enabled: false,
  advanceValue: 15,
  advanceUnit: 'minutes',
  remindDate: new Date().toISOString(),
  dueAt: new Date().toISOString(),
  timezone: Intl.DateTimeFormat().resolvedOptions().timeZone,
  repeatPeriod: { type: 'None' },
  reminderMethods: {
    desktop: true,
    mobile: true,
    email: false,
    sms: false,
  },
  reminderFrequency: 'once',
  status: 'pending',
  retryCount: 0,
};

/**
 * 创建默认的智能提醒配置
 */
export function createDefaultSmartConfig(): SmartReminderConfig {
  return {
    enabled: false,
    locationBased: false,
    weatherDependent: false,
    priorityBoost: false,
    calendarAware: false,
  };
}

/**
 * 合并提醒配置（用于更新部分字段）
 */
export function mergeReminderConfig<T extends BaseReminderConfig>(base: T, updates: Partial<T>): T {
  return {
    ...base,
    ...updates,
    reminderMethods: {
      ...base.reminderMethods,
      ...(updates.reminderMethods || {}),
    },
    smartConfig: updates.smartConfig
      ? {
          ...base.smartConfig,
          ...updates.smartConfig,
        }
      : base.smartConfig,
  };
}

/**
 * 验证提醒配置
 */
export interface ReminderConfigValidation {
  isValid: boolean;
  errors: string[];
}

/**
 * 验证基础提醒配置
 */
export function validateReminderConfig(config: BaseReminderConfig): ReminderConfigValidation {
  const errors: string[] = [];

  // 验证时间
  if (config.enabled) {
    const remindDate = new Date(config.remindDate);
    const dueDate = new Date(config.dueAt);

    if (Number.isNaN(remindDate.getTime())) {
      errors.push('提醒时间格式无效');
    }

    if (Number.isNaN(dueDate.getTime())) {
      errors.push('到期时间格式无效');
    }

    if (remindDate >= dueDate) {
      errors.push('提醒时间必须早于到期时间');
    }

    // 验证提前时间
    if (config.advanceValue < 0) {
      errors.push('提前时间不能为负数');
    }

    // 验证至少选择一种提醒方式
    const hasMethod = Object.values(config.reminderMethods).some(v => v);
    if (!hasMethod) {
      errors.push('请至少选择一种提醒方式');
    }
  }

  // 验证智能配置
  if (config.smartConfig?.enabled) {
    if (config.smartConfig.locationBased && !config.smartConfig.targetLocation) {
      errors.push('启用位置提醒时必须设置目标位置');
    }

    if (config.smartConfig.weatherDependent && !config.smartConfig.weatherCondition) {
      errors.push('启用天气提醒时必须设置天气条件');
    }
  }

  return {
    isValid: errors.length === 0,
    errors,
  };
}

/**
 * 计算下次提醒时间
 */
export function calculateNextReminderTime(config: BaseReminderConfig): Date | null {
  if (!config.enabled) return null;

  const dueDate = new Date(config.dueAt);
  const now = new Date();

  // 如果设置了推迟时间，使用推迟时间
  if (config.snoozeUntil) {
    const snoozeDate = new Date(config.snoozeUntil);
    if (snoozeDate > now) {
      return snoozeDate;
    }
  }

  // 根据提前时间计算
  const reminderTime = new Date(dueDate);
  switch (config.advanceUnit) {
    case 'minutes':
      reminderTime.setMinutes(reminderTime.getMinutes() - config.advanceValue);
      break;
    case 'hours':
      reminderTime.setHours(reminderTime.getHours() - config.advanceValue);
      break;
    case 'days':
      reminderTime.setDate(reminderTime.getDate() - config.advanceValue);
      break;
    case 'weeks':
      reminderTime.setDate(reminderTime.getDate() - config.advanceValue * 7);
      break;
  }

  // 如果计算出的时间已过期，返回null
  if (reminderTime < now) {
    return null;
  }

  return reminderTime;
}
