/**
 * 认证系统类型定义
 */

/**
 * 权限枚举
 */
export enum Permission {
  // 交易权限
  TRANSACTION_VIEW = 'transaction:view',
  TRANSACTION_CREATE = 'transaction:create',
  TRANSACTION_EDIT = 'transaction:edit',
  TRANSACTION_DELETE = 'transaction:delete',

  // 账户权限
  ACCOUNT_VIEW = 'account:view',
  ACCOUNT_CREATE = 'account:create',
  ACCOUNT_EDIT = 'account:edit',
  ACCOUNT_DELETE = 'account:delete',

  // 预算权限
  BUDGET_VIEW = 'budget:view',
  BUDGET_CREATE = 'budget:create',
  BUDGET_EDIT = 'budget:edit',
  BUDGET_DELETE = 'budget:delete',

  // 提醒权限
  REMINDER_VIEW = 'reminder:view',
  REMINDER_CREATE = 'reminder:create',
  REMINDER_EDIT = 'reminder:edit',
  REMINDER_DELETE = 'reminder:delete',

  // 家庭账本权限
  LEDGER_VIEW = 'ledger:view',
  LEDGER_CREATE = 'ledger:create',
  LEDGER_EDIT = 'ledger:edit',
  LEDGER_DELETE = 'ledger:delete',
  LEDGER_ADMIN = 'ledger:admin',

  // 成员权限
  MEMBER_VIEW = 'member:view',
  MEMBER_MANAGE = 'member:manage',

  // 设置权限
  SETTINGS_VIEW = 'settings:view',
  SETTINGS_MANAGE = 'settings:manage',

  // 统计权限
  STATS_VIEW = 'stats:view',
}

/**
 * 角色枚举
 */
export enum Role {
  /** 访客 - 只读权限 */
  GUEST = 'guest',
  /** 普通用户 - 基础操作权限 */
  USER = 'user',
  /** 管理员 - 完整操作权限 */
  ADMIN = 'admin',
  /** 所有者 - 所有权限 */
  OWNER = 'owner',
}

/**
 * 访客权限
 */
const GUEST_PERMISSIONS: Permission[] = [
  Permission.TRANSACTION_VIEW,
  Permission.ACCOUNT_VIEW,
  Permission.BUDGET_VIEW,
  Permission.REMINDER_VIEW,
  Permission.LEDGER_VIEW,
  Permission.STATS_VIEW,
];

/**
 * 用户权限
 */
const USER_PERMISSIONS: Permission[] = [
  // 继承访客权限
  ...GUEST_PERMISSIONS,

  // 创建权限
  Permission.TRANSACTION_CREATE,
  Permission.ACCOUNT_CREATE,
  Permission.BUDGET_CREATE,
  Permission.REMINDER_CREATE,

  // 编辑自己的内容
  Permission.TRANSACTION_EDIT,
  Permission.ACCOUNT_EDIT,
  Permission.BUDGET_EDIT,
  Permission.REMINDER_EDIT,

  // 查看设置
  Permission.SETTINGS_VIEW,
];

/**
 * 管理员权限
 */
const ADMIN_PERMISSIONS: Permission[] = [
  // 继承用户权限
  ...USER_PERMISSIONS,

  // 删除权限
  Permission.TRANSACTION_DELETE,
  Permission.ACCOUNT_DELETE,
  Permission.BUDGET_DELETE,
  Permission.REMINDER_DELETE,

  // 账本管理
  Permission.LEDGER_EDIT,
  Permission.LEDGER_DELETE,
  Permission.MEMBER_VIEW,
  Permission.MEMBER_MANAGE,

  // 设置管理
  Permission.SETTINGS_MANAGE,
];

/**
 * 角色权限映射
 */
export const RolePermissions: Record<Role, Permission[]> = {
  [Role.GUEST]: GUEST_PERMISSIONS,
  [Role.USER]: USER_PERMISSIONS,
  [Role.ADMIN]: ADMIN_PERMISSIONS,
  [Role.OWNER]: Object.values(Permission),
};

/**
 * 检查角色是否有指定权限
 */
export function roleHasPermission(role: Role, permission: Permission): boolean {
  return RolePermissions[role]?.includes(permission) ?? false;
}

/**
 * 检查角色是否有任一权限
 */
export function roleHasAnyPermission(role: Role, permissions: Permission[]): boolean {
  return permissions.some(p => roleHasPermission(role, p));
}

/**
 * 检查角色是否有所有权限
 */
export function roleHasAllPermissions(role: Role, permissions: Permission[]): boolean {
  return permissions.every(p => roleHasPermission(role, p));
}
