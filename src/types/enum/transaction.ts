export const TransactionStatus = {
  Pending: 0,
  Completed: 1,
  Reversed: 2,
} as const;

export type TransactionStatus =
  (typeof TransactionStatus)[keyof typeof TransactionStatus];

export const TransactionType = {
  Income: 0,
  Expense: 1,
} as const;

export type TransactionType =
  (typeof TransactionType)[keyof typeof TransactionType];

export const Category = {
  Food: 0,
  Transport: 1,
  Entertainment: 2,
  Utilities: 3,
  Shopping: 4,
  Salary: 5,
  Investment: 6,
  Others: 7,
} as const;

export type Category = (typeof Category)[keyof typeof Category];

export const SubCategory = {
  // 食物类
  Restaurant: 0,
  Groceries: 1,
  Snacks: 2,

  // 交通类
  Bus: 10,
  Taxi: 11,
  Fuel: 12,

  // 娱乐类
  Movies: 20,
  Concerts: 21,

  // 工资类
  MonthlySalary: 30,
  Bonus: 31,

  // 其他
  Other: 99,
} as const;

export type SubCategory = (typeof SubCategory)[keyof typeof SubCategory];
