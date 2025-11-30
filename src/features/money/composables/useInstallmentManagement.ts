/**
 * 分期管理逻辑 Composable
 *
 * 职责：
 * - 分期计算
 * - 分期计划加载
 * - 分期状态管理
 * - 分期详情展示
 */

import { invokeCommand } from '@/types/api';
import { DateUtils } from '@/utils/date';
import { Lg } from '@/utils/debugLog';
import { toast } from '@/utils/toast';
import { INSTALLMENT_CONSTANTS, InstallmentStatus } from '../constants/transactionConstants';
import { parseAmount } from '../utils/numberUtils';
import type { InstallmentCalculationRequest, InstallmentCalculationResponse } from '@/schema/money';
import type { InstallmentPlanResponse } from '@/services/money/transactions';

/**
 * 分期详情接口
 */
export interface InstallmentDetail {
  period: number;
  amount: number;
  dueDate: string;
  status: InstallmentStatus;
  paidDate?: string;
  paidAmount?: number;
}

/**
 * 分期管理配置
 */
export interface InstallmentConfig {
  enabled: boolean;
  totalPeriods: number;
  firstDueDate?: string;
  installmentAmount: number;
}

export function useInstallmentManagement() {
  // ==================== 状态管理 ====================
  const isCalculating = ref(false);
  const calculationResult = ref<InstallmentCalculationResponse | null>(null);
  const planDetails = ref<InstallmentPlanResponse | null>(null);
  const hasPaidInstallments = ref(false);
  const isExpanded = ref(false);

  // ==================== 计算属性 ====================

  /**
   * 计算的每期金额
   */
  const calculatedInstallmentAmount = computed(() => {
    // 编辑模式：使用分期计划详情数据
    if (planDetails.value) {
      if (planDetails.value.installment_amount) {
        return parseAmount(planDetails.value.installment_amount);
      }
      // 降级方案：使用第一期的金额
      if (planDetails.value.details && planDetails.value.details.length > 0) {
        return parseAmount(planDetails.value.details[0].amount);
      }
      return 0;
    }

    // 创建模式：使用计算结果数据
    return parseAmount(calculationResult.value?.installment_amount);
  });

  /**
   * 格式化后的分期详情
   */
  const installmentDetails = computed<InstallmentDetail[] | null>(() => {
    // 编辑模式
    if (planDetails.value?.details) {
      return formatInstallmentDetails(planDetails.value.details);
    }

    // 创建模式
    if (calculationResult.value?.details) {
      return formatInstallmentDetails(calculationResult.value.details);
    }

    return null;
  });

  /**
   * 可见的分期详情（展开/收起）
   */
  const visibleDetails = computed(() => {
    if (!installmentDetails.value) return null;

    return isExpanded.value ? installmentDetails.value : installmentDetails.value.slice(0, 2);
  });

  /**
   * 是否有更多期数
   */
  const hasMorePeriods = computed(() => {
    return installmentDetails.value && installmentDetails.value.length > 2;
  });

  /**
   * 分期字段是否应禁用
   */
  const isFieldsDisabled = computed(() => {
    return hasPaidInstallments.value;
  });

  // ==================== 统计信息 ====================

  /**
   * 获取已入账期数
   */
  const paidPeriodsCount = computed(() => {
    if (!installmentDetails.value) return 0;
    return installmentDetails.value.filter(d => d.status === InstallmentStatus.PAID).length;
  });

  /**
   * 获取待入账期数
   */
  const pendingPeriodsCount = computed(() => {
    if (!installmentDetails.value) return 0;
    return installmentDetails.value.filter(
      d => d.status === InstallmentStatus.PENDING || d.status === InstallmentStatus.OVERDUE,
    ).length;
  });

  /**
   * 获取总期数
   */
  const totalPeriodsCount = computed(() => {
    return installmentDetails.value?.length || 0;
  });

  // ==================== 核心方法 ====================

  /**
   * 调用后端API计算分期金额
   */
  async function calculateInstallment(
    amount: number,
    totalPeriods: number,
    firstDueDate?: string,
    transactionDate?: string,
  ): Promise<boolean> {
    // 验证必需参数
    if (
      !amount ||
      amount <= 0 ||
      !totalPeriods ||
      totalPeriods < INSTALLMENT_CONSTANTS.MIN_PERIODS
    ) {
      calculationResult.value = null;
      return false;
    }

    try {
      isCalculating.value = true;

      const request: InstallmentCalculationRequest = {
        total_amount: amount,
        total_periods: totalPeriods,
        first_due_date: firstDueDate
          ? DateUtils.formatDateOnly(new Date(firstDueDate))
          : DateUtils.formatDateOnly(new Date(transactionDate || new Date())),
      };

      const response = await invokeCommand<InstallmentCalculationResponse>(
        'installment_calculate',
        { data: request },
      );

      // 确保每个detail都有status字段
      if (response.details) {
        response.details = response.details.map(detail => ({
          ...detail,
          status: detail.status || InstallmentStatus.PENDING,
        }));
      }

      calculationResult.value = response;
      return true;
    } catch (error) {
      Lg.e('useInstallmentManagement', 'Failed to calculate installment:', error);
      toast.error('计算分期金额失败');
      calculationResult.value = null;
      return false;
    } finally {
      isCalculating.value = false;
    }
  }

  /**
   * 加载分期计划详情（根据计划序列号）
   */
  async function loadPlanBySerialNum(planSerialNum: string): Promise<boolean> {
    try {
      const response = await invokeCommand<InstallmentPlanResponse>('installment_plan_get', {
        planSerialNum,
      });

      processPlanResponse(response);
      return true;
    } catch (error) {
      Lg.e('useInstallmentManagement', 'Failed to load plan by serial num:', error);
      toast.error('加载分期计划详情失败');
      return false;
    }
  }

  /**
   * 加载分期计划详情（根据交易序列号）
   */
  async function loadPlanByTransaction(transactionSerialNum: string): Promise<boolean> {
    try {
      const response = await invokeCommand<InstallmentPlanResponse>(
        'installment_plan_get_by_transaction',
        { transactionSerialNum },
      );

      processPlanResponse(response);
      return true;
    } catch (error) {
      Lg.e('useInstallmentManagement', 'Failed to load plan by transaction:', error);
      // 如果根据交易序列号查询失败，说明确实没有分期计划，不显示错误提示
      console.warn('该交易没有分期计划');
      return false;
    }
  }

  /**
   * 检查交易是否有已完成的分期付款
   */
  async function checkPaidStatus(transactionSerialNum: string): Promise<void> {
    if (!transactionSerialNum) {
      hasPaidInstallments.value = false;
      return;
    }

    try {
      const response = await invokeCommand<boolean>('installment_has_paid', {
        transactionSerialNum,
      });
      hasPaidInstallments.value = response;
    } catch (error) {
      Lg.e('useInstallmentManagement', 'Failed to check paid status:', error);
      hasPaidInstallments.value = false;
    }
  }

  /**
   * 重置分期状态
   */
  function resetInstallmentState(): void {
    calculationResult.value = null;
    planDetails.value = null;
    hasPaidInstallments.value = false;
    isExpanded.value = false;
  }

  /**
   * 切换展开/收起
   */
  function toggleExpanded(): void {
    isExpanded.value = !isExpanded.value;
  }

  // ==================== 内部辅助方法 ====================

  /**
   * 处理分期计划响应
   */
  function processPlanResponse(response: InstallmentPlanResponse | null): void {
    if (!response?.details) return;

    planDetails.value = response;
  }

  /**
   * 格式化分期详情
   */
  function formatInstallmentDetails(sourceDetails: any[]): InstallmentDetail[] {
    if (!sourceDetails || sourceDetails.length === 0) return [];

    const firstPeriodAmount = parseAmount(sourceDetails[0]?.amount);

    return sourceDetails.map((detail: any, index: number) => ({
      period: detail.periodNumber || detail.period_number || detail.period || index + 1,
      amount: parseAmount(detail.amount) || firstPeriodAmount,
      dueDate: detail.dueDate || detail.due_date || '',
      status: parseInstallmentStatus(detail.status),
      paidDate: detail.paidDate || detail.paid_date || undefined,
      paidAmount:
        detail.paidAmount || detail.paid_amount
          ? parseAmount(detail.paidAmount || detail.paid_amount)
          : undefined,
    }));
  }

  /**
   * 解析分期状态
   */
  function parseInstallmentStatus(status?: string): InstallmentStatus {
    if (!status) return InstallmentStatus.PENDING;

    const upperStatus = status.toUpperCase();
    return (
      InstallmentStatus[upperStatus as keyof typeof InstallmentStatus] || InstallmentStatus.PENDING
    );
  }

  return {
    // 状态
    isCalculating: readonly(isCalculating),
    calculationResult: readonly(calculationResult),
    planDetails: readonly(planDetails),
    hasPaidInstallments: readonly(hasPaidInstallments),
    isExpanded: readonly(isExpanded),

    // 计算属性
    calculatedInstallmentAmount,
    installmentDetails,
    visibleDetails,
    hasMorePeriods,
    isFieldsDisabled,

    // 统计
    paidPeriodsCount,
    pendingPeriodsCount,
    totalPeriodsCount,

    // 方法
    calculateInstallment,
    loadPlanBySerialNum,
    loadPlanByTransaction,
    checkPaidStatus,
    resetInstallmentState,
    toggleExpanded,
  };
}
