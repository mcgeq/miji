/**
 * 结算 Service
 *
 * 提供智能结算建议、执行结算等功能
 */

import { invokeCommand } from '@/types/api';

// ==================== 类型定义 ====================

export interface TransferSuggestion {
  from: string;
  fromName: string;
  to: string;
  toName: string;
  amount: number;
  currency: string;
}

export interface SettlementSuggestion {
  totalAmount: number;
  currency: string;
  originalTransfers: number;
  optimizedTransfers: TransferSuggestion[];
  savings: number;
  participantMembers: string[];
  calculatedAt: string;
}

export interface SettlementCalculateParams {
  familyLedgerSerialNum: string;
  memberSerialNums?: string[];
  startDate?: string;
  endDate?: string;
  settlementType: 'manual' | 'auto' | 'optimized';
}

export interface SettlementExecuteParams {
  familyLedgerSerialNum: string;
  settlementType: 'manual' | 'auto' | 'optimized';
  periodStart: string;
  periodEnd: string;
  participantMembers: string[];
  optimizedTransfers?: TransferSuggestion[];
  totalAmount: number;
  currency: string;
  initiatedBy: string;
}

export interface SettlementExecuteResult {
  serialNum: string;
  status: 'pending' | 'completed';
  message: string;
}

// ==================== Service 方法 ====================

export const settlementService = {
  /**
   * 计算结算建议
   * 使用智能算法优化转账次数
   */
  async calculateSuggestion(
    params: SettlementCalculateParams,
  ): Promise<SettlementSuggestion> {
    // 后端期期period_start和period_end
    return invokeCommand('settlement_generate_suggestion', {
      family_ledger_serial_num: params.familyLedgerSerialNum,
      period_start: params.startDate || new Date(new Date().getFullYear(), new Date().getMonth(), 1).toISOString().split('T')[0],
      period_end: params.endDate || new Date().toISOString().split('T')[0],
    });
  },

  /**
   * 执行结算
   * 创建结算记录并更新债务关系
   */
  async executeSettlement(
    params: SettlementExecuteParams,
  ): Promise<SettlementExecuteResult> {
    return invokeCommand('settlement_execute', {
      family_ledger_serial_num: params.familyLedgerSerialNum,
      settlement_type: params.settlementType,
      period_start: params.periodStart,
      period_end: params.periodEnd,
      participant_members: params.participantMembers,
      optimized_transfers: params.optimizedTransfers,
      total_amount: params.totalAmount,
      currency: params.currency,
      initiated_by: params.initiatedBy,
    });
  },

  /**
   * 获取结算优化详情
   * 包含优化前后对比
   */
  async getOptimizationDetails(
    familyLedgerSerialNum: string,
  ): Promise<{
    before: {
      transferCount: number;
      complexity: string;
    };
    after: {
      transferCount: number;
      complexity: string;
    };
    savings: number;
    savingsPercentage: number;
  }> {
    return invokeCommand('settlement_get_optimization_details', {
      family_ledger_serial_num: familyLedgerSerialNum,
    });
  },

  /**
   * 验证结算方案
   * 检查转账方案是否平衡
   */
  async validateSettlement(transfers: TransferSuggestion[]): Promise<{
    isValid: boolean;
    errors: string[];
  }> {
    return invokeCommand('settlement_validate', { transfers });
  },
};
