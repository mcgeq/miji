/**
 * 提醒类型配置系统
 * 根据不同提醒类型定义字段需求、默认值和验证规则
 */

export interface ReminderTypeConfig {
  // 需要显示的字段
  requiresAmount: boolean;
  requiresBillDate: boolean;
  requiresDescription: boolean;
  requiresCategory: boolean;

  // 智能默认值
  defaultPriority: 'Urgent' | 'High' | 'Medium' | 'Low';
  defaultAdvanceValue: number;
  defaultAdvanceUnit: 'minutes' | 'hours' | 'days' | 'weeks';
  defaultAdvanceHours: number; // 转换为小时数，便于后端计算
  defaultColor: string;

  // 特殊配置
  defaultRepeatType: string;
  enableSmartReminder: boolean;
  enableEscalation: boolean;
  enableAutoReschedule: boolean;
  enablePaymentReminder: boolean;

  // 分类信息
  category: string;
  icon: string;
  description: string;
}

export const REMINDER_TYPE_CONFIG: Record<string, ReminderTypeConfig> = {
  // ===== 财务相关 =====
  Bill: {
    requiresAmount: true,
    requiresBillDate: true,
    requiresDescription: false,
    requiresCategory: true,
    defaultPriority: 'High',
    defaultAdvanceValue: 3,
    defaultAdvanceUnit: 'days',
    defaultAdvanceHours: 72,
    defaultColor: 'var(--color-error)',
    defaultRepeatType: 'None',
    enableSmartReminder: true,
    enableEscalation: true,
    enableAutoReschedule: true,
    enablePaymentReminder: true,
    category: '财务',
    icon: '💰',
    description: '账单提醒',
  },

  Income: {
    requiresAmount: true,
    requiresBillDate: true,
    requiresDescription: false,
    requiresCategory: true,
    defaultPriority: 'Medium',
    defaultAdvanceValue: 1,
    defaultAdvanceUnit: 'days',
    defaultAdvanceHours: 24,
    defaultColor: 'var(--color-success)',
    defaultRepeatType: 'None',
    enableSmartReminder: false,
    enableEscalation: false,
    enableAutoReschedule: false,
    enablePaymentReminder: false,
    category: '财务',
    icon: '💵',
    description: '收入提醒',
  },

  Budget: {
    requiresAmount: true,
    requiresBillDate: false,
    requiresDescription: true,
    requiresCategory: true,
    defaultPriority: 'Medium',
    defaultAdvanceValue: 7,
    defaultAdvanceUnit: 'days',
    defaultAdvanceHours: 168,
    defaultColor: 'var(--color-info)',
    defaultRepeatType: 'None',
    enableSmartReminder: true,
    enableEscalation: false,
    enableAutoReschedule: true,
    enablePaymentReminder: false,
    category: '财务',
    icon: '📊',
    description: '预算提醒',
  },

  Investment: {
    requiresAmount: true,
    requiresBillDate: false,
    requiresDescription: false,
    requiresCategory: true,
    defaultPriority: 'Medium',
    defaultAdvanceValue: 1,
    defaultAdvanceUnit: 'days',
    defaultAdvanceHours: 24,
    defaultColor: 'var(--color-info)',
    defaultRepeatType: 'None',
    enableSmartReminder: true,
    enableEscalation: false,
    enableAutoReschedule: false,
    enablePaymentReminder: false,
    category: '财务',
    icon: '📈',
    description: '投资提醒',
  },

  Savings: {
    requiresAmount: true,
    requiresBillDate: false,
    requiresDescription: true,
    requiresCategory: true,
    defaultPriority: 'Low',
    defaultAdvanceValue: 1,
    defaultAdvanceUnit: 'days',
    defaultAdvanceHours: 24,
    defaultColor: 'var(--color-success)',
    defaultRepeatType: 'Monthly',
    enableSmartReminder: false,
    enableEscalation: false,
    enableAutoReschedule: true,
    enablePaymentReminder: false,
    category: '财务',
    icon: '🏦',
    description: '储蓄提醒',
  },

  Tax: {
    requiresAmount: true,
    requiresBillDate: true,
    requiresDescription: true,
    requiresCategory: true,
    defaultPriority: 'High',
    defaultAdvanceValue: 30,
    defaultAdvanceUnit: 'days',
    defaultAdvanceHours: 720,
    defaultColor: 'var(--color-error)',
    defaultRepeatType: 'Yearly',
    enableSmartReminder: true,
    enableEscalation: true,
    enableAutoReschedule: true,
    enablePaymentReminder: true,
    category: '财务',
    icon: '📋',
    description: '税务提醒',
  },

  Insurance: {
    requiresAmount: true,
    requiresBillDate: true,
    requiresDescription: false,
    requiresCategory: true,
    defaultPriority: 'High',
    defaultAdvanceValue: 7,
    defaultAdvanceUnit: 'days',
    defaultAdvanceHours: 168,
    defaultColor: 'var(--color-warning)',
    defaultRepeatType: 'Yearly',
    enableSmartReminder: true,
    enableEscalation: true,
    enableAutoReschedule: true,
    enablePaymentReminder: true,
    category: '财务',
    icon: '🛡️',
    description: '保险提醒',
  },

  Loan: {
    requiresAmount: true,
    requiresBillDate: true,
    requiresDescription: false,
    requiresCategory: true,
    defaultPriority: 'Urgent',
    defaultAdvanceValue: 3,
    defaultAdvanceUnit: 'days',
    defaultAdvanceHours: 72,
    defaultColor: 'var(--color-error)',
    defaultRepeatType: 'Monthly',
    enableSmartReminder: true,
    enableEscalation: true,
    enableAutoReschedule: true,
    enablePaymentReminder: true,
    category: '财务',
    icon: '🏠',
    description: '贷款提醒',
  },

  // ===== 健康生活 =====
  Health: {
    requiresAmount: false,
    requiresBillDate: false,
    requiresDescription: true,
    requiresCategory: true,
    defaultPriority: 'High',
    defaultAdvanceValue: 1,
    defaultAdvanceUnit: 'days',
    defaultAdvanceHours: 24,
    defaultColor: 'var(--color-warning)',
    defaultRepeatType: 'None',
    enableSmartReminder: false,
    enableEscalation: false,
    enableAutoReschedule: false,
    enablePaymentReminder: false,
    category: '健康',
    icon: '🏥',
    description: '健康提醒',
  },

  Exercise: {
    requiresAmount: false,
    requiresBillDate: false,
    requiresDescription: true,
    requiresCategory: true,
    defaultPriority: 'Low',
    defaultAdvanceValue: 1,
    defaultAdvanceUnit: 'hours',
    defaultAdvanceHours: 1,
    defaultColor: 'var(--color-cyan-500)',
    defaultRepeatType: 'Daily',
    enableSmartReminder: false,
    enableEscalation: false,
    enableAutoReschedule: false,
    enablePaymentReminder: false,
    category: '健康',
    icon: '💪',
    description: '运动提醒',
  },

  Medicine: {
    requiresAmount: false,
    requiresBillDate: false,
    requiresDescription: true,
    requiresCategory: true,
    defaultPriority: 'Urgent',
    defaultAdvanceValue: 30,
    defaultAdvanceUnit: 'minutes',
    defaultAdvanceHours: 0.5,
    defaultColor: 'var(--color-error)',
    defaultRepeatType: 'Daily',
    enableSmartReminder: true,
    enableEscalation: true,
    enableAutoReschedule: false,
    enablePaymentReminder: false,
    category: '健康',
    icon: '💊',
    description: '用药提醒',
  },

  Diet: {
    requiresAmount: false,
    requiresBillDate: false,
    requiresDescription: true,
    requiresCategory: true,
    defaultPriority: 'Low',
    defaultAdvanceValue: 1,
    defaultAdvanceUnit: 'hours',
    defaultAdvanceHours: 1,
    defaultColor: 'var(--color-success)',
    defaultRepeatType: 'Daily',
    enableSmartReminder: false,
    enableEscalation: false,
    enableAutoReschedule: false,
    enablePaymentReminder: false,
    category: '健康',
    icon: '🍽️',
    description: '饮食提醒',
  },

  Sleep: {
    requiresAmount: false,
    requiresBillDate: false,
    requiresDescription: false,
    requiresCategory: false,
    defaultPriority: 'Medium',
    defaultAdvanceValue: 15,
    defaultAdvanceUnit: 'minutes',
    defaultAdvanceHours: 0.25,
    defaultColor: 'var(--color-warning)',
    defaultRepeatType: 'Daily',
    enableSmartReminder: false,
    enableEscalation: false,
    enableAutoReschedule: false,
    enablePaymentReminder: false,
    category: '健康',
    icon: '😴',
    description: '睡眠提醒',
  },

  // ===== 工作事务 =====
  Work: {
    requiresAmount: false,
    requiresBillDate: false,
    requiresDescription: true,
    requiresCategory: true,
    defaultPriority: 'High',
    defaultAdvanceValue: 1,
    defaultAdvanceUnit: 'hours',
    defaultAdvanceHours: 1,
    defaultColor: 'var(--color-warning)',
    defaultRepeatType: 'None',
    enableSmartReminder: true,
    enableEscalation: true,
    enableAutoReschedule: false,
    enablePaymentReminder: false,
    category: '工作',
    icon: '💼',
    description: '工作提醒',
  },

  Deadline: {
    requiresAmount: false,
    requiresBillDate: false,
    requiresDescription: true,
    requiresCategory: true,
    defaultPriority: 'Urgent',
    defaultAdvanceValue: 1,
    defaultAdvanceUnit: 'days',
    defaultAdvanceHours: 24,
    defaultColor: 'var(--color-error)',
    defaultRepeatType: 'None',
    enableSmartReminder: true,
    enableEscalation: true,
    enableAutoReschedule: false,
    enablePaymentReminder: false,
    category: '工作',
    icon: '⏰',
    description: '截止日期',
  },

  Meeting: {
    requiresAmount: false,
    requiresBillDate: false,
    requiresDescription: true,
    requiresCategory: true,
    defaultPriority: 'Medium',
    defaultAdvanceValue: 30,
    defaultAdvanceUnit: 'minutes',
    defaultAdvanceHours: 0.5,
    defaultColor: 'var(--color-purple-500)',
    defaultRepeatType: 'None',
    enableSmartReminder: false,
    enableEscalation: false,
    enableAutoReschedule: false,
    enablePaymentReminder: false,
    category: '工作',
    icon: '👥',
    description: '会议提醒',
  },

  // ===== 生活事务 =====
  Birthday: {
    requiresAmount: false,
    requiresBillDate: false,
    requiresDescription: false,
    requiresCategory: false,
    defaultPriority: 'Medium',
    defaultAdvanceValue: 1,
    defaultAdvanceUnit: 'days',
    defaultAdvanceHours: 24,
    defaultColor: 'var(--color-pink-500)',
    defaultRepeatType: 'Yearly',
    enableSmartReminder: false,
    enableEscalation: false,
    enableAutoReschedule: true,
    enablePaymentReminder: false,
    category: '生活',
    icon: '🎂',
    description: '生日提醒',
  },

  Anniversary: {
    requiresAmount: false,
    requiresBillDate: false,
    requiresDescription: false,
    requiresCategory: false,
    defaultPriority: 'Medium',
    defaultAdvanceValue: 1,
    defaultAdvanceUnit: 'days',
    defaultAdvanceHours: 24,
    defaultColor: 'var(--color-pink-500)',
    defaultRepeatType: 'Yearly',
    enableSmartReminder: false,
    enableEscalation: false,
    enableAutoReschedule: true,
    enablePaymentReminder: false,
    category: '生活',
    icon: '💝',
    description: '纪念日提醒',
  },

  Shopping: {
    requiresAmount: false,
    requiresBillDate: false,
    requiresDescription: true,
    requiresCategory: true,
    defaultPriority: 'Low',
    defaultAdvanceValue: 1,
    defaultAdvanceUnit: 'days',
    defaultAdvanceHours: 24,
    defaultColor: 'var(--color-info)',
    defaultRepeatType: 'None',
    enableSmartReminder: false,
    enableEscalation: false,
    enableAutoReschedule: false,
    enablePaymentReminder: false,
    category: '生活',
    icon: '🛒',
    description: '购物提醒',
  },

  Travel: {
    requiresAmount: false,
    requiresBillDate: false,
    requiresDescription: true,
    requiresCategory: true,
    defaultPriority: 'Medium',
    defaultAdvanceValue: 1,
    defaultAdvanceUnit: 'days',
    defaultAdvanceHours: 24,
    defaultColor: 'var(--color-info)',
    defaultRepeatType: 'None',
    enableSmartReminder: true,
    enableEscalation: false,
    enableAutoReschedule: false,
    enablePaymentReminder: false,
    category: '生活',
    icon: '✈️',
    description: '旅行提醒',
  },

  // ===== 通用 =====
  Important: {
    requiresAmount: false,
    requiresBillDate: false,
    requiresDescription: true,
    requiresCategory: false,
    defaultPriority: 'High',
    defaultAdvanceValue: 1,
    defaultAdvanceUnit: 'hours',
    defaultAdvanceHours: 1,
    defaultColor: 'var(--color-warning)',
    defaultRepeatType: 'None',
    enableSmartReminder: true,
    enableEscalation: true,
    enableAutoReschedule: false,
    enablePaymentReminder: false,
    category: '通用',
    icon: '⭐',
    description: '重要提醒',
  },

  Urgent: {
    requiresAmount: false,
    requiresBillDate: false,
    requiresDescription: true,
    requiresCategory: false,
    defaultPriority: 'Urgent',
    defaultAdvanceValue: 30,
    defaultAdvanceUnit: 'minutes',
    defaultAdvanceHours: 0.5,
    defaultColor: 'var(--color-error)',
    defaultRepeatType: 'None',
    enableSmartReminder: true,
    enableEscalation: true,
    enableAutoReschedule: false,
    enablePaymentReminder: false,
    category: '通用',
    icon: '🚨',
    description: '紧急提醒',
  },

  Routine: {
    requiresAmount: false,
    requiresBillDate: false,
    requiresDescription: true,
    requiresCategory: false,
    defaultPriority: 'Low',
    defaultAdvanceValue: 1,
    defaultAdvanceUnit: 'hours',
    defaultAdvanceHours: 1,
    defaultColor: 'var(--color-neutral)',
    defaultRepeatType: 'Daily',
    enableSmartReminder: false,
    enableEscalation: false,
    enableAutoReschedule: false,
    enablePaymentReminder: false,
    category: '通用',
    icon: '📅',
    description: '日常提醒',
  },
};

/**
 * 获取提醒类型配置
 */
export function getReminderTypeConfig(type: string): ReminderTypeConfig {
  return REMINDER_TYPE_CONFIG[type] || REMINDER_TYPE_CONFIG.Routine;
}

/**
 * 检查类型是否需要金额字段
 */
export function requiresAmount(type: string): boolean {
  return getReminderTypeConfig(type).requiresAmount;
}

/**
 * 检查类型是否需要账单日期字段
 */
export function requiresBillDate(type: string): boolean {
  return getReminderTypeConfig(type).requiresBillDate;
}

/**
 * 是否为财务类型
 */
export function isFinanceType(type: string): boolean {
  const config = getReminderTypeConfig(type);
  return config.category === '财务';
}

/**
 * 是否为紧急类型
 */
export function isUrgentType(type: string): boolean {
  const config = getReminderTypeConfig(type);
  return config.defaultPriority === 'Urgent';
}

/**
 * 获取需要升级提醒的类型
 */
export function shouldEnableEscalation(type: string): boolean {
  return getReminderTypeConfig(type).enableEscalation;
}

/**
 * 获取需要智能提醒的类型
 */
export function shouldEnableSmartReminder(type: string): boolean {
  return getReminderTypeConfig(type).enableSmartReminder;
}

/**
 * 获取需要自动重排的类型
 */
export function shouldEnableAutoReschedule(type: string): boolean {
  return getReminderTypeConfig(type).enableAutoReschedule;
}

/**
 * 获取需要支付提醒的类型
 */
export function shouldEnablePaymentReminder(type: string): boolean {
  return getReminderTypeConfig(type).enablePaymentReminder;
}
