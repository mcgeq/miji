// src/stores/money/family-split-store.ts
import { defineStore } from 'pinia';
import type {
  DebtRelation,
  SettlementSuggestion,
  SplitRecord,
  SplitRecordCreate,
  SplitResult,
  SplitRuleConfig,
  SplitRuleConfigCreate,
  SplitRuleConfigUpdate,
  SplitRuleType,
} from '@/schema/money';

interface FamilySplitStoreState {
  splitRules: SplitRuleConfig[];
  splitRecords: SplitRecord[];
  debtRelations: DebtRelation[];
  settlementSuggestions: SettlementSuggestion[];
  loading: boolean;
  error: string | null;
  currentLedgerSerialNum: string | null;
}

/**
 * 家庭分摊管理 Store
 * 负责分摊规则管理、分摊计算和模板管理
 */
export const useFamilySplitStore = defineStore('family-split', {
  state: (): FamilySplitStoreState => ({
    splitRules: [],
    splitRecords: [],
    debtRelations: [],
    settlementSuggestions: [],
    loading: false,
    error: null,
    currentLedgerSerialNum: null,
  }),

  getters: {
    /**
     * 获取当前账本的分摊规则
     */
    currentLedgerSplitRules: state => {
      if (!state.currentLedgerSerialNum) return [];
      return state.splitRules.filter(
        rule => rule.familyLedgerSerialNum === state.currentLedgerSerialNum,
      );
    },

    /**
     * 获取分摊模板
     */
    splitTemplates: state => state.splitRules.filter(rule => rule.isTemplate),

    /**
     * 获取激活的分摊规则
     */
    activeSplitRules: state => state.splitRules.filter(rule => rule.isActive),

    /**
     * 根据类型获取分摊规则
     */
    getSplitRulesByType: state => (type: SplitRuleType) => {
      return state.splitRules.filter(rule => rule.ruleType === type);
    },

    /**
     * 根据ID获取分摊规则
     */
    getSplitRuleById: state => (id: string) => {
      return state.splitRules.find(rule => rule.serialNum === id);
    },

    /**
     * 获取当前账本的分摊记录
     */
    currentLedgerSplitRecords: state => {
      if (!state.currentLedgerSerialNum) return [];
      return state.splitRecords.filter(
        record => record.familyLedgerSerialNum === state.currentLedgerSerialNum,
      );
    },

    /**
     * 获取未支付的分摊记录
     */
    unpaidSplitRecords: state => {
      return state.splitRecords.filter(record =>
        record.splitDetails.some(detail => !detail.isPaid),
      );
    },

    /**
     * 获取当前账本的债务关系
     */
    currentLedgerDebtRelations: state => {
      if (!state.currentLedgerSerialNum) return [];
      return state.debtRelations.filter(
        debt => debt.familyLedgerSerialNum === state.currentLedgerSerialNum,
      );
    },

    /**
     * 获取未结算的债务
     */
    unsettledDebts: state => state.debtRelations.filter(debt => !debt.isSettled),

    /**
     * 获取成员的债务关系
     */
    getMemberDebts: state => (memberSerialNum: string) => {
      return state.debtRelations.filter(
        debt => debt.debtorMemberSerialNum === memberSerialNum && !debt.isSettled,
      );
    },

    /**
     * 获取成员的债权关系
     */
    getMemberCredits: state => (memberSerialNum: string) => {
      return state.debtRelations.filter(
        debt => debt.creditorMemberSerialNum === memberSerialNum && !debt.isSettled,
      );
    },

    /**
     * 计算成员净余额
     */
    getMemberNetBalance: state => (memberSerialNum: string) => {
      const credits = state.debtRelations
        .filter(debt => debt.creditorMemberSerialNum === memberSerialNum && !debt.isSettled)
        .reduce((sum, debt) => sum + debt.amount, 0);

      const debts = state.debtRelations
        .filter(debt => debt.debtorMemberSerialNum === memberSerialNum && !debt.isSettled)
        .reduce((sum, debt) => sum + debt.amount, 0);

      return credits - debts;
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
     * 获取分摊规则列表
     */
    async fetchSplitRules(_ledgerSerialNum?: string) {
      this.loading = true;
      this.error = null;

      try {
        // TODO: 替换为实际的API调用
        // this.splitRules = await FamilyApi.listSplitRules(ledgerSerialNum);
        // console.log('Fetching split rules for ledger:', ledgerSerialNum);
        // 临时模拟数据
        this.splitRules = [];
      } catch (error: any) {
        this.error = error.message || '获取分摊规则失败';
        throw error;
      } finally {
        this.loading = false;
      }
    },

    /**
     * 创建分摊规则
     */
    async createSplitRule(data: SplitRuleConfigCreate): Promise<SplitRuleConfig> {
      this.loading = true;
      this.error = null;

      try {
        // TODO: 替换为实际的API调用
        // const rule = await FamilyApi.createSplitRule(data);
        // console.log('Creating split rule:', data);

        // 临时模拟创建
        const rule: SplitRuleConfig = {
          serialNum: `rule_${Date.now()}`,
          familyLedgerSerialNum: data.familyLedgerSerialNum,
          name: data.name,
          description: data.description,
          ruleType: data.ruleType,
          isTemplate: data.isTemplate,
          isActive: true,
          participants: data.participants,
          createdAt: new Date().toISOString(),
          updatedAt: null,
        };

        this.splitRules.push(rule);
        return rule;
      } catch (error: any) {
        this.error = error.message || '创建分摊规则失败';
        throw error;
      } finally {
        this.loading = false;
      }
    },

    /**
     * 更新分摊规则
     */
    async updateSplitRule(
      serialNum: string,
      data: SplitRuleConfigUpdate,
    ): Promise<SplitRuleConfig> {
      this.loading = true;
      this.error = null;

      try {
        // TODO: 替换为实际的API调用
        // const rule = await FamilyApi.updateSplitRule(serialNum, data);
        // console.log('Updating split rule:', serialNum, data);

        const index = this.splitRules.findIndex(r => r.serialNum === serialNum);
        if (index === -1) {
          throw new Error('分摊规则不存在');
        }

        // 临时模拟更新
        const updatedRule: SplitRuleConfig = {
          ...this.splitRules[index],
          ...data,
          updatedAt: new Date().toISOString(),
        };

        this.splitRules[index] = updatedRule;
        return updatedRule;
      } catch (error: any) {
        this.error = error.message || '更新分摊规则失败';
        throw error;
      } finally {
        this.loading = false;
      }
    },

    /**
     * 删除分摊规则
     */
    async deleteSplitRule(serialNum: string): Promise<void> {
      this.loading = true;
      this.error = null;

      try {
        // TODO: 替换为实际的API调用
        // await FamilyApi.deleteSplitRule(serialNum);
        // console.log('Deleting split rule:', serialNum);

        this.splitRules = this.splitRules.filter(r => r.serialNum !== serialNum);
      } catch (error: any) {
        this.error = error.message || '删除分摊规则失败';
        throw error;
      } finally {
        this.loading = false;
      }
    },

    /**
     * 计算分摊结果
     */
    calculateSplit(ruleId: string, totalAmount: number): SplitResult[] {
      const rule = this.getSplitRuleById(ruleId);
      if (!rule) {
        throw new Error('分摊规则不存在');
      }

      const results: SplitResult[] = [];

      switch (rule.ruleType) {
        case 'EQUAL': {
          // 均摊
          const equalAmount = totalAmount / rule.participants.length;
          rule.participants.forEach(participant => {
            results.push({
              memberSerialNum: participant.memberSerialNum,
              memberName: `Member_${participant.memberSerialNum}`, // TODO: 获取实际姓名
              amount: equalAmount,
              percentage: 100 / rule.participants.length,
            });
          });
          break;
        }

        case 'PERCENTAGE': {
          // 按比例分摊
          rule.participants.forEach(participant => {
            const percentage = participant.percentage || 0;
            const amount = (totalAmount * percentage) / 100;
            results.push({
              memberSerialNum: participant.memberSerialNum,
              memberName: `Member_${participant.memberSerialNum}`,
              amount,
              percentage,
            });
          });
          break;
        }

        case 'FIXED_AMOUNT': {
          // 固定金额
          let remainingAmount = totalAmount;
          const fixedParticipants = rule.participants.filter(p => p.fixedAmount);
          const flexibleParticipants = rule.participants.filter(p => !p.fixedAmount);

          // 先分配固定金额
          fixedParticipants.forEach(participant => {
            const amount = participant.fixedAmount || 0;
            remainingAmount -= amount;
            results.push({
              memberSerialNum: participant.memberSerialNum,
              memberName: `Member_${participant.memberSerialNum}`,
              amount,
              percentage: (amount / totalAmount) * 100,
            });
          });

          // 剩余金额均摊给灵活参与者
          if (flexibleParticipants.length > 0) {
            const flexibleAmount = remainingAmount / flexibleParticipants.length;
            flexibleParticipants.forEach(participant => {
              results.push({
                memberSerialNum: participant.memberSerialNum,
                memberName: `Member_${participant.memberSerialNum}`,
                amount: flexibleAmount,
                percentage: (flexibleAmount / totalAmount) * 100,
              });
            });
          }
          break;
        }

        case 'WEIGHTED': {
          // 按权重分摊
          const totalWeight = rule.participants.reduce((sum, p) => sum + (p.weight || 1), 0);
          rule.participants.forEach(participant => {
            const weight = participant.weight || 1;
            const amount = (totalAmount * weight) / totalWeight;
            const percentage = (weight / totalWeight) * 100;
            results.push({
              memberSerialNum: participant.memberSerialNum,
              memberName: `Member_${participant.memberSerialNum}`,
              amount,
              percentage,
            });
          });
          break;
        }

        default:
          throw new Error('不支持的分摊类型');
      }

      return results;
    },

    /**
     * 创建分摊记录
     */
    async createSplitRecord(data: SplitRecordCreate): Promise<SplitRecord> {
      this.loading = true;
      this.error = null;

      try {
        // TODO: 替换为实际的API调用
        // const record = await FamilyApi.createSplitRecord(data);
        // console.log('Creating split record:', data);

        // 临时模拟创建
        const record: SplitRecord = {
          serialNum: `split_${Date.now()}`,
          transactionSerialNum: data.transactionSerialNum,
          familyLedgerSerialNum: data.familyLedgerSerialNum,
          ruleConfigSerialNum: data.ruleConfigSerialNum,
          totalAmount: data.totalAmount,
          splitDetails: data.splitDetails,
          createdAt: new Date().toISOString(),
          updatedAt: null,
        };

        this.splitRecords.push(record);

        // 创建债务关系
        await this.createDebtRelationsFromSplit(record);

        return record;
      } catch (error: any) {
        this.error = error.message || '创建分摊记录失败';
        throw error;
      } finally {
        this.loading = false;
      }
    },

    /**
     * 从分摊记录创建债务关系
     */
    async createDebtRelationsFromSplit(_splitRecord: SplitRecord): Promise<void> {
      // TODO: 实现债务关系创建逻辑
      // console.log('Creating debt relations from split record:', splitRecord);
    },

    /**
     * 获取结算建议
     */
    async fetchSettlementSuggestions(_ledgerSerialNum: string): Promise<SettlementSuggestion[]> {
      try {
        // TODO: 替换为实际的API调用
        // const suggestions = await FamilyApi.getSettlementSuggestions(ledgerSerialNum);
        // console.log('Fetching settlement suggestions for ledger:', ledgerSerialNum);

        // 临时模拟数据
        this.settlementSuggestions = [];
        return this.settlementSuggestions;
      } catch (error: any) {
        console.error('获取结算建议失败:', error);
        throw error;
      }
    },

    /**
     * 标记分摊为已支付
     */
    async markSplitAsPaid(splitRecordId: string, memberSerialNum: string): Promise<void> {
      const record = this.splitRecords.find(r => r.serialNum === splitRecordId);
      if (!record) {
        throw new Error('分摊记录不存在');
      }

      const detail = record.splitDetails.find(d => d.memberSerialNum === memberSerialNum);
      if (!detail) {
        throw new Error('分摊详情不存在');
      }

      detail.isPaid = true;
      detail.paidAt = new Date().toISOString();

      // TODO: 更新后端数据
      // console.log('Marking split as paid:', splitRecordId, memberSerialNum);
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
      this.splitRules = [];
      this.splitRecords = [];
      this.debtRelations = [];
      this.settlementSuggestions = [];
      this.loading = false;
      this.error = null;
      this.currentLedgerSerialNum = null;
    },
  },
});
