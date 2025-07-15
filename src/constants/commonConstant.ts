export type ReminderTypeI18 = {
  code: string;
  nameZh: string;
  nameEn: string;
};

export const REMINDER_TYPE: ReminderTypeI18[] = [
  { code: 'Bill', nameZh: '账单提醒', nameEn: '' },
  { code: 'Income', nameZh: '收入提醒', nameEn: '' },
  { code: 'Budget', nameZh: '预算提醒', nameEn: '' },
  { code: 'Goal', nameZh: '目标提醒', nameEn: '' },
  { code: 'Investment', nameZh: '投资提醒', nameEn: '' },
  { code: 'Other', nameZh: '其他', nameEn: '' },
];
