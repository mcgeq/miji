/**
 * 预算分配 Store
 * Phase 6: 家庭预算管理
 */

import { invoke } from '@tauri-apps/api/core';
import { defineStore } from 'pinia';
import { computed, ref } from 'vue';
import type {
  BudgetAlertResponse,
  BudgetAllocationCreateRequest,
  BudgetAllocationResponse,
  BudgetAllocationUpdateRequest,
  BudgetUsageRequest,
} from '@/types/budget-allocation';

/**
 * 预算分配 Store
 */
export const useBudgetAllocationStore = defineStore('budget-allocation', () => {
  // ============================================================================
  // State
  // ============================================================================

  const allocations = ref<BudgetAllocationResponse[]>([]);
  const currentAllocation = ref<BudgetAllocationResponse | null>(null);
  const alerts = ref<BudgetAlertResponse[]>([]);
  const loading = ref(false);
  const error = ref<string | null>(null);

  // ============================================================================
  // Getters
  // ============================================================================

  /**
   * 活动的分配
   */
  const activeAllocations = computed(() => allocations.value.filter(a => a.status === 'ACTIVE'));

  /**
   * 已超支的分配
   */
  const exceededAllocations = computed(() => allocations.value.filter(a => a.isExceeded));

  /**
   * 预警中的分配
   */
  const warningAllocations = computed(() =>
    allocations.value.filter(a => a.isWarning && !a.isExceeded),
  );

  /**
   * 强制保障的分配
   */
  const mandatoryAllocations = computed(() => allocations.value.filter(a => a.isMandatory));

  /**
   * 按优先级排序的分配
   */
  const allocationsByPriority = computed(() =>
    [...allocations.value].sort((a, b) => b.priority - a.priority),
  );

  /**
   * 总体使用率
   */
  const overallUsageRate = computed(() => {
    if (allocations.value.length === 0) return 0;
    const totalAllocated = allocations.value.reduce((sum, a) => sum + a.allocatedAmount, 0);
    const totalUsed = allocations.value.reduce((sum, a) => sum + a.usedAmount, 0);
    return totalAllocated > 0 ? (totalUsed / totalAllocated) * 100 : 0;
  });

  /**
   * 统计信息
   */
  const statistics = computed(() => {
    const total = allocations.value.length;
    const active = activeAllocations.value.length;
    const exceeded = exceededAllocations.value.length;
    const warning = warningAllocations.value.length;
    const totalAllocated = allocations.value.reduce((sum, a) => sum + a.allocatedAmount, 0);
    const totalUsed = allocations.value.reduce((sum, a) => sum + a.usedAmount, 0);
    const totalRemaining = allocations.value.reduce((sum, a) => sum + a.remainingAmount, 0);

    return {
      total,
      active,
      exceeded,
      warning,
      totalAllocated,
      totalUsed,
      totalRemaining,
      overallUsageRate: overallUsageRate.value,
    };
  });

  /**
   * 根据ID获取分配
   */
  const getAllocationById = computed(() => (id: string) => {
    return allocations.value.find(a => a.serialNum === id);
  });

  /**
   * 根据成员获取分配
   */
  const getAllocationsByMember = computed(() => (memberSerialNum: string) => {
    return allocations.value.filter(a => a.memberSerialNum === memberSerialNum);
  });

  /**
   * 根据分类获取分配
   */
  const getAllocationsByCategory = computed(() => (categorySerialNum: string) => {
    return allocations.value.filter(a => a.categorySerialNum === categorySerialNum);
  });

  // ============================================================================
  // Actions
  // ============================================================================

  /**
   * 创建预算分配
   */
  async function createAllocation(
    budgetSerialNum: string,
    data: BudgetAllocationCreateRequest,
  ): Promise<BudgetAllocationResponse> {
    loading.value = true;
    error.value = null;

    try {
      const response = await invoke<{
        success: boolean;
        data: BudgetAllocationResponse;
        message?: string;
      }>('budget_allocation_create', {
        budgetSerialNum,
        data,
      });

      if (!response.success) {
        throw new Error(response.message || '创建分配失败');
      }

      // 重新加载分配列表
      await fetchAllocations(budgetSerialNum);

      return response.data;
    } catch (err: unknown) {
      error.value = err instanceof Error ? err.message : '创建分配失败';
      throw err;
    } finally {
      loading.value = false;
    }
  }

  /**
   * 更新预算分配
   */
  async function updateAllocation(
    serialNum: string,
    data: BudgetAllocationUpdateRequest,
  ): Promise<BudgetAllocationResponse> {
    loading.value = true;
    error.value = null;

    try {
      const response = await invoke<{
        success: boolean;
        data: BudgetAllocationResponse;
        message?: string;
      }>('budget_allocation_update', {
        serialNum,
        data,
      });

      if (!response.success) {
        throw new Error(response.message || '更新分配失败');
      }

      // 更新本地数据
      const index = allocations.value.findIndex(a => a.serialNum === serialNum);
      if (index !== -1) {
        allocations.value[index] = response.data;
      }

      return response.data;
    } catch (err: unknown) {
      error.value = err instanceof Error ? err.message : '更新分配失败';
      throw err;
    } finally {
      loading.value = false;
    }
  }

  /**
   * 删除预算分配
   */
  async function deleteAllocation(serialNum: string): Promise<void> {
    loading.value = true;
    error.value = null;

    try {
      const response = await invoke<{
        success: boolean;
        message?: string;
      }>('budget_allocation_delete', {
        serialNum,
      });

      if (!response.success) {
        throw new Error(response.message || '删除分配失败');
      }

      // 从本地删除
      const index = allocations.value.findIndex(a => a.serialNum === serialNum);
      if (index !== -1) {
        allocations.value.splice(index, 1);
      }
    } catch (err: unknown) {
      error.value = err instanceof Error ? err.message : '删除分配失败';
      throw err;
    } finally {
      loading.value = false;
    }
  }

  /**
   * 获取预算分配详情
   */
  async function fetchAllocation(serialNum: string): Promise<BudgetAllocationResponse> {
    loading.value = true;
    error.value = null;

    try {
      const response = await invoke<{
        success: boolean;
        data: BudgetAllocationResponse;
        message?: string;
      }>('budget_allocation_get', {
        serialNum,
      });

      if (!response.success) {
        throw new Error(response.message || '获取分配详情失败');
      }

      currentAllocation.value = response.data;
      return response.data;
    } catch (err: unknown) {
      error.value = err instanceof Error ? err.message : '获取分配详情失败';
      throw err;
    } finally {
      loading.value = false;
    }
  }

  /**
   * 获取预算的所有分配
   */
  async function fetchAllocations(budgetSerialNum: string): Promise<void> {
    loading.value = true;
    error.value = null;

    try {
      const response = await invoke<{
        success: boolean;
        data: BudgetAllocationResponse[];
        message?: string;
      }>('budget_allocations_list', {
        budgetSerialNum,
      });

      if (!response.success) {
        throw new Error(response.message || '获取分配列表失败');
      }

      allocations.value = response.data;
    } catch (err: unknown) {
      error.value = err instanceof Error ? err.message : '获取分配列表失败';
      throw err;
    } finally {
      loading.value = false;
    }
  }

  /**
   * 更新本地分配数据
   */
  function updateLocalAllocation(
    allocationSerialNum: string | undefined,
    updatedData: BudgetAllocationResponse,
  ) {
    if (!allocationSerialNum) return;
    const index = allocations.value.findIndex(a => a.serialNum === allocationSerialNum);
    if (index !== -1) {
      allocations.value[index] = updatedData;
    }
  }

  /**
   * 记录预算使用
   */
  async function recordUsage(data: BudgetUsageRequest): Promise<BudgetAllocationResponse> {
    loading.value = true;
    error.value = null;

    try {
      const response = await invoke<{
        success: boolean;
        data: BudgetAllocationResponse;
        message?: string;
      }>('budget_allocation_record_usage', {
        data,
      });

      if (!response.success) {
        throw new Error(response.message || '记录使用失败');
      }

      updateLocalAllocation(data.allocationSerialNum, response.data);

      if (response.data.isWarning) {
        await checkAlerts(data.budgetSerialNum);
      }

      return response.data;
    } catch (err: unknown) {
      error.value = err instanceof Error ? err.message : '记录使用失败';
      throw err;
    } finally {
      loading.value = false;
    }
  }

  /**
   * 检查是否可以消费
   */
  async function canSpend(
    allocationSerialNum: string,
    amount: number,
  ): Promise<{ canSpend: boolean; reason?: string }> {
    try {
      const response = await invoke<{
        success: boolean;
        data: [boolean, string | null];
        message?: string;
      }>('budget_allocation_can_spend', {
        allocationSerialNum,
        amount: amount.toString(),
      });

      if (!response.success) {
        return { canSpend: false, reason: response.message };
      }

      const [canSpend, reason] = response.data;
      return { canSpend, reason: reason || undefined };
    } catch (err: unknown) {
      return { canSpend: false, reason: err instanceof Error ? err.message : '检查消费失败' };
    }
  }

  /**
   * 检查预警
   */
  async function checkAlerts(budgetSerialNum: string): Promise<BudgetAlertResponse[]> {
    try {
      const response = await invoke<{
        success: boolean;
        data: BudgetAlertResponse[];
        message?: string;
      }>('budget_allocation_check_alerts', {
        budgetSerialNum,
      });

      if (!response.success) {
        throw new Error(response.message || '检查预警失败');
      }

      alerts.value = response.data;
      return response.data;
    } catch (err: unknown) {
      console.error('检查预警失败:', err);
      return [];
    }
  }

  /**
   * 清除错误
   */
  function clearError() {
    error.value = null;
  }

  /**
   * 清除预警
   */
  function clearAlerts() {
    alerts.value = [];
  }

  /**
   * 重置状态
   */
  function reset() {
    allocations.value = [];
    currentAllocation.value = null;
    alerts.value = [];
    loading.value = false;
    error.value = null;
  }

  // ============================================================================
  // Return
  // ============================================================================

  return {
    // State
    allocations,
    currentAllocation,
    alerts,
    loading,
    error,

    // Getters
    activeAllocations,
    exceededAllocations,
    warningAllocations,
    mandatoryAllocations,
    allocationsByPriority,
    overallUsageRate,
    statistics,
    getAllocationById,
    getAllocationsByMember,
    getAllocationsByCategory,

    // Actions
    createAllocation,
    updateAllocation,
    deleteAllocation,
    fetchAllocation,
    fetchAllocations,
    recordUsage,
    canSpend,
    checkAlerts,
    clearError,
    clearAlerts,
    reset,
  };
});
