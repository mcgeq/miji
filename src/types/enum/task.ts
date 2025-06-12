export const Priority = {
  Low: 0,
  Medium: 1,
  High: 2,
  Urgent: 3,
} as const;

export type Priority = (typeof Priority)[keyof typeof Priority];

export const Status = {
  NotStarted: 0,
  InProgress: 1,
  Completed: 2,
  Cancelled: 3,
  Overdue: 4,
} as const;

export type Status = (typeof Status)[keyof typeof Status];
