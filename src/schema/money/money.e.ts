import { z } from 'zod/v4';

export const AccountTypeSchema = z.enum([
  'Cash',
  'Bank',
  'CreditCard',
  'Investment',
]);
export type AccountType = z.infer<typeof AccountTypeSchema>;

export const PaymentMethodSchema = z.enum([
  'Cash',
  'BankTransfer',
  'CreditCard',
  'WeChat',
  'Alipay',
  'Other',
]);
export type PaymentMethod = z.infer<typeof PaymentMethodSchema>;
