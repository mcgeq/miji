export const ReminderType = {
  Notification: 0,
  Email: 1,
  Popup: 2,
} as const;

export type ReminderType = (typeof ReminderType)[keyof typeof ReminderType];

export const RepeatPeriod = {
  Daily: 0,
  Weekly: 1,
  Monthy: 2,
  Quarterly: 3,
  Yearly: 4,
} as const;

export type RepeatPeriod = (typeof RepeatPeriod)[keyof typeof RepeatPeriod];
