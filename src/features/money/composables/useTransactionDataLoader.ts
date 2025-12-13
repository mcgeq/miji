import type { Ref } from 'vue';
import { AppErrorSeverity } from '@/errors/appError';
import type { Transaction } from '@/schema/money';
import { MoneyDb } from '@/services/money/money';
import { Lg } from '@/utils/debugLog';
import { throwAppError } from '@/utils/errorHandler';

/**
 * 交易数据加载器 Composable
 *
 * 职责：
 * 1. 统一管理交易相关数据的加载逻辑
 * 2. 分离创建模式和编辑模式的初始化流程
 * 3. 提供清晰的数据加载接口
 */

interface SplitConfig {
  enabled: boolean;
  splitType?: string;
  members?: Array<{
    memberSerialNum: string;
    memberName: string;
    amount: number;
    percentage?: number;
    weight?: number;
  }>;
}

interface LoadedTransactionData {
  fullTransaction: Transaction;
  ledgerSerialNums: string[];
  memberSerialNums: string[];
  splitConfig: SplitConfig;
}

interface DataLoaderDependencies {
  loadAvailableLedgers: () => Promise<void>;
  loadAvailableMembers: () => Promise<void>;
  getTransactionLinks: (serialNum: string) => Promise<{
    ledgers: Array<{ serialNum: string; name: string }>;
    members: Array<{ serialNum: string; name: string }>;
  }>;
}

export function useTransactionDataLoader(deps: DataLoaderDependencies) {
  const { loadAvailableLedgers, loadAvailableMembers, getTransactionLinks } = deps;

  /**
   * 加载创建模式所需的基础数据
   */
  async function loadCreateModeData(): Promise<void> {
    try {
      await loadAvailableLedgers();
      Lg.d('TransactionDataLoader', 'Create mode data loaded');
    } catch (error) {
      Lg.e('TransactionDataLoader', 'Failed to load create mode data:', error);
      throw error;
    }
  }

  /**
   * 加载完整的交易数据（包含 splitConfig）
   */
  async function loadFullTransaction(serialNum: string): Promise<Transaction> {
    try {
      const fullTransaction = await MoneyDb.getTransaction(serialNum);

      if (!fullTransaction) {
        throwAppError(
          'TransactionDataLoader',
          'TRANSACTION_NOT_FOUND',
          `交易不存在: ${serialNum}`,
          AppErrorSeverity.MEDIUM,
        );
      }

      Lg.d('TransactionDataLoader', 'Full transaction loaded:', {
        serialNum,
        hasSplitConfig: !!fullTransaction.splitConfig,
      });

      return fullTransaction;
    } catch (error) {
      Lg.e('TransactionDataLoader', 'Failed to load full transaction:', error);
      throw error;
    }
  }

  /**
   * 加载交易的关联数据（账本、成员）
   */
  async function loadTransactionLinks(serialNum: string) {
    try {
      const links = await getTransactionLinks(serialNum);

      Lg.d('TransactionDataLoader', 'Transaction links loaded:', {
        ledgerCount: links.ledgers.length,
        memberCount: links.members.length,
      });

      return links;
    } catch (error) {
      Lg.e('TransactionDataLoader', 'Failed to load transaction links:', error);
      throw error;
    }
  }

  /**
   * 加载编辑模式所需的所有数据
   *
   * 执行顺序：
   * 1. 加载可用账本列表
   * 2. 加载完整交易数据（包含 splitConfig）
   * 3. 加载交易关联（账本、成员）
   * 4. 加载可用成员列表
   */
  async function loadEditModeData(transaction: Transaction): Promise<LoadedTransactionData> {
    try {
      Lg.d('TransactionDataLoader', 'Starting edit mode data loading for:', transaction.serialNum);

      // 1. 加载账本列表（必须先加载，因为成员列表依赖账本）
      await loadAvailableLedgers();

      // 2. 加载完整交易数据
      const fullTransaction = await loadFullTransaction(transaction.serialNum);

      // 3. 加载关联数据
      const links = await loadTransactionLinks(transaction.serialNum);

      // 4. 加载成员列表（基于已关联的账本）
      await loadAvailableMembers();

      // 5. 组装返回数据
      const result: LoadedTransactionData = {
        fullTransaction,
        ledgerSerialNums: links.ledgers.map(l => l.serialNum),
        memberSerialNums: links.members.map(m => m.serialNum),
        splitConfig: {
          enabled: false,
        },
      };

      // 6. 处理分摊配置
      if (fullTransaction.splitConfig?.enabled) {
        result.splitConfig = {
          enabled: true,
          splitType: fullTransaction.splitConfig.splitType,
          members: fullTransaction.splitConfig.members || [],
        };
      }

      Lg.d('TransactionDataLoader', 'Edit mode data loaded successfully');

      return result;
    } catch (error) {
      Lg.e('TransactionDataLoader', 'Failed to load edit mode data:', error);
      throw error;
    }
  }

  /**
   * 应用加载的数据到状态
   *
   * 这个函数将加载的数据应用到各个 ref 变量
   */
  function applyLoadedData(
    loadedData: LoadedTransactionData,
    refs: {
      selectedLedgers: Ref<string[]>;
      selectedMembers: Ref<string[]>;
      splitConfig: Ref<SplitConfig>;
    },
  ): void {
    try {
      // 应用账本和成员选择
      refs.selectedLedgers.value = loadedData.ledgerSerialNums;
      refs.selectedMembers.value = loadedData.memberSerialNums;

      // 应用分摊配置
      refs.splitConfig.value = loadedData.splitConfig;

      Lg.d('TransactionDataLoader', 'Loaded data applied to refs');
    } catch (error) {
      Lg.e('TransactionDataLoader', 'Failed to apply loaded data:', error);
      throw error;
    }
  }

  return {
    // 基础加载方法
    loadCreateModeData,
    loadEditModeData,
    loadFullTransaction,
    loadTransactionLinks,

    // 数据应用方法
    applyLoadedData,
  };
}
