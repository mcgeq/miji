import { useBudgetStore } from '@/stores/money';
import { Lg } from '@/utils/debugLog';
import { toast } from '@/utils/toast';
import type { Budget, BudgetCreate, BudgetUpdate } from '@/schema/money';

export function useBudgetActions() {
  const budgetStore = useBudgetStore();

  const showBudget = ref(false);
  const selectedBudget = ref<Budget | null>(null);
  const budgets = ref<Budget[]>([]);

  // 显示预算模态框
  function showBudgetModal() {
    selectedBudget.value = null;
    showBudget.value = true;
  }

  // 关闭预算模态框
  function closeBudgetModal() {
    showBudget.value = false;
    selectedBudget.value = null;
  }

  // 编辑预算
  function editBudget(budget: Budget) {
    selectedBudget.value = budget;
    showBudget.value = true;
  }

  // 保存预算
  async function saveBudget(budget: BudgetCreate) {
    try {
      await budgetStore.createBudget(budget);
      toast.success('添加成功');
      closeBudgetModal();
      return true;
    } catch (err) {
      Lg.e('saveBudget', err);
      toast.error('保存失败');
      return false;
    }
  }

  // 更新预算
  async function updateBudget(serialNum: string, budget: BudgetUpdate) {
    try {
      if (selectedBudget.value) {
        await budgetStore.updateBudget(serialNum, budget);
        toast.success('更新成功');
        closeBudgetModal();
        return true;
      }
      return false;
    } catch (err) {
      Lg.e('updateBudget', err);
      toast.error('保存失败');
      return false;
    }
  }

  // 删除预算
  async function deleteBudget(
    serialNum: string,
    confirmDelete?: (message: string) => Promise<boolean>,
  ) {
    if (confirmDelete && !(await confirmDelete('此预算'))) {
      return false;
    }

    try {
      await budgetStore.deleteBudget(serialNum);
      toast.success('删除成功');
      return true;
    } catch (err) {
      Lg.e('deleteBudget', err);
      toast.error('删除失败');
      return false;
    }
  }

  // 切换预算状态
  async function toggleBudgetActive(serialNum: string) {
    try {
      await budgetStore.toggleBudgetActive(serialNum);
      toast.success('状态更新成功');
      return true;
    } catch (err) {
      Lg.e('toggleBudgetActive', err);
      toast.error('状态更新失败');
      return false;
    }
  }

  // 加载预算列表
  async function loadBudgets() {
    try {
      budgets.value = budgetStore.budgetsPaged.rows;
      if (budgets.value.length === 0) {
        await budgetStore.fetchBudgetsPaged({
          currentPage: 1,
          pageSize: 10,
          sortOptions: {
            desc: true,
          },
          filter: {},
        });
        budgets.value = budgetStore.budgetsPaged.rows;
      }
      return true;
    } catch (err) {
      Lg.e('loadBudgets', err);
      return false;
    }
  }

  // 包装保存方法，支持自定义回调
  async function handleSaveBudget(budget: BudgetCreate, onSuccess?: () => Promise<void> | void) {
    const success = await saveBudget(budget);
    if (success && onSuccess) {
      await onSuccess();
    }
    return success;
  }

  // 包装更新方法，支持自定义回调
  async function handleUpdateBudget(
    serialNum: string,
    budget: BudgetUpdate,
    onSuccess?: () => Promise<void> | void,
  ) {
    const success = await updateBudget(serialNum, budget);
    if (success && onSuccess) {
      await onSuccess();
    }
    return success;
  }

  // 包装删除方法，支持自定义回调
  async function handleDeleteBudget(
    serialNum: string,
    confirmDelete?: (message: string) => Promise<boolean>,
    onSuccess?: () => Promise<void> | void,
  ) {
    const success = await deleteBudget(serialNum, confirmDelete);
    if (success && onSuccess) {
      await onSuccess();
    }
    return success;
  }

  // 包装切换状态方法，支持自定义回调
  async function handleToggleBudgetActive(
    serialNum: string,
    onSuccess?: () => Promise<void> | void,
  ) {
    const success = await toggleBudgetActive(serialNum);
    if (success && onSuccess) {
      await onSuccess();
    }
    return success;
  }

  return {
    // 状态
    showBudget,
    selectedBudget,
    budgets,

    // 基础方法
    showBudgetModal,
    closeBudgetModal,
    editBudget,
    saveBudget,
    updateBudget,
    deleteBudget,
    toggleBudgetActive,
    loadBudgets,

    // 包装方法（支持回调）
    handleSaveBudget,
    handleUpdateBudget,
    handleDeleteBudget,
    handleToggleBudgetActive,
  };
}
