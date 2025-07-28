import { DateUtils } from '@/utils/date';
import type { Currency, DefaultColors } from '@/schema/common';

export const COLORS_MAP: DefaultColors[] = [
  { code: '#3B82F6', nameZh: '蓝色', nameEn: 'Blue' },
  { code: '#EF4444', nameZh: '红色', nameEn: 'Red' },
  { code: '#10B981', nameZh: '绿色', nameEn: 'Emerald' },
  { code: '#FFA000', nameZh: '橙色', nameEn: 'Orange' },
  { code: '#8B5CF6', nameZh: '紫色', nameEn: 'Violet' },
  { code: '#06B6D4', nameZh: '青色', nameEn: 'Cyan' },
  { code: '#76C043', nameZh: '柠檬绿', nameEn: 'Lime' },
  { code: '#E65100', nameZh: '深橙色', nameEn: 'Deep Orange' },
  { code: '#EC4899', nameZh: '粉色', nameEn: 'Pink' },
  { code: '#A0AEC0', nameZh: '灰色', nameEn: 'Gray' },
];

export const CURRENCY_CNY: Currency = {
  locale: 'zh-CN',
  code: 'CNY',
  symbol: '¥',
  createdAt: DateUtils.getLocalISODateTimeWithOffset(),
};
