/**
 * 用户数据转换工具
 *
 * 使用 es-toolkit 优化对象选择
 */

import { pick } from 'es-toolkit';
import type { AuthUser, User } from '../schema/user';

/**
 * 将 User 转换为 AuthUser
 * 使用 es-toolkit 的 pick 优化性能
 *
 * @param user - 完整用户对象
 * @returns 认证用户对象
 */
export function toAuthUser(user: User): AuthUser {
  // 使用 es-toolkit 的 pick 提取字段
  const picked = pick(user, ['serialNum', 'name', 'email', 'role'] as const);

  // 添加默认值
  return {
    ...picked,
    avatarUrl: user.avatarUrl ?? null,
    timezone: user.timezone ?? 'UTC',
    language: user.language ?? 'en',
  };
}
