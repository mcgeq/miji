import { DateUtils } from '@/utils/date';
import type { Currency, DefaultColors } from '@/schema/common';

// 基础颜色调色板（保持向后兼容）
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

// 扩展颜色调色板
export const EXTENDED_COLORS_MAP: DefaultColors[] = [
  // 基础色系
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

  // 扩展色系
  { code: '#1E40AF', nameZh: '深蓝', nameEn: 'Deep Blue' },
  { code: '#DC2626', nameZh: '深红', nameEn: 'Deep Red' },
  { code: '#059669', nameZh: '深绿', nameEn: 'Deep Green' },
  { code: '#D97706', nameZh: '琥珀色', nameEn: 'Amber' },
  { code: '#7C3AED', nameZh: '深紫', nameEn: 'Deep Purple' },
  { code: '#0891B2', nameZh: '深青', nameEn: 'Deep Cyan' },
  { code: '#65A30D', nameZh: '橄榄绿', nameEn: 'Olive' },
  { code: '#EA580C', nameZh: '橙红', nameEn: 'Orange Red' },
  { code: '#DB2777', nameZh: '玫瑰红', nameEn: 'Rose' },
  { code: '#6B7280', nameZh: '深灰', nameEn: 'Dark Gray' },

  // 柔和色系
  { code: '#60A5FA', nameZh: '浅蓝', nameEn: 'Light Blue' },
  { code: '#F87171', nameZh: '浅红', nameEn: 'Light Red' },
  { code: '#34D399', nameZh: '浅绿', nameEn: 'Light Green' },
  { code: '#FBBF24', nameZh: '浅黄', nameEn: 'Light Yellow' },
  { code: '#A78BFA', nameZh: '浅紫', nameEn: 'Light Purple' },
  { code: '#22D3EE', nameZh: '浅青', nameEn: 'Light Cyan' },
  { code: '#A3E635', nameZh: '浅绿', nameEn: 'Light Lime' },
  { code: '#FB923C', nameZh: '浅橙', nameEn: 'Light Orange' },
  { code: '#F472B6', nameZh: '浅粉', nameEn: 'Light Pink' },
  { code: '#D1D5DB', nameZh: '浅灰', nameEn: 'Light Gray' },

  // 特殊色系
  { code: '#F59E0B', nameZh: '金色', nameEn: 'Gold' },
  { code: '#10B981', nameZh: '翡翠绿', nameEn: 'Emerald' },
  { code: '#8B5CF6', nameZh: '紫罗兰', nameEn: 'Violet' },
  { code: '#F97316', nameZh: '珊瑚橙', nameEn: 'Coral' },
  { code: '#06B6D4', nameZh: '天蓝', nameEn: 'Sky Blue' },
  { code: '#84CC16', nameZh: '酸橙', nameEn: 'Lime' },
  { code: '#EC4899', nameZh: '洋红', nameEn: 'Magenta' },
  { code: '#6B7280', nameZh: '石板灰', nameEn: 'Slate Gray' },
  { code: '#EF4444', nameZh: '朱红', nameEn: 'Vermillion' },
  { code: '#3B82F6', nameZh: '钴蓝', nameEn: 'Cobalt Blue' },
];

export const CURRENCY_CNY: Currency = {
  locale: 'zh-CN',
  code: 'CNY',
  symbol: '¥',
  createdAt: DateUtils.getLocalISODateTimeWithOffset(),
  updatedAt: null,
};
