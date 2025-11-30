/**
 * 权限审计日志系统
 * 记录所有权限相关的操作和检查
 */
import { Lg } from './debugLog';
import type { Permission, Role } from '@/types/auth';

export interface AuditLogEntry {
  /** 时间戳 */
  timestamp: number;
  /** 事件类型 */
  type: 'login' | 'logout' | 'permission_check' | 'permission_denied' | 'role_change';
  /** 用户标识 */
  userId?: string;
  /** 用户角色 */
  userRole?: Role;
  /** 检查的权限 */
  permission?: Permission;
  /** 检查的权限列表 */
  permissions?: Permission[];
  /** 检查结果 */
  result?: 'granted' | 'denied';
  /** 目标资源 */
  resource?: string;
  /** 额外信息 */
  metadata?: Record<string, any>;
}

class AuthAuditLogger {
  private logs: AuditLogEntry[] = [];
  private maxLogs = 1000; // 最多保存1000条日志
  private enabled = true;

  /**
   * 记录登录事件
   */
  logLogin(userId: string, role: Role, metadata?: Record<string, any>) {
    this.addLog({
      type: 'login',
      userId,
      userRole: role,
      metadata,
    });

    Lg.i('AuthAudit', '🔐 User logged in', { userId, role });
  }

  /**
   * 记录登出事件
   */
  logLogout(userId: string, metadata?: Record<string, any>) {
    this.addLog({
      type: 'logout',
      userId,
      metadata,
    });

    Lg.i('AuthAudit', '🚪 User logged out', { userId });
  }

  /**
   * 记录权限检查（通过）
   */
  logPermissionGranted(
    userId: string,
    userRole: Role,
    permissions: Permission[],
    resource?: string,
    metadata?: Record<string, any>,
  ) {
    this.addLog({
      type: 'permission_check',
      userId,
      userRole,
      permissions,
      result: 'granted',
      resource,
      metadata,
    });

    if (this.isDebugMode()) {
      Lg.d('AuthAudit', '✅ Permission granted', {
        userId,
        role: userRole,
        permissions,
        resource,
      });
    }
  }

  /**
   * 记录权限检查（拒绝）
   */
  logPermissionDenied(
    userId: string,
    userRole: Role,
    permissions: Permission[],
    effectivePermissions: Permission[],
    resource?: string,
    metadata?: Record<string, any>,
  ) {
    this.addLog({
      type: 'permission_denied',
      userId,
      userRole,
      permissions,
      result: 'denied',
      resource,
      metadata: {
        ...metadata,
        effectivePermissions,
      },
    });

    Lg.w('AuthAudit', '❌ Permission denied', {
      userId,
      role: userRole,
      required: permissions,
      effective: effectivePermissions,
      resource,
    });
  }

  /**
   * 记录角色变更
   */
  logRoleChange(userId: string, oldRole: Role, newRole: Role, metadata?: Record<string, any>) {
    this.addLog({
      type: 'role_change',
      userId,
      userRole: newRole,
      metadata: {
        ...metadata,
        oldRole,
      },
    });

    Lg.i('AuthAudit', '🔄 Role changed', { userId, from: oldRole, to: newRole });
  }

  /**
   * 添加日志条目
   */
  private addLog(entry: Omit<AuditLogEntry, 'timestamp'>) {
    if (!this.enabled) return;

    const logEntry: AuditLogEntry = {
      ...entry,
      timestamp: Date.now(),
    };

    this.logs.push(logEntry);

    // 限制日志数量
    if (this.logs.length > this.maxLogs) {
      this.logs.shift();
    }
  }

  /**
   * 获取所有日志
   */
  getLogs(): AuditLogEntry[] {
    return [...this.logs];
  }

  /**
   * 获取指定用户的日志
   */
  getUserLogs(userId: string): AuditLogEntry[] {
    return this.logs.filter(log => log.userId === userId);
  }

  /**
   * 获取指定类型的日志
   */
  getLogsByType(type: AuditLogEntry['type']): AuditLogEntry[] {
    return this.logs.filter(log => log.type === type);
  }

  /**
   * 获取被拒绝的权限检查日志
   */
  getDeniedLogs(): AuditLogEntry[] {
    return this.logs.filter(log => log.type === 'permission_denied' || log.result === 'denied');
  }

  /**
   * 获取指定时间范围的日志
   */
  getLogsByTimeRange(startTime: number, endTime: number): AuditLogEntry[] {
    return this.logs.filter(log => log.timestamp >= startTime && log.timestamp <= endTime);
  }

  /**
   * 清空日志
   */
  clearLogs() {
    this.logs = [];
    Lg.i('AuthAudit', 'Audit logs cleared');
  }

  /**
   * 导出日志为JSON
   */
  exportLogs(): string {
    return JSON.stringify(this.logs, null, 2);
  }

  /**
   * 生成日志统计报告
   */
  generateReport() {
    const totalLogs = this.logs.length;
    const loginCount = this.getLogsByType('login').length;
    const logoutCount = this.getLogsByType('logout').length;
    const deniedCount = this.getDeniedLogs().length;

    const roleDistribution: Record<string, number> = {};
    const permissionDenialCount: Record<string, number> = {};

    this.logs.forEach(log => {
      if (log.userRole) {
        roleDistribution[log.userRole] = (roleDistribution[log.userRole] || 0) + 1;
      }

      if (log.result === 'denied' && log.permissions) {
        log.permissions.forEach(perm => {
          permissionDenialCount[perm] = (permissionDenialCount[perm] || 0) + 1;
        });
      }
    });

    return {
      totalLogs,
      loginCount,
      logoutCount,
      deniedCount,
      denialRate: totalLogs > 0 ? `${((deniedCount / totalLogs) * 100).toFixed(2)}%` : '0%',
      roleDistribution,
      topDeniedPermissions: Object.entries(permissionDenialCount)
        .sort(([, a], [, b]) => b - a)
        .slice(0, 10)
        .map(([perm, count]) => ({ permission: perm, count })),
    };
  }

  /**
   * 启用/禁用审计日志
   */
  setEnabled(enabled: boolean) {
    this.enabled = enabled;
    Lg.i('AuthAudit', `Audit logging ${enabled ? 'enabled' : 'disabled'}`);
  }

  /**
   * 设置最大日志数量
   */
  setMaxLogs(max: number) {
    this.maxLogs = max;

    // 如果当前日志超过新限制，裁剪
    if (this.logs.length > max) {
      this.logs = this.logs.slice(-max);
    }
  }

  /**
   * 是否为调试模式
   */
  private isDebugMode(): boolean {
    // 可以根据环境变量或配置判断
    return import.meta.env.DEV;
  }
}

// 导出单例
export const authAudit = new AuthAuditLogger();

// 便捷方法
export const logLogin = authAudit.logLogin.bind(authAudit);
export const logLogout = authAudit.logLogout.bind(authAudit);
export const logPermissionGranted = authAudit.logPermissionGranted.bind(authAudit);
export const logPermissionDenied = authAudit.logPermissionDenied.bind(authAudit);
export const logRoleChange = authAudit.logRoleChange.bind(authAudit);
