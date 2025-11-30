import { useCrudActions } from '@/composables/useCrudActions';
import { useBudgetStore } from '@/stores/money';
import { toast } from '@/utils/toast';
import type { Budget, BudgetCreate, BudgetUpdate } from '@/schema/money';

/**
 * 预算操作 Composable - 重构版本
 * 使用 useCrudActions 简化代码
 */
export function useBudgetActions() {
  const budgetStore = useBudgetStore();
  const { t } = useI18n();

  // 创建 Store 适配器
  const storeAdapter = {
    create: (data: BudgetCreate) => budgetStore.createBudget(data),
    update: (id: string, data: BudgetUpdate) => budgetStore.updateBudget(id, data),
    delete: (id: string) => budgetStore.deleteBudget(id),
    fetchAll: () =>
      budgetStore.fetchBudgetsPaged({
        currentPage: 1,
        pageSize: 10,
        sortOptions: { desc: true },
        filter: {},
      }),
  };

  // 使用通用 CRUD Actions
  const crudActions = useCrudActions<Budget, BudgetCreate, BudgetUpdate>(storeAdapter, {
    successMessages: {
      create: t('financial.messages.budgetCreated'),
      update: t('financial.messages.budgetUpdated'),
      delete: t('financial.messages.budgetDeleted'),
    },
    errorMessages: {
      create: t('financial.messages.budgetCreateFailed'),
      update: t('financial.messages.budgetUpdateFailed'),
      delete: t('financial.messages.budgetDeleteFailed'),
    },
    autoRefresh: true,
    autoClose: true,
  });

  // 预算列表状态
  const budgets = computed(() => budgetStore.budgetsPaged.rows);

  /**
   * 切换预算激活状态
   * Store 会自动更新状态，无需手动刷新
   */
  async function toggleBudgetActive(serialNum: string): Promise<boolean> {
    try {
      const budget = budgets.value.find(b => b.serialNum === serialNum);
      // toggleBudgetActive 内部已经更新了 store 中的预算状态
      await budgetStore.toggleBudgetActive(serialNum, !budget?.isActive);
      toast.success(
        budget?.isActive
          ? t('financial.messages.budgetDeactivated')
          : t('financial.messages.budgetActivated'),
      );

      return true;
    } catch (error: any) {
      toast.error(error.message || t('financial.messages.budgetToggleFailed'));
      return false;
    }
  }

  /**
   * 包装切换状态方法，支持自定义回调
   */
  async function handleToggleBudgetActive(
    serialNum: string,
    onSuccess?: () => Promise<void> | void,
  ): Promise<boolean> {
    const success = await toggleBudgetActive(serialNum);
    if (success && onSuccess) {
      await onSuccess();
    }
    return success;
  }

  // 向后兼容的包装方法
  const saveBudget = async (data: BudgetCreate, onSuccess?: () => void) => {
    const result = await crudActions.handleSave(data);
    if (result && onSuccess) onSuccess();
    return result;
  };

  const updateBudget = async (serialNum: string, data: BudgetUpdate, onSuccess?: () => void) => {
    const result = await crudActions.handleUpdate(serialNum, data);
    if (result && onSuccess) onSuccess();
    return result;
  };

  const deleteBudget = async (
    serialNum: string,
    onConfirm?: () => Promise<boolean>,
    onSuccess?: () => void,
  ) => {
    if (onConfirm && !(await onConfirm())) return false;
    const result = await crudActions.handleDelete(serialNum);
    if (result && onSuccess) onSuccess();
    return result;
  };

  /**
   * 加载预算列表（使用 store 的全局刷新机制）
   */
  const loadBudgets = async () => {
    try {
      // 直接使用 store 的 fetchBudgetsPaged，它会触发全局刷新
      await storeAdapter.fetchAll();
      return true;
    } catch (error: any) {
      toast.error(error.message || t('financial.messages.budgetLoadFailed'));
      return false;
    }
  };

  return {
    // 从 useCrudActions 继承的状态和方法
    showBudget: crudActions.show,
    selectedBudget: computed(() => crudActions.selected.value as Budget | null),
    isViewMode: crudActions.isViewMode,
    loading: crudActions.loading,

    // 从 useCrudActions 继承的方法
    showBudgetModal: crudActions.showModal,
    closeBudgetModal: crudActions.closeModal,
    editBudget: crudActions.edit,
    viewBudget: crudActions.view,

    // 向后兼容的方法
    saveBudget,
    updateBudget,
    deleteBudget,
    handleSaveBudget: saveBudget,
    handleUpdateBudget: updateBudget,
    handleDeleteBudget: deleteBudget,
    loadBudgets,

    // 预算特有的状态
    budgets,

    // 预算特有的方法
    toggleBudgetActive,
    handleToggleBudgetActive,
  };
}
