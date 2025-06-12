export const AccountType = {
  Cash: 0,
  Bank: 1,
  CreditCard: 2,
  Investment: 3,
} as const;

export type AccountType = (typeof AccountType)[keyof typeof AccountType];

export const PaymentMethod = {
  Cash: 0,
  BankTransfer: 1,
  CreditCard: 2,
  WeChat: 3,
  Alipay: 4,
  Other: 5,
} as const;

export type PaymentMethod = (typeof PaymentMethod)[keyof typeof PaymentMethod];
