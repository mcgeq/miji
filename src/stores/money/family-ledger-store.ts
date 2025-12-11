// src/stores/money/family-ledger-store.ts
import { defineStore } from 'pinia';
import { AppError } from '@/errors/appError';
import type {
  FamilyLedger,
  FamilyLedgerCreate,
  FamilyLedgerStats,
  FamilyLedgerUpdate,
} from '@/schema/money';
import { MoneyDb } from '@/services/money/money';
import { Lg } from '@/utils/debugLog';
import { toast } from '@/utils/toast';
import { type EventCleanup, onStoreEvent } from './store-events';

// ==================== Store Constants ====================
const STORE_MODULE = 'FamilyLedgerStore';

/** FamilyLedgerStore 错误代码 */
export enum FamilyLedgerStoreErrorCode {
  FETCH_FAILED = 'FETCH_FAILED',
  CREATE_FAILED = 'CREATE_FAILED',
  UPDATE_FAILED = 'UPDATE_FAILED',
  DELETE_FAILED = 'DELETE_FAILED',
  SWITCH_FAILED = 'SWITCH_FAILED',
  STATS_FAILED = 'STATS_FAILED',
  NOT_FOUND = 'NOT_FOUND',
}

interface FamilyLedgerStoreState {
  /** 账本列表 */
  ledgers: FamilyLedger[];
  /** 当前选中的账本 */
  currentLedger: FamilyLedger | null;
  /** 账本统计数据 */
  ledgerStats: Record<string, FamilyLedgerStats>;
  /** 加载状态 */
  loading: boolean;
  /** 错误信息 */
  error: AppError | null;
  /** 事件监听器清理函数 */
  eventCleanups: EventCleanup[];
}

/**
 * 创建初始状态
 */
function createInitialState(): FamilyLedgerStoreState {
  return {
    ledgers: [],
    currentLedger: null,
    ledgerStats: {},
    loading: false,
    error: null,
    eventCleanups: [],
  };
}

/**
 * 家庭账本管理 Store
 * 负责家庭账本的CRUD操作、切换和统计
 */
export const useFamilyLedgerStore = defineStore('family-ledger', {
  state: (): FamilyLedgerStoreState => createInitialState(),

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

    /**
     * 获取用户友好的错误消息
     */
    errorMessage: (state): string | null => {
      return state.error?.getUserMessage() ?? null;
    },
  },

  actions: {
    // ==================== 错误处理 ====================

    /**
     * 统一错误处理
     */
    handleError(
      err: unknown,
      code: FamilyLedgerStoreErrorCode,
      message: string,
      showToast = true,
    ): AppError {
      const appError = AppError.wrap(STORE_MODULE, err, code, message);
      this.error = appError;
      appError.log();
      if (showToast) {
        toast.error(appError.getUserMessage());
      }
      return appError;
    },

    /**
     * 清空错误状态
     */
    clearError() {
      this.error = null;
    },

    /**
     * 带加载状态和错误处理的操作包装器
     */
    async withLoadingSafe<T>(
      operation: () => Promise<T>,
      errorCode: FamilyLedgerStoreErrorCode,
      errorMsg: string,
      showToast = true,
    ): Promise<T> {
      this.loading = true;
      this.error = null;
      try {
        return await operation();
      } catch (err) {
        const appError = this.handleError(err, errorCode, errorMsg, showToast);
        throw appError;
      } finally {
        this.loading = false;
      }
    },

    // ==================== CRUD 操作 ====================

    /**
     * 获取账本列表
     */
    async fetchLedgers() {
      Lg.i(STORE_MODULE, '获取账本列表');
      this.loading = true;
      this.error = null;

      try {
        const result = await MoneyDb.listFamilyLedgers();
        // 不可变更新
        this.ledgers = [...result];
        Lg.i(STORE_MODULE, '账本列表获取成功', { count: result.length });
      } catch (err) {
        this.handleError(err, FamilyLedgerStoreErrorCode.FETCH_FAILED, '获取账本列表失败');
        this.ledgers = [];
      } finally {
        this.loading = false;
      }
    },

    /**
     * 创建账本
     */
    async createLedger(data: FamilyLedgerCreate): Promise<FamilyLedger> {
      Lg.i(STORE_MODULE, '创建账本', { name: data.name, type: data.ledgerType });
      return this.withLoadingSafe(
        async () => {
          const ledger = await MoneyDb.createFamilyLedger(data);
          // 不可变更新
          this.ledgers = [...this.ledgers, ledger];
          Lg.i(STORE_MODULE, '账本创建成功', { serialNum: ledger.serialNum });
          return ledger;
        },
        FamilyLedgerStoreErrorCode.CREATE_FAILED,
        '创建账本失败',
      );
    },

    /**
     * 更新账本
     */
    async updateLedger(serialNum: string, data: FamilyLedgerUpdate): Promise<FamilyLedger> {
      Lg.i(STORE_MODULE, '更新账本', { serialNum, updates: Object.keys(data) });
      return this.withLoadingSafe(
        async () => {
          const updatedLedger = await MoneyDb.updateFamilyLedger(serialNum, data);

          // 不可变更新
          this.ledgers = this.ledgers.map(l => (l.serialNum === serialNum ? updatedLedger : l));

          // 如果更新的是当前账本，同步更新
          if (this.currentLedger?.serialNum === serialNum) {
            this.currentLedger = updatedLedger;
          }

          Lg.i(STORE_MODULE, '账本更新成功', { serialNum });
          return updatedLedger;
        },
        FamilyLedgerStoreErrorCode.UPDATE_FAILED,
        '更新账本失败',
      );
    },

    /**
     * 删除账本
     */
    async deleteLedger(serialNum: string): Promise<void> {
      Lg.i(STORE_MODULE, '删除账本', { serialNum });
      return this.withLoadingSafe(
        async () => {
          await MoneyDb.deleteFamilyLedger(serialNum);

          // 不可变更新
          this.ledgers = this.ledgers.filter(l => l.serialNum !== serialNum);

          // 如果删除的是当前账本，清空当前账本
          if (this.currentLedger?.serialNum === serialNum) {
            this.currentLedger = null;
          }

          // 不可变更新：清理统计数据
          const { [serialNum]: _, ...restStats } = this.ledgerStats;
          this.ledgerStats = restStats;

          Lg.i(STORE_MODULE, '账本删除成功', { serialNum });
        },
        FamilyLedgerStoreErrorCode.DELETE_FAILED,
        '删除账本失败',
      );
    },

    /**
     * 切换当前账本
     */
    async switchLedger(serialNum: string): Promise<void> {
      Lg.i(STORE_MODULE, '切换账本', { serialNum });
      try {
        // 使用详情 API，一次获取所有数据（包含成员和账户列表）
        const ledger = await MoneyDb.getFamilyLedgerDetail(serialNum);

        this.currentLedger = ledger;

        // 获取账本统计信息
        await this.fetchLedgerStats(serialNum);

        // 保存到本地存储
        localStorage.setItem('currentFamilyLedger', serialNum);

        Lg.i(STORE_MODULE, '账本切换成功', { serialNum });
      } catch (err) {
        this.handleError(err, FamilyLedgerStoreErrorCode.SWITCH_FAILED, '切换账本失败');
        throw err;
      }
    },

    /**
     * 获取账本统计信息
     */
    async fetchLedgerStats(serialNum: string): Promise<FamilyLedgerStats> {
      Lg.d(STORE_MODULE, '获取账本统计', { serialNum });
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

        // 不可变更新
        this.ledgerStats = { ...this.ledgerStats, [serialNum]: stats };
        Lg.d(STORE_MODULE, '账本统计获取成功', { serialNum });
        return stats;
      } catch (err) {
        Lg.e(STORE_MODULE, '获取账本统计失败', { serialNum, error: err });
        throw err;
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
        Lg.d(STORE_MODULE, '从本地存储恢复账本', { serialNum: savedLedgerId });
        const ledger = this.getLedgerById(savedLedgerId);
        if (ledger) {
          this.currentLedger = ledger;
          await this.fetchLedgerStats(savedLedgerId);
        }
      }
    },

    // ==================== 状态重置 ====================

    /**
     * 重置store状态
     */
    $reset() {
      Lg.i(STORE_MODULE, '重置 store 状态');

      // 先清理事件监听器
      this.cleanupEventListeners();

      const initialState = createInitialState();
      this.ledgers = initialState.ledgers;
      this.currentLedger = initialState.currentLedger;
      this.ledgerStats = initialState.ledgerStats;
      this.loading = initialState.loading;
      this.error = initialState.error;
      this.eventCleanups = initialState.eventCleanups;
      localStorage.removeItem('currentFamilyLedger');
    },

    // ==================== 事件监听 ====================

    /**
     * 初始化事件监听器
     * 监听其他 Store 发出的账本相关事件
     */
    initEventListeners() {
      Lg.i(STORE_MODULE, '初始化事件监听器');

      // 先清理旧的监听器
      this.cleanupEventListeners();

      // 监听账本更新事件（例如成员数量变化）
      this.eventCleanups.push(
        onStoreEvent('ledger:updated', async ({ serialNum }) => {
          try {
            // 重新获取账本列表以更新数据
            await this.fetchLedgers();

            // 如果是当前账本，也刷新统计数据
            if (this.currentLedger?.serialNum === serialNum) {
              await this.fetchLedgerStats(serialNum);
            }
          } catch (err) {
            Lg.e(STORE_MODULE, '处理 ledger:updated 事件失败', { serialNum, error: err });
          }
        }),
      );

      Lg.i(STORE_MODULE, '事件监听器初始化完成', { count: this.eventCleanups.length });
    },

    /**
     * 清理事件监听器
     */
    cleanupEventListeners() {
      if (this.eventCleanups.length > 0) {
        Lg.i(STORE_MODULE, '清理事件监听器', { count: this.eventCleanups.length });
        this.eventCleanups.forEach(cleanup => {
          cleanup();
        });
        this.eventCleanups = [];
      }
    },
  },
});
