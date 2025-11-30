/**
 * 分摊计算工具
 *
 * 提供各种分摊场景的计算功能：
 * - 平均分摊
 * - 固定金额分摊
 * - 按百分比分摊
 * - 按权重分摊
 */

import type { FamilyMember } from '@/schema/money/family';
import type { SplitMember } from '@/schema/money/transaction';

/**
 * 分摊类型
 */
export enum SplitType {
  Equal = 'equal', // 平均分摊
  FixedAmount = 'amount', // 固定金额
  Percentage = 'percentage', // 按百分比
  Weighted = 'weighted', // 按权重
  Custom = 'custom', // 自定义
}

/**
 * 分摊计算结果
 */
export interface SplitResult {
  member: FamilyMember;
  amount: number;
  percentage: number;
  isValid: boolean;
  error?: string;
}

export function useSplitCalculator() {
  /**
   * 平均分摊计算
   */
  function calculateEqualSplit(totalAmount: number, members: FamilyMember[]): SplitResult[] {
    if (members.length === 0) return [];

    const perPersonAmount = totalAmount / members.length;
    const percentage = 100 / members.length;

    return members.map(member => ({
      member,
      amount: perPersonAmount,
      percentage,
      isValid: true,
    }));
  }

  /**
   * 固定金额分摊
   */
  function calculateFixedAmountSplit(
    totalAmount: number,
    membersWithAmount: Array<{ member: FamilyMember; amount?: number }>,
  ): SplitResult[] {
    const results: SplitResult[] = [];
    let assignedAmount = 0;
    const unassignedMembers: FamilyMember[] = [];

    // 先处理有指定金额的成员
    for (const { member, amount } of membersWithAmount) {
      if (amount !== undefined && amount > 0) {
        assignedAmount += amount;
        results.push({
          member,
          amount,
          percentage: (amount / totalAmount) * 100,
          isValid: amount <= totalAmount,
        });
      } else {
        unassignedMembers.push(member);
      }
    }

    // 剩余金额平均分配给未指定的成员
    const remainingAmount = totalAmount - assignedAmount;
    if (unassignedMembers.length > 0 && remainingAmount > 0) {
      const perPersonAmount = remainingAmount / unassignedMembers.length;
      for (const member of unassignedMembers) {
        results.push({
          member,
          amount: perPersonAmount,
          percentage: (perPersonAmount / totalAmount) * 100,
          isValid: true,
        });
      }
    }

    // 验证总金额
    const totalAssigned = results.reduce((sum, r) => sum + r.amount, 0);
    const isOverBudget = totalAssigned > totalAmount;

    return results.map(r => ({
      ...r,
      isValid: r.isValid && !isOverBudget,
      error: isOverBudget ? '总金额超出交易金额' : undefined,
    }));
  }

  /**
   * 按百分比分摊
   */
  function calculatePercentageSplit(
    totalAmount: number,
    membersWithPercentage: Array<{ member: FamilyMember; percentage?: number }>,
  ): SplitResult[] {
    let totalPercentage = 0;
    const results: SplitResult[] = [];

    for (const { member, percentage } of membersWithPercentage) {
      const pct = percentage ?? 0;
      totalPercentage += pct;

      results.push({
        member,
        amount: (totalAmount * pct) / 100,
        percentage: pct,
        isValid: pct >= 0 && pct <= 100,
      });
    }

    const isValid = Math.abs(totalPercentage - 100) < 0.01;

    return results.map(r => ({
      ...r,
      isValid: r.isValid && isValid,
      error: isValid ? undefined : `总百分比为 ${totalPercentage}%，应为 100%`,
    }));
  }

  /**
   * 按权重分摊
   */
  function calculateWeightedSplit(
    totalAmount: number,
    membersWithWeight: Array<{ member: FamilyMember; weight?: number }>,
  ): SplitResult[] {
    const totalWeight = membersWithWeight.reduce((sum, { weight }) => sum + (weight ?? 1), 0);

    return membersWithWeight.map(({ member, weight }) => {
      const w = weight ?? 1;
      const amount = (totalAmount * w) / totalWeight;
      const percentage = (w / totalWeight) * 100;

      return {
        member,
        amount,
        percentage,
        isValid: w > 0,
      };
    });
  }

  /**
   * 创建分摊成员对象
   */
  function createSplitMember(
    member: FamilyMember,
    options?: {
      amount?: number;
      payerSerialNum?: string;
      percentage?: number;
      weight?: number;
    },
  ): SplitMember {
    return {
      serialNum: member.serialNum,
      name: member.name,
      avatar: member.avatar,
      colorTag: member.colorTag,
      ...options,
    };
  }

  /**
   * 验证分摊数据
   */
  function validateSplitData(
    totalAmount: number,
    splitMembers: SplitMember[],
  ): { isValid: boolean; errors: string[] } {
    const errors: string[] = [];

    if (splitMembers.length === 0) {
      errors.push('至少需要一个分摊成员');
    }

    // 检查固定金额总和
    const totalFixedAmount = splitMembers
      .filter(m => m.amount !== undefined)
      .reduce((sum, m) => sum + (m.amount || 0), 0);

    if (totalFixedAmount > totalAmount) {
      errors.push(`固定金额总和 (${totalFixedAmount}) 超出交易金额 (${totalAmount})`);
    }

    // 检查百分比总和
    const membersWithPercentage = splitMembers.filter(m => m.percentage !== undefined);
    if (membersWithPercentage.length > 0) {
      const totalPercentage = membersWithPercentage.reduce(
        (sum, m) => sum + (m.percentage || 0),
        0,
      );
      if (Math.abs(totalPercentage - 100) > 0.01) {
        errors.push(`百分比总和为 ${totalPercentage}%，应为 100%`);
      }
    }

    return {
      isValid: errors.length === 0,
      errors,
    };
  }

  /**
   * 格式化金额显示
   */
  function formatAmount(amount: number, decimals: number = 2): string {
    return amount.toFixed(decimals);
  }

  /**
   * 格式化百分比显示
   */
  function formatPercentage(percentage: number, decimals: number = 1): string {
    return `${percentage.toFixed(decimals)}%`;
  }

  return {
    // 计算函数
    calculateEqualSplit,
    calculateFixedAmountSplit,
    calculatePercentageSplit,
    calculateWeightedSplit,

    // 工具函数
    createSplitMember,
    validateSplitData,
    formatAmount,
    formatPercentage,

    // 枚举
    SplitType,
  };
}
