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

export const DEFAULT_CURRENCY: Currency[] = [
  {
    locale: 'en-US',
    code: 'USD',
    symbol: '$',
  },
  {
    locale: 'zh-CN',
    code: 'CNY',
    symbol: '¥',
  },
  {
    locale: 'en-DE',
    code: 'EUR',
    symbol: '€',
  },
  {
    locale: 'en-GB',
    code: 'GBP',
    symbol: '£',
  },
  {
    locale: 'ja-JP',
    code: 'JPY',
    symbol: '¥',
  },
  {
    locale: 'en-AU',
    code: 'AUD',
    symbol: 'A$',
  },
  {
    locale: 'en-CA',
    code: 'CAD',
    symbol: 'C$',
  },
  {
    locale: 'en-CH',
    code: 'CHF',
    symbol: '₣',
  },
  {
    locale: 'zh-HK',
    code: 'HKD',
    symbol: 'HK$',
  },
  {
    locale: 'en-SG',
    code: 'SGD',
    symbol: 'S$',
  },
  {
    locale: 'ko-KR',
    code: 'KRW',
    symbol: '₩',
  },
  {
    locale: 'en-IN',
    code: 'INR',
    symbol: '₹',
  },
  {
    locale: 'ru-RU',
    code: 'RUB',
    symbol: '₽',
  },
  {
    locale: 'pt-BR',
    code: 'BRL',
    symbol: 'R$',
  },
  {
    locale: 'en-ZA',
    code: 'ZAR',
    symbol: 'R',
  },
  {
    locale: 'sv-SE',
    code: 'SEK',
    symbol: 'kr',
  },
  {
    locale: 'en-NZ',
    code: 'NZD',
    symbol: 'NZ$',
  },
  {
    locale: 'th-TH',
    code: 'THB',
    symbol: '฿',
  },
  {
    locale: 'en-PH',
    code: 'PHP',
    symbol: '₱',
  },
  {
    locale: 'vi-VN',
    code: 'VND',
    symbol: '₫',
  },
];
