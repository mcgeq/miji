/**
 * 债务关系 Service
 *
 * 提供债务关系的查询、同步、结算等功能
 */

import { invokeCommand } from '@/types/api';
import type { PagedResult } from './baseManager';

// ==================== 类型定义 ====================

export interface DebtRelation {
  serialNum: string;
  familyLedgerSerialNum: string;
  creditorMemberSerialNum: string;
  creditorMemberName: string;
  debtorMemberSerialNum: string;
  debtorMemberName: string;
  amount: number;
  currency: string;
  status: 'active' | 'settled' | 'cancelled';
  lastCalculatedAt: string;
  createdAt: string;
  updatedAt?: string;
}

export interface DebtRelationListParams {
  familyLedgerSerialNum: string;
  memberSerialNum?: string;
  status?: 'active' | 'settled' | 'cancelled';
  page?: number;
  pageSize?: number;
}

export interface DebtStatistics {
  totalDebts: number;
  activeDebts: number;
  settledDebts: number;
  totalAmount: number;
  activeAmount: number;
  settledAmount: number;
}

export interface MemberDebtSummary {
  memberSerialNum: string;
  memberName: string;
  totalCredit: number;
  totalDebt: number;
  netBalance: number;
  activeCredits: number;
  activeDebts: number;
}

export interface DebtGraphNode {
  memberSerialNum: string;
  memberName: string;
  avatarUrl?: string;
  color?: string;
  netBalance: number;
}

export interface DebtGraphEdge {
  fromMember: string;
  toMember: string;
  amount: number;
  currency: string;
  status: string;
}

export interface DebtGraph {
  nodes: DebtGraphNode[];
  edges: DebtGraphEdge[];
  totalAmount: number;
  currency: string;
}

// ==================== Service 方法 ====================

export const debtService = {
  /**
   * 获取债务关系列表
   */
  async listRelations(params: DebtRelationListParams): Promise<PagedResult<DebtRelation>> {
    return invokeCommand('debt_relations_list', {
      family_ledger_serial_num: params.familyLedgerSerialNum,
    });
  },

  /**
   * 获取债务统计信息
   */
  async getStatistics(
    familyLedgerSerialNum: string,
  ): Promise<DebtStatistics> {
    return invokeCommand('debt_relations_stats', {
      family_ledger_serial_num: familyLedgerSerialNum,
    });
  },

  /**
   * 同步债务关系
   * 根据分摊记录重新计算所有债务关系
   */
  async syncRelations(familyLedgerSerialNum: string, updatedBy: string): Promise<number> {
    return invokeCommand('debt_relations_recalculate', {
      family_ledger_serial_num: familyLedgerSerialNum,
      updated_by: updatedBy,
    });
  },

  /**
   * 获取单个债务关系详情
   */
  async getRelation(serialNum: string): Promise<DebtRelation> {
    return invokeCommand('debt_relation_get', { serial_num: serialNum });
  },

  /**
   * 标记债务关系为已结算
   */
  async markAsSettled(serialNum: string): Promise<void> {
    return invokeCommand('debt_relation_mark_settled', { serial_num: serialNum });
  },

  /**
   * 标记债务关系为已取消
   */
  async markAsCancelled(serialNum: string): Promise<void> {
    return invokeCommand('debt_relation_mark_cancelled', { serial_num: serialNum });
  },

  /**
   * 获取成员债务汇总
   */
  async getMemberSummary(
    familyLedgerSerialNum: string,
    memberSerialNum: string,
  ): Promise<MemberDebtSummary> {
    return invokeCommand('debt_relations_member_summary', {
      family_ledger_serial_num: familyLedgerSerialNum,
      member_serial_num: memberSerialNum,
    });
  },

  /**
   * 获取债务关系图谱
   */
  async getDebtGraph(familyLedgerSerialNum: string): Promise<DebtGraph> {
    return invokeCommand('debt_relations_graph', {
      family_ledger_serial_num: familyLedgerSerialNum,
    });
  },
};
