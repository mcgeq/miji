export interface ReminderTypeI18 {
  code: string;
  nameZh: string;
  nameEn: string;
  icon?: string;
  category?: string;
  description?: string;
}

export const DEFAULT_REMINDER_TYPES: ReminderTypeI18[] = [
  // 财务相关
  {
    code: 'Bill',
    nameZh: '账单提醒',
    nameEn: 'Bill Reminder',
    icon: '💳',
    category: 'finance',
    description: '信用卡、水电费等账单提醒',
  },
  {
    code: 'Income',
    nameZh: '收入提醒',
    nameEn: 'Income Reminder',
    icon: '💰',
    category: 'finance',
    description: '工资、奖金等收入提醒',
  },
  {
    code: 'Budget',
    nameZh: '预算提醒',
    nameEn: 'Budget Reminder',
    icon: '📊',
    category: 'finance',
    description: '预算执行情况检查',
  },
  {
    code: 'Investment',
    nameZh: '投资提醒',
    nameEn: 'Investment Reminder',
    icon: '📈',
    category: 'finance',
    description: '股票、基金等投资提醒',
  },
  {
    code: 'Savings',
    nameZh: '储蓄提醒',
    nameEn: 'Savings Reminder',
    icon: '🏦',
    category: 'finance',
    description: '定期储蓄、存款提醒',
  },
  {
    code: 'Tax',
    nameZh: '税务提醒',
    nameEn: 'Tax Reminder',
    icon: '📋',
    category: 'finance',
    description: '报税、纳税提醒',
  },
  {
    code: 'Insurance',
    nameZh: '保险提醒',
    nameEn: 'Insurance Reminder',
    icon: '🛡',
    category: 'finance',
    description: '保险缴费、续保提醒',
  },
  {
    code: 'Loan',
    nameZh: '贷款提醒',
    nameEn: 'Loan Reminder',
    icon: '🏠',
    category: 'finance',
    description: '房贷、车贷等还款提醒',
  },

  // 目标与计划
  {
    code: 'Goal',
    nameZh: '目标提醒',
    nameEn: 'Goal Reminder',
    icon: '🎯',
    category: 'goals',
    description: '个人目标达成提醒',
  },
  {
    code: 'Milestone',
    nameZh: '里程碑提醒',
    nameEn: 'Milestone Reminder',
    icon: '🏆',
    category: 'goals',
    description: '重要里程碑节点提醒',
  },
  {
    code: 'Review',
    nameZh: '复盘提醒',
    nameEn: 'Review Reminder',
    icon: '🔍',
    category: 'goals',
    description: '定期复盘和总结提醒',
  },

  // 健康生活
  {
    code: 'Health',
    nameZh: '健康提醒',
    nameEn: 'Health Reminder',
    icon: '🏥',
    category: 'health',
    description: '体检、看医生等健康提醒',
  },
  {
    code: 'Exercise',
    nameZh: '运动提醒',
    nameEn: 'Exercise Reminder',
    icon: '💪',
    category: 'health',
    description: '运动锻炼提醒',
  },
  {
    code: 'Medicine',
    nameZh: '用药提醒',
    nameEn: 'Medicine Reminder',
    icon: '💊',
    category: 'health',
    description: '服药、治疗提醒',
  },
  {
    code: 'Diet',
    nameZh: '饮食提醒',
    nameEn: 'Diet Reminder',
    icon: '🥗',
    category: 'health',
    description: '饮食计划、营养提醒',
  },
  {
    code: 'Sleep',
    nameZh: '睡眠提醒',
    nameEn: 'Sleep Reminder',
    icon: '😴',
    category: 'health',
    description: '睡眠时间、作息提醒',
  },

  // 工作学习
  {
    code: 'Work',
    nameZh: '工作提醒',
    nameEn: 'Work Reminder',
    icon: '💼',
    category: 'work',
    description: '工作任务、会议等提醒',
  },
  {
    code: 'Deadline',
    nameZh: '截止日期',
    nameEn: 'Deadline Reminder',
    icon: '⏰',
    category: 'work',
    description: '项目截止、交付日期提醒',
  },
  {
    code: 'Meeting',
    nameZh: '会议提醒',
    nameEn: 'Meeting Reminder',
    icon: '👥',
    category: 'work',
    description: '会议、约会时间提醒',
  },
  {
    code: 'Study',
    nameZh: '学习提醒',
    nameEn: 'Study Reminder',
    icon: '📚',
    category: 'education',
    description: '学习计划、课程提醒',
  },
  {
    code: 'Exam',
    nameZh: '考试提醒',
    nameEn: 'Exam Reminder',
    icon: '📝',
    category: 'education',
    description: '考试时间、报名提醒',
  },
  {
    code: 'Training',
    nameZh: '培训提醒',
    nameEn: 'Training Reminder',
    icon: '🎓',
    category: 'education',
    description: '培训课程、技能提升提醒',
  },

  // 生活事务
  {
    code: 'Shopping',
    nameZh: '购物提醒',
    nameEn: 'Shopping Reminder',
    icon: '🛒',
    category: 'lifestyle',
    description: '购买物品、采购提醒',
  },
  {
    code: 'Maintenance',
    nameZh: '维护提醒',
    nameEn: 'Maintenance Reminder',
    icon: '🔧',
    category: 'lifestyle',
    description: '设备维护、保养提醒',
  },
  {
    code: 'Renewal',
    nameZh: '续费提醒',
    nameEn: 'Renewal Reminder',
    icon: '🔄',
    category: 'lifestyle',
    description: '会员续费、订阅续期提醒',
  },
  {
    code: 'Travel',
    nameZh: '旅行提醒',
    nameEn: 'Travel Reminder',
    icon: '✈',
    category: 'lifestyle',
    description: '旅行计划、行程提醒',
  },
  {
    code: 'Event',
    nameZh: '活动提醒',
    nameEn: 'Event Reminder',
    icon: '🎉',
    category: 'social',
    description: '活动、聚会等社交提醒',
  },
  {
    code: 'Birthday',
    nameZh: '生日提醒',
    nameEn: 'Birthday Reminder',
    icon: '🎂',
    category: 'social',
    description: '生日、纪念日提醒',
  },
  {
    code: 'Anniversary',
    nameZh: '纪念日提醒',
    nameEn: 'Anniversary Reminder',
    icon: '💝',
    category: 'social',
    description: '结婚纪念日等重要日期',
  },
  {
    code: 'Call',
    nameZh: '联系提醒',
    nameEn: 'Call Reminder',
    icon: '📞',
    category: 'social',
    description: '联系朋友、家人提醒',
  },

  // 文档证件
  {
    code: 'Document',
    nameZh: '证件提醒',
    nameEn: 'Document Reminder',
    icon: '📄',
    category: 'documents',
    description: '证件到期、更新提醒',
  },
  {
    code: 'Passport',
    nameZh: '护照提醒',
    nameEn: 'Passport Reminder',
    icon: '📓',
    category: 'documents',
    description: '护照、签证到期提醒',
  },
  {
    code: 'License',
    nameZh: '执照提醒',
    nameEn: 'License Reminder',
    icon: '🪪',
    category: 'documents',
    description: '驾照、营业执照等提醒',
  },

  // 家庭生活
  {
    code: 'Family',
    nameZh: '家庭提醒',
    nameEn: 'Family Reminder',
    icon: '👨',
    category: 'family',
    description: '家庭事务、亲子活动提醒',
  },
  {
    code: 'Pet',
    nameZh: '宠物提醒',
    nameEn: 'Pet Reminder',
    icon: '🐕',
    category: 'family',
    description: '宠物护理、疫苗等提醒',
  },
  {
    code: 'Chores',
    nameZh: '家务提醒',
    nameEn: 'Chores Reminder',
    icon: '🧹',
    category: 'family',
    description: '家务清洁、整理提醒',
  },

  // 兴趣爱好
  {
    code: 'Hobby',
    nameZh: '爱好提醒',
    nameEn: 'Hobby Reminder',
    icon: '🎨',
    category: 'hobbies',
    description: '兴趣爱好、娱乐活动提醒',
  },
  {
    code: 'Reading',
    nameZh: '阅读提醒',
    nameEn: 'Reading Reminder',
    icon: '📖',
    category: 'hobbies',
    description: '读书计划、阅读目标提醒',
  },
  {
    code: 'Music',
    nameZh: '音乐提醒',
    nameEn: 'Music Reminder',
    icon: '🎵',
    category: 'hobbies',
    description: '音乐练习、演出提醒',
  },

  // 技术相关
  {
    code: 'Backup',
    nameZh: '备份提醒',
    nameEn: 'Backup Reminder',
    icon: '💾',
    category: 'tech',
    description: '数据备份、系统更新提醒',
  },
  {
    code: 'Security',
    nameZh: '安全提醒',
    nameEn: 'Security Reminder',
    icon: '🔒',
    category: 'tech',
    description: '密码更新、安全检查提醒',
  },

  // 通用分类
  {
    code: 'Important',
    nameZh: '重要提醒',
    nameEn: 'Important Reminder',
    icon: '❗',
    category: 'general',
    description: '重要事项提醒',
  },
  {
    code: 'Urgent',
    nameZh: '紧急提醒',
    nameEn: 'Urgent Reminder',
    icon: '🚨',
    category: 'general',
    description: '紧急事项提醒',
  },
  {
    code: 'Routine',
    nameZh: '日常提醒',
    nameEn: 'Routine Reminder',
    icon: '🔄',
    category: 'general',
    description: '日常例行事务提醒',
  },
  {
    code: 'Custom',
    nameZh: '自定义提醒',
    nameEn: 'Custom Reminder',
    icon: '⚙',
    category: 'general',
    description: '自定义类型提醒',
  },
  {
    code: 'Other',
    nameZh: '其他',
    nameEn: 'Other',
    icon: '📌',
    category: 'general',
    description: '其他未分类提醒',
  },
];

// 按分类分组的提醒类型
export const REMINDER_TYPES_BY_CATEGORY = {
  finance: DEFAULT_REMINDER_TYPES.filter((type) => type.category === 'finance'),
  goals: DEFAULT_REMINDER_TYPES.filter((type) => type.category === 'goals'),
  health: DEFAULT_REMINDER_TYPES.filter((type) => type.category === 'health'),
  work: DEFAULT_REMINDER_TYPES.filter((type) => type.category === 'work'),
  education: DEFAULT_REMINDER_TYPES.filter(
    (type) => type.category === 'education',
  ),
  lifestyle: DEFAULT_REMINDER_TYPES.filter(
    (type) => type.category === 'lifestyle',
  ),
  social: DEFAULT_REMINDER_TYPES.filter((type) => type.category === 'social'),
  documents: DEFAULT_REMINDER_TYPES.filter(
    (type) => type.category === 'documents',
  ),
  family: DEFAULT_REMINDER_TYPES.filter((type) => type.category === 'family'),
  hobbies: DEFAULT_REMINDER_TYPES.filter((type) => type.category === 'hobbies'),
  tech: DEFAULT_REMINDER_TYPES.filter((type) => type.category === 'tech'),
  general: DEFAULT_REMINDER_TYPES.filter((type) => type.category === 'general'),
};

// 分类名称映射
export const CATEGORY_NAMES = {
  finance: { zh: '💰 财务管理', en: '💰 Finance' },
  goals: { zh: '🎯 目标计划', en: '🎯 Goals & Plans' },
  health: { zh: '🏥 健康生活', en: '🏥 Health & Wellness' },
  work: { zh: '💼 工作事务', en: '💼 Work & Business' },
  education: { zh: '📚 学习教育', en: '📚 Education' },
  lifestyle: { zh: '🏠 生活事务', en: '🏠 Lifestyle' },
  social: { zh: '👥 社交活动', en: '👥 Social' },
  documents: { zh: '📄 证件文档', en: '📄 Documents' },
  family: { zh: '👨 家庭生活', en: '👨 Family' },
  hobbies: { zh: '🎨 兴趣爱好', en: '🎨 Hobbies' },
  tech: { zh: '💻 技术相关', en: '💻 Technology' },
  general: { zh: '📌 通用分类', en: '📌 General' },
};

// 获取热门提醒类型（使用频率较高的）
export const POPULAR_REMINDER_TYPES = DEFAULT_REMINDER_TYPES.filter((type) =>
  [
    'Bill',
    'Income',
    'Work',
    'Health',
    'Meeting',
    'Shopping',
    'Exercise',
    'Birthday',
  ].includes(type.code),
);

// 工具函数：根据代码获取提醒类型
export const getReminderTypeByCode = (
  code: string,
): ReminderTypeI18 | undefined => {
  return DEFAULT_REMINDER_TYPES.find((type) => type.code === code);
};

// 工具函数：根据分类获取提醒类型
export const getReminderTypesByCategory = (
  category: string,
): ReminderTypeI18[] => {
  return DEFAULT_REMINDER_TYPES.filter((type) => type.category === category);
};

// 工具函数：搜索提醒类型
export const searchReminderTypes = (
  keyword: string,
  locale: 'zh-CN' | 'en' = 'zh-CN',
): ReminderTypeI18[] => {
  const searchTerm = keyword.toLowerCase();
  return DEFAULT_REMINDER_TYPES.filter((type) => {
    const name = locale === 'zh-CN' ? type.nameZh : type.nameEn;
    return (
      name.toLowerCase().includes(searchTerm) ||
      (type.description && type.description.toLowerCase().includes(searchTerm))
    );
  });
};
