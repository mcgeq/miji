import type { AuthUser, User } from '../schema/user';

export function toAuthUser(user: User): AuthUser {
  return {
    serial_num: user.serial_num,
    name: user.name,
    email: user.email,
    avatar_url: user.avatar_url ?? null,
    role: user.role,
    timezone: user.timezone ?? 'UTC',
    language: user.language ?? 'en',
  };
}
