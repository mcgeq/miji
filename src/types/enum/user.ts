export const UserRole = {
  Admin: 0,
  User: 1,
  Moderator: 2,
  Editor: 3,
  Guest: 4,
  Developer: 5,
  Owner: 6,
} as const;

export type UserRole = (typeof UserRole)[keyof typeof UserRole];

export const UserStatus = {
  Active: 0,
  Inactive: 1,
  Suspended: 2,
  Banned: 3,
  Pending: 4,
  Deleted: 5,
} as const;

export type UserStatus = (typeof UserStatus)[keyof typeof UserStatus];
