/**
 * 分摊功能 Service
 *
 * 提供分摊记录的创建、查询、更新等功能
 * 基于新的 split_record_details 表实现
 */

import { invokeCommand } from '@/types/api';
import type { PagedResult } from './baseManager';

// ==================== 类型定义 ====================

export interface SplitMemberConfig {
  memberSerialNum: string;
  memberName: string;
  amount: number;
  percentage?: number;
  weight?: number;
}

export interface SplitDetailCreate {
  memberSerialNum: string;
  memberName: string;
  amount: number;
  percentage?: number;
  weight?: number;
  isPaid: boolean;
}

export interface SplitRecordDetailResponse {
  serialNum: string;
  splitRecordSerialNum: string;
  memberSerialNum: string;
  memberName?: string;
  amount: number;
  percentage?: number;
  weight?: number;
  isPaid: boolean;
  paidAt?: string;
  createdAt: string;
  updatedAt?: string;
}

export interface SplitRecordWithDetails {
  serialNum: string;
  transactionSerialNum: string;
  familyLedgerSerialNum: string;
  ruleType: string;
  totalAmount: number;
  currency: string;
  payerMemberSerialNum?: string;
  payerMemberName?: string;
  createdAt: string;
  updatedAt?: string;
  details: SplitRecordDetailResponse[];
}

export interface SplitRecordWithDetailsCreate {
  transactionSerialNum: string;
  familyLedgerSerialNum: string;
  ruleType: 'EQUAL' | 'PERCENTAGE' | 'FIXED_AMOUNT' | 'WEIGHTED';
  totalAmount: number;
  currency: string;
  payerMemberSerialNum?: string;
  details: SplitDetailCreate[];
}

export interface SplitRecordStatistics {
  totalMembers: number;
  paidMembers: number;
  unpaidMembers: number;
  totalAmount: number;
  paidAmount: number;
  unpaidAmount: number;
  paidPercentage: number;
}

// ==================== Service 方法 ====================

export const splitService = {
  /**
   * 创建完整的分摊记录（主记录 + 所有明细）
   */
  async createRecord(data: SplitRecordWithDetailsCreate): Promise<SplitRecordWithDetails> {
    return invokeCommand('split_record_with_details_create', { data });
  },

  /**
   * 获取分摊记录详情（包含所有明细）
   */
  async getRecord(splitRecordSerialNum: string): Promise<SplitRecordWithDetails> {
    return invokeCommand('split_record_with_details_get', { splitRecordSerialNum });
  },

  /**
   * 更新分摊明细的支付状态
   */
  async updatePaymentStatus(
    detailSerialNum: string,
    isPaid: boolean,
  ): Promise<SplitRecordDetailResponse> {
    return invokeCommand('split_detail_payment_status_update', {
      detailSerialNum,
      isPaid,
    });
  },

  /**
   * 获取分摊记录的统计信息
   */
  async getStatistics(splitRecordSerialNum: string): Promise<SplitRecordStatistics> {
    return invokeCommand('split_record_statistics_get', { splitRecordSerialNum });
  },

  /**
   * 查询成员的所有分摊明细（分页）
   */
  async listMemberDetails(
    memberSerialNum: string,
    page?: number,
    pageSize?: number,
  ): Promise<PagedResult<SplitRecordDetailResponse>> {
    return invokeCommand('member_split_details_list', {
      memberSerialNum,
      page,
      pageSize,
    });
  },
};

// ==================== 工具函数 ====================

/**
 * 计算均摊金额
 */
export function calculateEqualSplit(totalAmount: number, memberCount: number): number[] {
  const baseAmount = Math.floor((totalAmount * 100) / memberCount) / 100;
  const remainder = totalAmount - baseAmount * memberCount;

  const amounts = Array.from({ length: memberCount }).fill(baseAmount) as number[];
  if (remainder > 0) {
    amounts[0] += remainder;
  }

  return amounts;
}

/**
 * 计算按比例分摊
 */
export function calculatePercentageSplit(totalAmount: number, percentages: number[]): number[] {
  const amounts = percentages.map(p => (totalAmount * p) / 100);
  const total = amounts.reduce((sum, amount) => sum + amount, 0);
  const remainder = totalAmount - total;

  if (Math.abs(remainder) > 0.01) {
    amounts[0] += remainder;
  }

  return amounts;
}

/**
 * 计算按权重分摊
 */
export function calculateWeightedSplit(totalAmount: number, weights: number[]): number[] {
  const totalWeight = weights.reduce((sum, w) => sum + w, 0);
  const amounts = weights.map(w => (totalAmount * w) / totalWeight);
  const total = amounts.reduce((sum, amount) => sum + amount, 0);
  const remainder = totalAmount - total;

  if (Math.abs(remainder) > 0.01) {
    amounts[0] += remainder;
  }

  return amounts;
}

/**
 * 验证均摊配置
 */
function validateEqualSplit(
  totalAmount: number,
  details: SplitDetailCreate[],
  errors: string[],
): void {
  const expectedAmount = totalAmount / details.length;
  for (const detail of details) {
    if (Math.abs(detail.amount - expectedAmount) > 0.02) {
      errors.push(`均摊金额不均等: 期望${expectedAmount}, 实际${detail.amount}`);
      break;
    }
  }
}

/**
 * 验证百分比分摊配置
 */
function validatePercentageSplit(
  totalAmount: number,
  details: SplitDetailCreate[],
  errors: string[],
): void {
  const totalPercentage = details.reduce((sum, d) => sum + (d.percentage || 0), 0);
  if (Math.abs(totalPercentage - 100) > 0.01) {
    errors.push(`比例总和必须为100%，当前为${totalPercentage}%`);
  }

  for (const detail of details) {
    if (detail.percentage) {
      const expectedAmount = (totalAmount * detail.percentage) / 100;
      if (Math.abs(detail.amount - expectedAmount) > 0.01) {
        errors.push(`比例金额计算错误: 期望${expectedAmount}, 实际${detail.amount}`);
        break;
      }
    }
  }
}

/**
 * 验证固定金额分摊配置
 */
function validateFixedAmountSplit(
  totalAmount: number,
  details: SplitDetailCreate[],
  errors: string[],
): void {
  const calculatedTotal = details.reduce((sum, d) => sum + d.amount, 0);
  if (Math.abs(totalAmount - calculatedTotal) > 0.01) {
    errors.push(`固定金额总和(${calculatedTotal})必须等于交易金额(${totalAmount})`);
  }
}

/**
 * 验证权重分摊配置
 */
function validateWeightedSplit(
  totalAmount: number,
  details: SplitDetailCreate[],
  errors: string[],
): void {
  const totalWeight = details.reduce((sum, d) => sum + (d.weight || 0), 0);
  if (totalWeight <= 0) {
    errors.push('权重总和必须大于0');
    return;
  }

  for (const detail of details) {
    if (detail.weight) {
      const expectedAmount = (totalAmount * detail.weight) / totalWeight;
      if (Math.abs(detail.amount - expectedAmount) > 0.01) {
        errors.push(`权重金额计算错误: 期望${expectedAmount}, 实际${detail.amount}`);
        break;
      }
    }
  }
}

/**
 * 验证分摊配置
 */
export function validateSplitConfig(
  ruleType: string,
  totalAmount: number,
  details: SplitDetailCreate[],
): { valid: boolean; errors: string[] } {
  const errors: string[] = [];

  if (details.length === 0) {
    errors.push('分摊成员不能为空');
  }

  if (totalAmount <= 0) {
    errors.push('分摊金额必须大于0');
  }

  switch (ruleType) {
    case 'EQUAL':
      validateEqualSplit(totalAmount, details, errors);
      break;
    case 'PERCENTAGE':
      validatePercentageSplit(totalAmount, details, errors);
      break;
    case 'FIXED_AMOUNT':
      validateFixedAmountSplit(totalAmount, details, errors);
      break;
    case 'WEIGHTED':
      validateWeightedSplit(totalAmount, details, errors);
      break;
    default:
      errors.push(`不支持的分摊类型: ${ruleType}`);
  }

  return {
    valid: errors.length === 0,
    errors,
  };
}

/**
 * 格式化金额（保留2位小数）
 */
export function formatSplitAmount(amount: number): string {
  return amount.toFixed(2);
}

/**
 * 格式化百分比
 */
export function formatPercentage(percentage: number): string {
  return `${percentage.toFixed(2)}%`;
}

/**
 * 计算支付进度百分比
 */
export function calculatePaymentProgress(paidAmount: number, totalAmount: number): number {
  if (totalAmount === 0) return 0;
  return Math.round((paidAmount / totalAmount) * 100);
}
