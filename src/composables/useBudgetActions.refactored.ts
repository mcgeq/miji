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
    fetchAll: () => budgetStore.fetchBudgetsPaged({
      currentPage: 1,
      pageSize: 10,
      sortOptions: { desc: true },
      filter: {},
    }),
  };

  // 使用通用 CRUD Actions
  const crudActions = useCrudActions<Budget, BudgetCreate, BudgetUpdate>(
    storeAdapter,
    {
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
    },
  );

  // 预算列表状态
  const budgets = computed(() => budgetStore.budgetsPaged.rows);

  /**
   * 切换预算激活状态
   */
  async function toggleBudgetActive(
    serialNum: string,
    isActive: boolean,
  ): Promise<boolean> {
    try {
      await budgetStore.toggleBudgetActive(serialNum, isActive);
      toast.success(
        isActive
          ? t('financial.messages.budgetActivated')
          : t('financial.messages.budgetDeactivated'),
      );

      // 刷新列表
      if (storeAdapter.fetchAll) {
        await storeAdapter.fetchAll();
      }

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
    isActive: boolean,
    onSuccess?: () => Promise<void> | void,
  ): Promise<boolean> {
    const success = await toggleBudgetActive(serialNum, isActive);
    if (success && onSuccess) {
      await onSuccess();
    }
    return success;
  }

  return {
    // 从 useCrudActions 继承的状态和方法
    showBudget: crudActions.show,
    selectedBudget: crudActions.selected,
    isViewMode: crudActions.isViewMode,
    loading: crudActions.loading,

    // 从 useCrudActions 继承的方法
    showBudgetModal: crudActions.showModal,
    closeBudgetModal: crudActions.closeModal,
    editBudget: crudActions.edit,
    viewBudget: crudActions.view,
    handleSaveBudget: crudActions.handleSave,
    handleUpdateBudget: crudActions.handleUpdate,
    handleDeleteBudget: crudActions.handleDelete,

    // 预算特有的状态
    budgets,

    // 预算特有的方法
    toggleBudgetActive,
    handleToggleBudgetActive,
  };
}
