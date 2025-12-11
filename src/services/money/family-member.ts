/**
 * 家庭成员 Service
 *
 * 提供家庭成员的CRUD、权限管理、统计查询等功能
 */

import { invokeCommand } from '@/types/api';

// ==================== 类型定义 ====================

export interface FamilyMember {
  serialNum: string;
  userSerialNum?: string;
  name: string;
  nickname?: string;
  role: 'Owner' | 'Admin' | 'Member' | 'Viewer';
  permissions: string; // JSON string
  isPrimary: boolean;
  avatarUrl?: string;
  colorCode?: string;
  status: 'active' | 'inactive' | 'invited';
  joinedAt?: string;
  createdAt: string;
  updatedAt?: string;
}

export interface FamilyMemberCreate {
  userSerialNum?: string;
  name: string;
  nickname?: string;
  role?: 'Admin' | 'Member' | 'Viewer';
  permissions?: string;
  isPrimary?: boolean;
  avatarUrl?: string;
  colorCode?: string;
}

export interface FamilyMemberUpdate {
  name?: string;
  nickname?: string;
  role?: 'Admin' | 'Member' | 'Viewer';
  permissions?: string;
  avatarUrl?: string;
  colorCode?: string;
  status?: 'active' | 'inactive';
}

export interface MemberFinancialStats {
  memberSerialNum: string;
  memberName: string;
  totalPaid: number;
  totalOwed: number;
  netBalance: number;
  pendingSettlement: number;
  transactionCount: number;
  splitCount: number;
}

export interface MemberTransactionParams {
  memberSerialNum: string;
  familyLedgerSerialNum?: string;
  startDate?: string;
  endDate?: string;
  page?: number;
  pageSize?: number;
}

export interface MemberInvitation {
  email: string;
  role: 'Admin' | 'Member' | 'Viewer';
  familyLedgerSerialNum: string;
  expiresAt?: string;
}

// ==================== Service 方法 ====================

export const familyMemberService = {
  /**
   * 获取成员列表
   */
  async listMembers(): Promise<FamilyMember[]> {
    return invokeCommand('family_member_list', {});
  },

  /**
   * 获取单个成员详情
   */
  async getMember(serialNum: string): Promise<FamilyMember> {
    return invokeCommand('family_member_get', {
      serial_num: serialNum,
    });
  },

  /**
   * 创建成员
   */
  async createMember(data: FamilyMemberCreate): Promise<FamilyMember> {
    return invokeCommand('family_member_create', {
      user_serial_num: data.userSerialNum,
      name: data.name,
      nickname: data.nickname,
      role: data.role || 'Member',
      permissions: data.permissions || '[]',
      is_primary: data.isPrimary,
      avatar_url: data.avatarUrl,
      color_code: data.colorCode,
    });
  },

  /**
   * 更新成员
   */
  async updateMember(serialNum: string, data: FamilyMemberUpdate): Promise<FamilyMember> {
    return invokeCommand('family_member_update', {
      serial_num: serialNum,
      name: data.name,
      nickname: data.nickname,
      role: data.role,
      permissions: data.permissions,
      avatar_url: data.avatarUrl,
      color_code: data.colorCode,
      status: data.status,
    });
  },

  /**
   * 删除成员
   */
  async deleteMember(serialNum: string): Promise<void> {
    return invokeCommand('family_member_delete', {
      serial_num: serialNum,
    });
  },

  /**
   * 获取成员权限
   */
  async getMemberPermissions(serialNum: string): Promise<string[]> {
    const member = await this.getMember(serialNum);
    try {
      return JSON.parse(member.permissions);
    } catch {
      return [];
    }
  },

  /**
   * 更新成员权限
   */
  async updateMemberPermissions(serialNum: string, permissions: string[]): Promise<FamilyMember> {
    return this.updateMember(serialNum, {
      permissions: JSON.stringify(permissions),
    });
  },

  /**
   * 更新成员角色
   */
  async updateMemberRole(
    serialNum: string,
    role: 'Admin' | 'Member' | 'Viewer',
  ): Promise<FamilyMember> {
    return this.updateMember(serialNum, { role });
  },

  /**
   * 获取成员财务统计
   * 注意：这个需要后端实现对应的Command
   */
  async getMemberStats(
    memberSerialNum: string,
    _familyLedgerSerialNum?: string,
  ): Promise<MemberFinancialStats> {
    // TODO: 替换为实际的后端Command
    // return invokeCommand('family_member_stats', {
    //   member_serial_num: memberSerialNum,
    //   family_ledger_serial_num: familyLedgerSerialNum,
    // });

    // 临时返回模拟数据
    return {
      memberSerialNum,
      memberName: 'Unknown',
      totalPaid: 0,
      totalOwed: 0,
      netBalance: 0,
      pendingSettlement: 0,
      transactionCount: 0,
      splitCount: 0,
    };
  },

  /**
   * 获取成员交易记录
   * 注意：这个需要调用transaction service
   */
  async getMemberTransactions(params: MemberTransactionParams) {
    // TODO: 调用transaction service
    // import { transactionService } from './transaction';
    // return transactionService.listTransactions({
    //   familyLedgerSerialNum: params.familyLedgerSerialNum,
    //   memberSerialNum: params.memberSerialNum,
    //   startDate: params.startDate,
    //   endDate: params.endDate,
    //   page: params.page,
    //   pageSize: params.pageSize,
    // });

    return {
      rows: [],
      totalCount: 0,
      currentPage: params.page || 1,
      pageSize: params.pageSize || 20,
      totalPages: 0,
    };
  },

  /**
   * 获取成员分摊记录
   * 注意：这个需要调用split service
   */
  async getMemberSplitRecords(params: MemberTransactionParams) {
    // TODO: 调用split service
    return {
      rows: [],
      totalCount: 0,
      currentPage: params.page || 1,
      pageSize: params.pageSize || 20,
      totalPages: 0,
    };
  },

  /**
   * 获取成员债务关系
   * 使用已有的debt service
   */
  async getMemberDebtRelations(memberSerialNum: string, familyLedgerSerialNum: string) {
    const { debtService } = await import('./debt');
    return debtService.listRelations({
      familyLedgerSerialNum,
      memberSerialNum,
    });
  },

  /**
   * 邀请用户加入账本
   * 注意：这个需要后端实现对应的Command
   */
  async inviteUser(data: MemberInvitation): Promise<void> {
    // TODO: 实现邀请逻辑
    // return invokeCommand('family_member_invite', {
    //   email: data.email,
    //   role: data.role,
    //   family_ledger_serial_num: data.familyLedgerSerialNum,
    //   expires_at: data.expiresAt,
    // });

    // eslint-disable-next-line no-console
    console.log('Invite user:', data);
  },

  /**
   * 接受邀请
   * 注意：这个需要后端实现对应的Command
   */
  async acceptInvitation(_token: string): Promise<FamilyMember> {
    // TODO: 实现接受邀请逻辑
    // return invokeCommand('family_member_accept_invitation', { token });

    throw new Error('Not implemented');
  },

  /**
   * 批量获取成员
   */
  async batchGetMembers(serialNums: string[]): Promise<FamilyMember[]> {
    const promises = serialNums.map(sn => this.getMember(sn));
    return Promise.all(promises);
  },

  /**
   * 检查成员名称是否可用
   */
  async checkNameAvailable(name: string): Promise<boolean> {
    try {
      const members = await this.listMembers();
      return !members.some(m => m.name === name);
    } catch {
      return true;
    }
  },
};
