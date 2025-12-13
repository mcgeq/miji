import { AppErrorSeverity } from '@/errors/appError';
import type { Budget, BudgetCreate } from '@/schema/money';
import { invokeCommand } from '@/types/api';
import type { BudgetAllocationCreateRequest } from '@/types/budget-allocation';
import { throwAppError } from '@/utils/errorHandler';
import { toast } from '@/utils/toast';

/**
 * 家庭预算操作 Composable
 */
export function useFamilyBudgetActions() {
  const showModal = ref(false);
  const selectedBudget = ref<Budget | null>(null);
  const isSubmitting = ref(false);

  /**
   * 显示创建家庭预算模态框
   */
  function showCreateModal() {
    selectedBudget.value = null;
    showModal.value = true;
  }

  /**
   * 显示编辑家庭预算模态框
   */
  function showEditModal(budget: Budget) {
    selectedBudget.value = budget;
    showModal.value = true;
  }

  /**
   * 关闭模态框
   */
  function closeModal() {
    showModal.value = false;
    selectedBudget.value = null;
  }

  /**
   * 创建成员分配
   */
  async function createBudgetAllocations(
    budgetSerialNum: string,
    allocations: BudgetAllocationCreateRequest[],
  ): Promise<void> {
    if (allocations.length === 0) return;

    const allocationPromises = allocations.map(allocation =>
      invokeCommand('budget_allocation_create', {
        budgetSerialNum,
        data: allocation,
      }),
    );

    await Promise.all(allocationPromises);
  }

  /**
   * 获取创建成功消息
   */
  function getSuccessMessage(allocationCount: number): string {
    return allocationCount > 0
      ? `预算创建成功，已配置 ${allocationCount} 个成员分配`
      : '预算创建成功';
  }

  /**
   * 创建家庭预算及其成员分配
   */
  async function createFamilyBudget(
    budgetData: BudgetCreate,
    allocations: BudgetAllocationCreateRequest[],
    onSuccess?: () => Promise<void> | void,
  ): Promise<boolean> {
    if (isSubmitting.value) return false;
    isSubmitting.value = true;

    try {
      // 1. 创建预算
      const createdBudget = await invokeCommand<Budget>('budget_create', {
        data: budgetData,
      });

      if (!createdBudget?.serialNum) {
        throwAppError('FamilyBudget', 'CREATE_FAILED', '预算创建失败', AppErrorSeverity.HIGH);
      }

      // 2. 创建成员分配
      await createBudgetAllocations(createdBudget.serialNum, allocations);

      // 3. 显示成功消息
      toast.success(getSuccessMessage(allocations.length));

      if (onSuccess) {
        await onSuccess();
      }

      return true;
    } catch (error: unknown) {
      console.error('创建家庭预算失败:', error);
      const message = error instanceof Error ? error.message : '创建家庭预算失败';
      toast.error(message);
      return false;
    } finally {
      isSubmitting.value = false;
    }
  }

  /**
   * 删除预算
   */
  async function deleteBudget(
    serialNum: string,
    onConfirm?: () => Promise<boolean>,
    onSuccess?: () => Promise<void> | void,
  ): Promise<boolean> {
    try {
      // 如果提供了确认回调，先确认
      if (onConfirm) {
        const confirmed = await onConfirm();
        if (!confirmed) return false;
      }

      await invokeCommand('budget_delete', { serialNum });
      toast.success('预算删除成功');

      if (onSuccess) {
        await onSuccess();
      }

      return true;
    } catch (error: unknown) {
      console.error('删除预算失败:', error);
      const message = error instanceof Error ? error.message : '删除预算失败';
      toast.error(message);
      return false;
    }
  }

  /**
   * 切换预算激活状态
   */
  async function toggleBudgetActive(
    serialNum: string,
    isActive: boolean,
    onSuccess?: () => Promise<void> | void,
  ): Promise<boolean> {
    try {
      await invokeCommand('budget_update_active', {
        serialNum,
        isActive,
      });

      toast.success(isActive ? '预算已激活' : '预算已停用');

      if (onSuccess) {
        await onSuccess();
      }

      return true;
    } catch (error: unknown) {
      console.error('切换预算状态失败:', error);
      const message = error instanceof Error ? error.message : '操作失败';
      toast.error(message);
      return false;
    }
  }

  return {
    // 状态
    showModal,
    selectedBudget,
    isSubmitting,

    // 方法
    showCreateModal,
    showEditModal,
    closeModal,
    createFamilyBudget,
    deleteBudget,
    toggleBudgetActive,
  };
}
