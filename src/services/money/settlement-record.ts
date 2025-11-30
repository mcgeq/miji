/**
 * 结算记录 Service
 *
 * 提供结算记录的查询、管理等功能
 */

import { invokeCommand } from '@/types/api';
import type { PagedResult } from './baseManager';
import type { TransferSuggestion } from './settlement';

// ==================== 类型定义 ====================

export interface SettlementRecord {
  serialNum: string;
  familyLedgerSerialNum: string;
  settlementType: 'manual' | 'auto' | 'optimized';
  periodStart: string;
  periodEnd: string;
  totalAmount: number;
  currency: string;
  participantMembers: string[];
  settlementDetails: any;
  optimizedTransfers: TransferSuggestion[];
  status: 'pending' | 'completed' | 'cancelled';
  initiatedBy: string;
  completedBy?: string;
  completedAt?: string;
  createdAt: string;
  updatedAt?: string;
}

export interface SettlementRecordListParams {
  familyLedgerSerialNum: string;
  status?: 'pending' | 'completed' | 'cancelled';
  settlementType?: 'manual' | 'auto' | 'optimized';
  startDate?: string;
  endDate?: string;
  page?: number;
  pageSize?: number;
}

export interface SettlementRecordStatistics {
  totalCount: number;
  completedCount: number;
  pendingCount: number;
  cancelledCount: number;
  totalAmount: number;
  completedAmount: number;
}

// ==================== Service 方法 ====================

export const settlementRecordService = {
  /**
   * 获取结算记录列表
   */
  async listRecords(params: SettlementRecordListParams): Promise<PagedResult<SettlementRecord>> {
    return invokeCommand('settlement_records_list', {
      family_ledger_serial_num: params.familyLedgerSerialNum,
    });
  },

  /**
   * 获取结算记录详情
   */
  async getRecord(serialNum: string): Promise<SettlementRecord> {
    return invokeCommand('settlement_record_get', { serial_num: serialNum });
  },

  /**
   * 获取结算记录统计
   */
  async getStatistics(familyLedgerSerialNum: string): Promise<SettlementRecordStatistics> {
    return invokeCommand('settlement_records_stats', {
      family_ledger_serial_num: familyLedgerSerialNum,
    });
  },

  /**
   * 确认完成结算
   */
  async completeSettlement(serialNum: string, completedBy: string): Promise<void> {
    return invokeCommand('settlement_record_complete', {
      serial_num: serialNum,
      completed_by: completedBy,
    });
  },

  /**
   * 取消结算
   */
  async cancelSettlement(serialNum: string, cancellationReason?: string): Promise<void> {
    return invokeCommand('settlement_record_cancel', {
      serial_num: serialNum,
      cancellation_reason: cancellationReason,
    });
  },

  /**
   * 导出结算记录
   */
  async exportRecord(
    serialNum: string,
    format: 'pdf' | 'excel',
  ): Promise<{
    filename: string;
    data: string;
    format: string;
  }> {
    return invokeCommand('settlement_record_export', {
      serial_num: serialNum,
      format,
    });
  },

  /**
   * 批量导出结算记录
   */
  async exportRecords(
    params: SettlementRecordListParams,
    format: 'pdf' | 'excel',
  ): Promise<{
    filename: string;
    data: string;
    format: string;
    recordCount: number;
  }> {
    return invokeCommand('settlement_records_export', {
      family_ledger_serial_num: params.familyLedgerSerialNum,
      format,
      status: params.status,
    });
  },
};
