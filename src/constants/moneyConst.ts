import { Currency, DefaultColors } from '@/schema/common';

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
    code: 'USD',
    symbol: '$',
    nameEn: 'US Dollar',
    nameZh: '美元',
  },
  {
    code: 'CNY',
    symbol: '¥',
    nameEn: 'Chinese Yuan',
    nameZh: '人民币',
  },
  {
    code: 'EUR',
    symbol: '€',
    nameEn: 'Euro',
    nameZh: '欧元',
  },
  {
    code: 'GBP',
    symbol: '£',
    nameEn: 'British Pound',
    nameZh: '英镑',
  },
  {
    code: 'JPY',
    symbol: '¥',
    nameEn: 'Japanese Yen',
    nameZh: '日元',
  },
  {
    code: 'AUD',
    symbol: 'A$',
    nameEn: 'Australian Dollar',
    nameZh: '澳大利亚元',
  },
  {
    code: 'CAD',
    symbol: 'C$',
    nameEn: 'Canadian Dollar',
    nameZh: '加拿大元',
  },
  {
    code: 'CHF',
    symbol: '₣',
    nameEn: 'Swiss Franc',
    nameZh: '瑞士法郎',
  },
  {
    code: 'HKD',
    symbol: 'HK$',
    nameEn: 'Hong Kong Dollar',
    nameZh: '港币',
  },
  {
    code: 'SGD',
    symbol: 'S$',
    nameEn: 'Singapore Dollar',
    nameZh: '新加坡元',
  },
  {
    code: 'KRW',
    symbol: '₩',
    nameEn: 'South Korean Won',
    nameZh: '韩元',
  },
  {
    code: 'INR',
    symbol: '₹',
    nameEn: 'Indian Rupee',
    nameZh: '印度卢比',
  },
  {
    code: 'RUB',
    symbol: '₽',
    nameEn: 'Russian Ruble',
    nameZh: '俄罗斯卢布',
  },
  {
    code: 'BRL',
    symbol: 'R$',
    nameEn: 'Brazilian Real',
    nameZh: '巴西雷亚尔',
  },
  {
    code: 'ZAR',
    symbol: 'R',
    nameEn: 'South African Rand',
    nameZh: '南非兰特',
  },
  {
    code: 'SEK',
    symbol: 'kr',
    nameEn: 'Swedish Krona',
    nameZh: '瑞典克朗',
  },
  {
    code: 'NZD',
    symbol: 'NZ$',
    nameEn: 'New Zealand Dollar',
    nameZh: '新西兰元',
  },
  {
    code: 'THB',
    symbol: '฿',
    nameEn: 'Thai Baht',
    nameZh: '泰铢',
  },
  {
    code: 'PHP',
    symbol: '₱',
    nameEn: 'Philippine Peso',
    nameZh: '菲律宾比索',
  },
  {
    code: 'VND',
    symbol: '₫',
    nameEn: 'Vietnamese Dong',
    nameZh: '越南盾',
  },
];
