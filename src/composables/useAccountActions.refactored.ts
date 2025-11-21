import { useCrudActions } from '@/composables/useCrudActions';
import { useAccountStore } from '@/stores/money';
import { toast } from '@/utils/toast';
import type { Account, CreateAccountRequest, UpdateAccountRequest } from '@/schema/money';

/**
 * 账户操作 Composable - 重构版本
 * 使用 useCrudActions 简化代码
 */
export function useAccountActions() {
  const accountStore = useAccountStore();
  const { t } = useI18n();

  // 创建 Store 适配器以匹配 CrudStore 接口
  const storeAdapter = {
    create: (data: CreateAccountRequest) => accountStore.createAccount(data),
    update: (id: string, data: UpdateAccountRequest) => accountStore.updateAccount(id, data),
    delete: (id: string) => accountStore.deleteAccount(id),
    fetchAll: () => accountStore.fetchAccounts(),
  };

  // 使用通用 CRUD Actions
  const crudActions = useCrudActions<Account, CreateAccountRequest, UpdateAccountRequest>(
    storeAdapter,
    {
      successMessages: {
        create: t('financial.messages.accountCreated'),
        update: t('financial.messages.accountUpdated'),
        delete: t('financial.messages.accountDeleted'),
      },
      errorMessages: {
        create: t('financial.messages.accountCreateFailed'),
        update: t('financial.messages.accountUpdateFailed'),
        delete: t('financial.messages.accountDeleteFailed'),
      },
      autoRefresh: true,
      autoClose: true,
    },
  );

  // 账户列表状态
  const accounts = computed(() => accountStore.accounts);
  const accountsLoading = ref(false);

  /**
   * 加载账户列表（带加载状态）
   */
  async function loadAccountsWithLoading(): Promise<boolean> {
    accountsLoading.value = true;
    try {
      await accountStore.fetchAccounts();
      return true;
    } catch (error: any) {
      toast.error(error.message || t('financial.messages.accountLoadFailed'));
      return false;
    } finally {
      accountsLoading.value = false;
    }
  }

  /**
   * 切换账户激活状态
   */
  async function toggleAccountActive(
    serialNum: string,
    isActive: boolean,
  ): Promise<boolean> {
    try {
      await accountStore.toggleAccountActive(serialNum);
      toast.success(
        isActive
          ? t('financial.messages.accountActivated')
          : t('financial.messages.accountDeactivated'),
      );

      // 刷新列表
      if (accountStore.fetchAccounts) {
        await accountStore.fetchAccounts();
      }

      return true;
    } catch (error: any) {
      toast.error(error.message || t('financial.messages.accountToggleFailed'));
      return false;
    }
  }

  /**
   * 包装切换状态方法，支持自定义回调
   */
  async function handleToggleAccountActive(
    serialNum: string,
    isActive: boolean,
    onSuccess?: () => Promise<void> | void,
  ): Promise<boolean> {
    const success = await toggleAccountActive(serialNum, isActive);
    if (success && onSuccess) {
      await onSuccess();
    }
    return success;
  }

  return {
    // 从 useCrudActions 继承的状态和方法
    showAccount: crudActions.show,
    selectedAccount: crudActions.selected,
    isViewMode: crudActions.isViewMode,
    loading: crudActions.loading,

    // 从 useCrudActions 继承的方法
    showAccountModal: crudActions.showModal,
    closeAccountModal: crudActions.closeModal,
    editAccount: crudActions.edit,
    viewAccount: crudActions.view,
    handleSaveAccount: crudActions.handleSave,
    handleUpdateAccount: crudActions.handleUpdate,
    handleDeleteAccount: crudActions.handleDelete,

    // 账户特有的状态
    accounts,
    accountsLoading: readonly(accountsLoading),

    // 账户特有的方法
    loadAccountsWithLoading,
    toggleAccountActive,
    handleToggleAccountActive,
  };
}
