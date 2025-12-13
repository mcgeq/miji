// composables/usePermission.ts

import { AppErrorSeverity } from '@/errors/appError';
import type { FamilyMember } from '@/schema/money';
import { useAuthStore } from '@/stores/auth';
import { useFamilyLedgerStore, useFamilyMemberStore } from '@/stores/money';
import { throwAppError } from '@/utils/errorHandler';

/**
 * 权限管理 Composable
 * 提供家庭账本的权限验证功能
 */
export function usePermission() {
  const authStore = useAuthStore();
  const familyLedgerStore = useFamilyLedgerStore();
  const familyMemberStore = useFamilyMemberStore();

  /**
   * 获取当前用户在当前账本中的成员信息
   */
  const currentMember = computed<FamilyMember | null>(() => {
    const currentUser = authStore.user;
    if (!(currentUser && familyLedgerStore.currentLedger)) {
      return null;
    }

    return familyMemberStore.getMemberByUserId(currentUser.serialNum) || null;
  });

  /**
   * 获取当前用户的角色
   */
  const currentRole = computed(() => {
    return currentMember.value?.role || null;
  });

  /**
   * 检查是否是账本所有者
   */
  const isOwner = computed(() => {
    return currentRole.value === 'Owner';
  });

  /**
   * 检查是否是管理员（包括所有者）
   */
  const isAdmin = computed(() => {
    return currentRole.value === 'Owner' || currentRole.value === 'Admin';
  });

  /**
   * 检查是否是主要成员
   */
  const isPrimary = computed(() => {
    return currentMember.value?.isPrimary;
  });

  /**
   * 解析权限字符串
   */
  function parsePermissions(permissionsStr: string): string[] {
    try {
      return JSON.parse(permissionsStr);
    } catch {
      return [];
    }
  }

  /**
   * 检查是否有特定权限
   */
  function hasPermission(permission: string): boolean {
    if (!currentMember.value) {
      return false;
    }

    // 所有者拥有所有权限
    if (isOwner.value) {
      return true;
    }

    // 检查具体权限
    const permissions = parsePermissions(currentMember.value.permissions);
    return permissions.includes(permission);
  }

  /**
   * 检查是否可以编辑
   */
  const canEdit = computed(() => {
    return hasPermission('edit') || isAdmin.value;
  });

  /**
   * 检查是否可以删除
   */
  const canDelete = computed(() => {
    return hasPermission('delete') || isOwner.value;
  });

  /**
   * 检查是否可以添加交易
   */
  const canAddTransaction = computed(() => {
    return hasPermission('transaction:add') || isAdmin.value;
  });

  /**
   * 检查是否可以编辑交易
   */
  const canEditTransaction = computed(() => {
    return hasPermission('transaction:edit') || isAdmin.value;
  });

  /**
   * 检查是否可以删除交易
   */
  const canDeleteTransaction = computed(() => {
    return hasPermission('transaction:delete') || isAdmin.value;
  });

  /**
   * 检查是否可以管理成员
   */
  const canManageMembers = computed(() => {
    return hasPermission('member:manage') || isAdmin.value;
  });

  /**
   * 检查是否可以添加成员
   */
  const canAddMember = computed(() => {
    return hasPermission('member:add') || isAdmin.value;
  });

  /**
   * 检查是否可以移除成员
   */
  const canRemoveMember = computed(() => {
    return hasPermission('member:remove') || isOwner.value;
  });

  /**
   * 检查是否可以管理分摊规则
   */
  const canManageSplitRules = computed(() => {
    return hasPermission('split:manage') || isAdmin.value;
  });

  /**
   * 检查是否可以创建分摊
   */
  const canCreateSplit = computed(() => {
    return hasPermission('split:create') || isAdmin.value;
  });

  /**
   * 检查是否可以查看财务统计
   */
  const canViewStats = computed(() => {
    return true; // 默认所有成员都可以查看基础统计
  });

  /**
   * 检查是否可以查看详细财务数据
   */
  const canViewDetailedStats = computed(() => {
    return hasPermission('stats:detailed') || isAdmin.value;
  });

  /**
   * 检查是否可以进行结算
   */
  const canSettle = computed(() => {
    return hasPermission('settlement:execute') || isAdmin.value;
  });

  /**
   * 检查是否可以查看结算记录
   */
  const canViewSettlement = computed(() => {
    return true; // 默认所有成员都可以查看
  });

  /**
   * 检查是否可以导出数据
   */
  const canExportData = computed(() => {
    return hasPermission('data:export') || isAdmin.value;
  });

  /**
   * 获取权限错误消息
   */
  function getPermissionErrorMessage(action: string): string {
    return `您没有权限执行此操作: ${action}`;
  }

  /**
   * 权限检查装饰器函数
   */
  function requirePermission(permission: string, errorMessage?: string) {
    return (_target: object, _propertyKey: string, descriptor: PropertyDescriptor) => {
      const originalMethod = descriptor.value;

      descriptor.value = function (...args: unknown[]) {
        if (!hasPermission(permission)) {
          throwAppError(
            'Permission',
            'PERMISSION_DENIED',
            errorMessage || getPermissionErrorMessage(permission),
            AppErrorSeverity.MEDIUM,
          );
        }
        return originalMethod.apply(this, args);
      };
    };
  }

  return {
    // 状态
    currentMember,
    currentRole,
    isOwner,
    isAdmin,
    isPrimary,

    // 方法
    hasPermission,
    parsePermissions,
    getPermissionErrorMessage,
    requirePermission,

    // 具体权限检查
    canEdit,
    canDelete,
    canAddTransaction,
    canEditTransaction,
    canDeleteTransaction,
    canManageMembers,
    canAddMember,
    canRemoveMember,
    canManageSplitRules,
    canCreateSplit,
    canViewStats,
    canViewDetailedStats,
    canSettle,
    canViewSettlement,
    canExportData,
  };
}
