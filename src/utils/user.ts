import type { AuthUser, User } from '../schema/user';

export function toAuthUser(user: User): AuthUser {
  return {
    serialNum: user.serialNum,
    name: user.name,
    email: user.email,
    avatarUrl: user.avatarUrl ?? null,
    role: user.role,
    timezone: user.timezone ?? 'UTC',
    language: user.language ?? 'en',
  };
}
