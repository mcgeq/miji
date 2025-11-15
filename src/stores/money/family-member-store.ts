// src/stores/money/family-member-store.ts
import { defineStore } from 'pinia';
import type {
  FamilyMember,
  FamilyMemberCreate,
  FamilyMemberUpdate,
  MemberFinancialStats,
} from '@/schema/money';

interface FamilyMemberStoreState {
  members: FamilyMember[];
  memberStats: Record<string, MemberFinancialStats>;
  loading: boolean;
  error: string | null;
  currentLedgerSerialNum: string | null;
}

/**
 * 家庭成员管理 Store
 * 负责家庭成员的CRUD操作、权限管理和统计
 */
export const useFamilyMemberStore = defineStore('family-member', {
  state: (): FamilyMemberStoreState => ({
    members: [],
    memberStats: {},
    loading: false,
    error: null,
    currentLedgerSerialNum: null,
  }),

  getters: {
    /**
     * 获取当前账本的成员
     */
    currentLedgerMembers: state => {
      if (!state.currentLedgerSerialNum) return [];
      // TODO: 需要根据实际的关联关系过滤，现在返回所有成员
      return state.members;
    },

    /**
     * 获取主要成员（账本创建者）
     */
    primaryMembers: state => state.members.filter(member => member.isPrimary),

    /**
     * 获取管理员成员
     */
    adminMembers: state => state.members.filter(member =>
      member.role === 'Admin' || member.role === 'Owner',
    ),

    /**
     * 获取普通成员
     */
    regularMembers: state => state.members.filter(member =>
      member.role === 'Member',
    ),

    /**
     * 根据ID获取成员
     */
    getMemberById: state => (id: string) => {
      return state.members.find(member => member.serialNum === id);
    },

    /**
     * 根据用户ID获取成员
     */
    getMemberByUserId: state => (userId: string) => {
      return state.members.find(member => member.userSerialNum === userId);
    },

    /**
     * 获取成员的财务统计
     */
    getMemberStats: state => (memberId: string) => {
      return state.memberStats[memberId] || null;
    },

    /**
     * 检查成员是否有特定权限
     */
    hasPermission: state => (memberId: string, permission: string) => {
      const member = state.members.find(m => m.serialNum === memberId);
      if (!member) return false;

      // 解析权限字符串（假设是JSON格式）
      try {
        const permissions = JSON.parse(member.permissions);
        return permissions.includes(permission);
      } catch {
        return false;
      }
    },

    /**
     * 获取有债务的成员
     */
    membersWithDebt: state => {
      return state.members.filter(member => {
        const stats = state.memberStats[member.serialNum];
        return stats && stats.netBalance < 0;
      });
    },

    /**
     * 获取有债权的成员
     */
    membersWithCredit: state => {
      return state.members.filter(member => {
        const stats = state.memberStats[member.serialNum];
        return stats && stats.netBalance > 0;
      });
    },
  },

  actions: {
    /**
     * 设置当前账本
     */
    setCurrentLedger(ledgerSerialNum: string) {
      this.currentLedgerSerialNum = ledgerSerialNum;
    },

    /**
     * 获取成员列表
     */
    async fetchMembers(ledgerSerialNum?: string) {
      this.loading = true;
      this.error = null;

      try {
        const { MoneyDb } = await import('@/services/money/money');

        if (ledgerSerialNum) {
          // 获取特定账本的成员
          const ledgerMembers = await MoneyDb.listFamilyLedgerMembers();
          const memberIds = ledgerMembers
            .filter(lm => lm.familyLedgerSerialNum === ledgerSerialNum)
            .map(lm => lm.familyMemberSerialNum);

          // 获取成员详情
          const memberPromises = memberIds.map(id => MoneyDb.getFamilyMember(id));
          const members = await Promise.all(memberPromises);
          this.members = members.filter(m => m !== null) as FamilyMember[];
        } else {
          // 获取所有成员
          this.members = await MoneyDb.listFamilyMembers();
        }
      } catch (error: any) {
        this.error = error.message || '获取成员列表失败';
        throw error;
      } finally {
        this.loading = false;
      }
    },

    /**
     * 创建成员
     */
    async createMember(data: FamilyMemberCreate): Promise<FamilyMember> {
      this.loading = true;
      this.error = null;

      try {
        const { MoneyDb } = await import('@/services/money/money');
        const member = await MoneyDb.createFamilyMember(data);

        // 添加到本地状态
        this.members.push(member);

        // 如果有当前账本，创建账本-成员关联
        if (this.currentLedgerSerialNum) {
          await MoneyDb.createFamilyLedgerMember({
            familyLedgerSerialNum: this.currentLedgerSerialNum,
            familyMemberSerialNum: member.serialNum,
          });

          // 更新账本的成员数量
          await this.updateLedgerMemberCount(this.currentLedgerSerialNum);
        }

        return member;
      } catch (error: any) {
        this.error = error.message || '创建成员失败';
        throw error;
      } finally {
        this.loading = false;
      }
    },

    /**
     * 更新成员
     */
    async updateMember(serialNum: string, data: FamilyMemberUpdate): Promise<FamilyMember> {
      this.loading = true;
      this.error = null;

      try {
        const { MoneyDb } = await import('@/services/money/money');
        const updatedMember = await MoneyDb.updateFamilyMember(serialNum, data);

        // 更新本地状态
        const index = this.members.findIndex(m => m.serialNum === serialNum);
        if (index !== -1) {
          this.members[index] = updatedMember;
        }

        return updatedMember;
      } catch (error: any) {
        this.error = error.message || '更新成员失败';
        throw error;
      } finally {
        this.loading = false;
      }
    },

    /**
     * 删除成员
     */
    async deleteMember(serialNum: string): Promise<void> {
      this.loading = true;
      this.error = null;

      try {
        const { MoneyDb } = await import('@/services/money/money');
        await MoneyDb.deleteFamilyMember(serialNum);

        // 更新本地状态
        this.members = this.members.filter(m => m.serialNum !== serialNum);

        // 清理统计数据
        delete this.memberStats[serialNum];

        // 如果有当前账本，更新账本的成员数量
        if (this.currentLedgerSerialNum) {
          await this.updateLedgerMemberCount(this.currentLedgerSerialNum);
        }
      } catch (error: any) {
        this.error = error.message || '删除成员失败';
        throw error;
      } finally {
        this.loading = false;
      }
    },

    /**
     * 更新成员权限
     */
    async updateMemberPermissions(serialNum: string, permissions: string[]): Promise<void> {
      const permissionsJson = JSON.stringify(permissions);
      await this.updateMember(serialNum, { permissions: permissionsJson });
    },

    /**
     * 更新成员角色
     */
    async updateMemberRole(serialNum: string, role: FamilyMember['role']): Promise<void> {
      await this.updateMember(serialNum, { role });
    },

    /**
     * 获取成员财务统计
     */
    async fetchMemberStats(serialNum: string): Promise<MemberFinancialStats> {
      try {
        // TODO: 替换为实际的API调用
        // const stats = await FamilyApi.getMemberStats(serialNum);
        // console.log('Fetching member stats:', serialNum);

        // 临时模拟统计数据
        const stats: MemberFinancialStats = {
          memberSerialNum: serialNum,
          memberName: this.getMemberById(serialNum)?.name || 'Unknown',
          totalPaid: 0,
          totalOwed: 0,
          netBalance: 0,
          pendingSettlement: 0,
          transactionCount: 0,
          splitCount: 0,
        };

        this.memberStats[serialNum] = stats;
        return stats;
      } catch (error: any) {
        console.error('获取成员统计失败:', error);
        throw error;
      }
    },

    /**
     * 刷新所有成员统计
     */
    async refreshAllMemberStats(): Promise<void> {
      const promises = this.members.map(member =>
        this.fetchMemberStats(member.serialNum),
      );
      await Promise.all(promises);
    },

    /**
     * 邀请用户加入账本
     */
    async inviteUser(_email: string, _role: FamilyMember['role'] = 'Member'): Promise<void> {
      this.loading = true;
      this.error = null;

      try {
        // TODO: 替换为实际的API调用
        // await FamilyApi.inviteUser(email, role);
        // console.log('Inviting user:', email, role);

        // 临时模拟邀请逻辑
        // 实际实现中应该发送邀请邮件或通知
      } catch (error: any) {
        this.error = error.message || '邀请用户失败';
        throw error;
      } finally {
        this.loading = false;
      }
    },

    /**
     * 移除成员（软删除，保留历史数据）
     */
    async removeMember(serialNum: string): Promise<void> {
      // 检查成员是否有未结算的债务
      const stats = this.memberStats[serialNum];
      if (stats && Math.abs(stats.netBalance) > 0.01) {
        throw new Error('该成员有未结算的债务，无法移除');
      }

      await this.deleteMember(serialNum);
    },

    /**
     * 更新账本的成员数量
     */
    async updateLedgerMemberCount(ledgerSerialNum: string): Promise<void> {
      try {
        const { MoneyDb } = await import('@/services/money/money');

        // 获取该账本的所有成员关联
        const ledgerMembers = await MoneyDb.listFamilyLedgerMembers();
        const memberCount = ledgerMembers.filter(
          lm => lm.familyLedgerSerialNum === ledgerSerialNum,
        ).length;

        // 更新账本的成员数量
        await MoneyDb.updateFamilyLedger(ledgerSerialNum, { memberCount });

        // 同步更新 ledger store
        const { useFamilyLedgerStore } = await import('./family-ledger-store');
        const ledgerStore = useFamilyLedgerStore();
        await ledgerStore.fetchLedgers();
      } catch (error) {
        console.error('Failed to update ledger member count:', error);
      }
    },

    /**
     * 清空错误状态
     */
    clearError() {
      this.error = null;
    },

    /**
     * 重置store状态
     */
    reset() {
      this.members = [];
      this.memberStats = {};
      this.loading = false;
      this.error = null;
      this.currentLedgerSerialNum = null;
    },
  },
});
