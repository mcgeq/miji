import { z } from 'zod';

export const AccountTypeSchema = z.enum([
  'Savings', // 储蓄账户
  'Cash', // 现金
  'Bank', // 银行账户
  'CreditCard', // 信用卡
  'Investment', // 投资账户
  'Alipay', // 支付宝
  'WeChat', // 微信
  'CloudQuickPass', // 云闪付
  'Other', // 其他
]);
export type AccountType = z.infer<typeof AccountTypeSchema>;

export const PaymentMethodSchema = z.enum([
  'Savings', // 储蓄账户
  'Cash', // 现金支付
  'BankTransfer', // 银行转账
  'CreditCard', // 信用卡支付
  'WeChat', // 微信支付
  'Alipay', // 支付宝支付
  'CloudQuickPass', // 云闪付
  'JD', // 京东支付
  'UnionPay', // 银联支付
  'PayPal', // PayPal
  'ApplePay', // Apple Pay
  'GooglePay', // Google Pay
  'SamsungPay', // Samsung Pay
  'HuaweiPay', // 华为支付
  'MiPay', // 小米支付
  'Other', // 其他方式
]);
export type PaymentMethod = z.infer<typeof PaymentMethodSchema>;
