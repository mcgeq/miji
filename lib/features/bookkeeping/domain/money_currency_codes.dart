/// 记账模块统一币种：所有账户的支出、收入、转账均使用同一币种，
/// 不维护汇率换算层。
const defaultMoneyCurrencyCode = 'CNY';

const supportedMoneyCurrencyCodes = <String>[
  'CNY',
  'USD',
  'EUR',
  'JPY',
  'HKD',
  'GBP',
  'AUD',
  'CAD',
  'SGD',
  'KRW',
];
