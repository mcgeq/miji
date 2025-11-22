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
   * 加载账户列表（使用 store 的全局刷新机制）
   */
  async function loadAccountsWithLoading(): Promise<boolean> {
    accountsLoading.value = true;
    try {
      // 直接使用 store 的 fetchAccounts，它会触发全局刷新
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
   * Store 会自动更新状态，无需手动刷新
   */
  async function toggleAccountActive(
    serialNum: string,
  ): Promise<boolean> {
    try {
      const account = accountStore.getAccountById(serialNum);
      // 保存切换前的状态，因为 account 可能是响应式对象
      const wasActive = account?.isActive ?? false;

      // toggleAccountActive 内部已经更新了 store 中的账户状态
      await accountStore.toggleAccountActive(serialNum);

      toast.success(
        wasActive
          ? t('financial.messages.accountDeactivated')
          : t('financial.messages.accountActivated'),
      );

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
    onSuccess?: () => Promise<void> | void,
  ): Promise<boolean> {
    const success = await toggleAccountActive(serialNum);
    if (success && onSuccess) {
      await onSuccess();
    }
    return success;
  }

  // 向后兼容的包装方法
  const saveAccount = async (data: CreateAccountRequest, onSuccess?: () => void) => {
    const result = await crudActions.handleSave(data);
    if (result && onSuccess) onSuccess();
    return result;
  };

  const updateAccount = async (serialNum: string, data: UpdateAccountRequest, onSuccess?: () => void) => {
    const result = await crudActions.handleUpdate(serialNum, data);
    if (result && onSuccess) onSuccess();
    return result;
  };

  const deleteAccount = async (serialNum: string, onConfirm?: () => Promise<boolean>, onSuccess?: () => void) => {
    if (onConfirm && !(await onConfirm())) return false;
    const result = await crudActions.handleDelete(serialNum);
    if (result && onSuccess) onSuccess();
    return result;
  };

  return {
    // 从 useCrudActions 继承的状态和方法
    showAccount: crudActions.show,
    selectedAccount: computed(() => crudActions.selected.value as Account | null),
    isViewMode: crudActions.isViewMode,
    loading: crudActions.loading,

    // 从 useCrudActions 继承的方法
    showAccountModal: crudActions.showModal,
    closeAccountModal: crudActions.closeModal,
    editAccount: crudActions.edit,
    viewAccount: crudActions.view,

    // 向后兼容的方法
    saveAccount,
    updateAccount,
    deleteAccount,
    handleSaveAccount: saveAccount,
    handleUpdateAccount: updateAccount,
    handleDeleteAccount: deleteAccount,
    loadAccounts: loadAccountsWithLoading,

    // 账户特有的状态
    accounts,
    accountsLoading: readonly(accountsLoading),

    // 账户特有的方法
    loadAccountsWithLoading,
    toggleAccountActive,
    handleToggleAccountActive,
  };
}
