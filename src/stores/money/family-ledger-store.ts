// src/stores/money/family-ledger-store.ts
import { defineStore } from 'pinia';
import { MoneyDb } from '@/services/money/money';
import type {
  FamilyLedger,
  FamilyLedgerCreate,
  FamilyLedgerStats,
  FamilyLedgerUpdate,
} from '@/schema/money';

interface FamilyLedgerStoreState {
  ledgers: FamilyLedger[];
  currentLedger: FamilyLedger | null;
  ledgerStats: Record<string, FamilyLedgerStats>;
  loading: boolean;
  error: string | null;
}

/**
 * 家庭账本管理 Store
 * 负责家庭账本的CRUD操作、切换和统计
 */
export const useFamilyLedgerStore = defineStore('family-ledger', {
  state: (): FamilyLedgerStoreState => ({
    ledgers: [],
    currentLedger: null,
    ledgerStats: {},
    loading: false,
    error: null,
  }),

  getters: {
    /**
     * 获取所有激活的账本
     */
    activeLedgers: state => state.ledgers.filter(ledger => ledger.ledgerType !== 'PERSONAL'),

    /**
     * 获取家庭类型的账本
     */
    familyLedgers: state => state.ledgers.filter(ledger => ledger.ledgerType === 'FAMILY'),

    /**
     * 获取共享类型的账本
     */
    sharedLedgers: state => state.ledgers.filter(ledger => ledger.ledgerType === 'SHARED'),

    /**
     * 获取项目类型的账本
     */
    projectLedgers: state => state.ledgers.filter(ledger => ledger.ledgerType === 'PROJECT'),

    /**
     * 根据ID获取账本
     */
    getLedgerById: state => (id: string) => {
      return state.ledgers.find(ledger => ledger.serialNum === id);
    },

    /**
     * 获取当前账本的统计信息
     */
    currentLedgerStats: state => {
      if (!state.currentLedger) return null;
      return state.ledgerStats[state.currentLedger.serialNum] || null;
    },

    /**
     * 检查是否有待结算的账本
     */
    hasPendingSettlement: state => {
      return state.ledgers.some(ledger => ledger.pendingSettlement > 0);
    },

    /**
     * 获取需要自动结算的账本
     */
    autoSettlementLedgers: state => {
      return state.ledgers.filter(
        ledger =>
          ledger.autoSettlement &&
          ledger.settlementCycle !== 'MANUAL' &&
          ledger.pendingSettlement > 0,
      );
    },
  },

  actions: {
    /**
     * 获取账本列表
     */
    async fetchLedgers() {
      this.loading = true;
      this.error = null;

      try {
        this.ledgers = await MoneyDb.listFamilyLedgers();
      } catch (error: any) {
        this.error = error.message || '获取账本列表失败';
        console.error('Failed to fetch ledgers:', error);
        this.ledgers = [];
      } finally {
        this.loading = false;
      }
    },

    /**
     * 创建账本
     */
    async createLedger(data: FamilyLedgerCreate): Promise<FamilyLedger> {
      this.loading = true;
      this.error = null;

      try {
        const ledger = await MoneyDb.createFamilyLedger(data);
        this.ledgers.push(ledger);
        return ledger;
      } catch (error: any) {
        this.error = error.message || '创建账本失败';
        console.error('Failed to create ledger:', error);
        throw error;
      } finally {
        this.loading = false;
      }
    },

    /**
     * 更新账本
     */
    async updateLedger(serialNum: string, data: FamilyLedgerUpdate): Promise<FamilyLedger> {
      this.loading = true;
      this.error = null;

      try {
        const updatedLedger = await MoneyDb.updateFamilyLedger(serialNum, data);

        const index = this.ledgers.findIndex(l => l.serialNum === serialNum);
        if (index !== -1) {
          this.ledgers[index] = updatedLedger;
        }

        // 如果更新的是当前账本，同步更新
        if (this.currentLedger?.serialNum === serialNum) {
          this.currentLedger = updatedLedger;
        }

        return updatedLedger;
      } catch (error: any) {
        this.error = error.message || '更新账本失败';
        console.error('Failed to update ledger:', error);
        throw error;
      } finally {
        this.loading = false;
      }
    },

    /**
     * 删除账本
     */
    async deleteLedger(serialNum: string): Promise<void> {
      this.loading = true;
      this.error = null;

      try {
        await MoneyDb.deleteFamilyLedger(serialNum);

        this.ledgers = this.ledgers.filter(l => l.serialNum !== serialNum);

        // 如果删除的是当前账本，清空当前账本
        if (this.currentLedger?.serialNum === serialNum) {
          this.currentLedger = null;
        }

        // 清理统计数据
        delete this.ledgerStats[serialNum];
      } catch (error: any) {
        this.error = error.message || '删除账本失败';
        console.error('Failed to delete ledger:', error);
        throw error;
      } finally {
        this.loading = false;
      }
    },

    /**
     * 切换当前账本
     */
    async switchLedger(serialNum: string): Promise<void> {
      // 使用详情 API，一次获取所有数据（包含成员和账户列表）
      const ledger = await MoneyDb.getFamilyLedgerDetail(serialNum);

      this.currentLedger = ledger;

      // 获取账本统计信息
      await this.fetchLedgerStats(serialNum);

      // 保存到本地存储
      localStorage.setItem('currentFamilyLedger', serialNum);
    },

    /**
     * 获取账本统计信息
     */
    async fetchLedgerStats(serialNum: string): Promise<FamilyLedgerStats> {
      try {
        // 目前后端还没有统计API，先返回基础统计数据
        // TODO: 等后端实现统计API后替换
        const ledger = await MoneyDb.getFamilyLedger(serialNum);
        if (!ledger) {
          throw new Error('账本不存在');
        }

        const stats: FamilyLedgerStats = {
          familyLedgerSerialNum: serialNum,
          totalIncome: ledger.totalIncome || 0,
          totalExpense: ledger.totalExpense || 0,
          sharedExpense: ledger.sharedExpense || 0,
          personalExpense: ledger.personalExpense || 0,
          pendingSettlement: ledger.pendingSettlement || 0,
          memberCount: ledger.members || 0,
          activeTransactionCount: ledger.transactions || 0,
          memberStats: [],
        };

        this.ledgerStats[serialNum] = stats;
        return stats;
      } catch (error: any) {
        console.error('获取账本统计失败:', error);
        throw error;
      }
    },

    /**
     * 刷新当前账本统计
     */
    async refreshCurrentStats(): Promise<void> {
      if (this.currentLedger) {
        await this.fetchLedgerStats(this.currentLedger.serialNum);
      }
    },

    /**
     * 初始化当前账本（从本地存储恢复）
     */
    async initCurrentLedger(): Promise<void> {
      const savedLedgerId = localStorage.getItem('currentFamilyLedger');
      if (savedLedgerId) {
        const ledger = this.getLedgerById(savedLedgerId);
        if (ledger) {
          this.currentLedger = ledger;
          await this.fetchLedgerStats(savedLedgerId);
        }
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
      this.ledgers = [];
      this.currentLedger = null;
      this.ledgerStats = {};
      this.loading = false;
      this.error = null;
      localStorage.removeItem('currentFamilyLedger');
    },
  },
});
