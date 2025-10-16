import { Lg } from '@/utils/debugLog';
import { toast } from '@/utils/toast';
import type { Account, CreateAccountRequest, UpdateAccountRequest } from '@/schema/money';

export function useAccountActions() {
  const moneyStore = useMoneyStore();

  const showAccount = ref(false);
  const selectedAccount = ref<Account | null>(null);
  const accounts = ref<Account[]>([]);
  const accountsLoading = ref(false);

  // 显示账户模态框
  function showAccountModal() {
    selectedAccount.value = null;
    showAccount.value = true;
  }

  // 关闭账户模态框
  function closeAccountModal() {
    showAccount.value = false;
    selectedAccount.value = null;
  }

  // 编辑账户
  function editAccount(account: Account) {
    selectedAccount.value = account;
    showAccount.value = true;
  }

  // 保存账户
  async function saveAccount(account: CreateAccountRequest) {
    try {
      await moneyStore.createAccount(account);
      toast.success('添加成功');
      closeAccountModal();
      return true;
    } catch (err) {
      Lg.e('saveAccount', err);
      toast.error('保存失败');
      return false;
    }
  }

  // 更新账户
  async function updateAccount(serialNum: string, account: UpdateAccountRequest) {
    try {
      if (selectedAccount.value) {
        await moneyStore.updateAccount(serialNum, account);
        toast.success('更新成功');
        closeAccountModal();
        return true;
      }
      return false;
    } catch (err) {
      Lg.e('updateAccount', err);
      toast.error('保存失败');
      return false;
    }
  }

  // 删除账户
  async function deleteAccount(
    serialNum: string,
    confirmDelete?: (message: string) => Promise<boolean>,
  ) {
    if (confirmDelete && !(await confirmDelete('此账户'))) {
      return false;
    }

    try {
      await moneyStore.deleteAccount(serialNum);
      toast.success('删除成功');
      return true;
    } catch (err) {
      Lg.e('deleteAccount', err);
      toast.error('删除失败');
      return false;
    }
  }

  // 切换账户状态
  async function toggleAccountActive(serialNum: string, isActive: boolean) {
    try {
      await moneyStore.toggleAccountActive(serialNum, isActive);
      toast.success('状态更新成功');
      return true;
    } catch (err) {
      Lg.e('toggleAccountActive', err);
      toast.error('状态更新失败');
      return false;
    }
  }

  // 加载账户列表（基础版本）
  async function loadAccounts() {
    try {
      accounts.value = await moneyStore.getAllAccounts();
      return true;
    } catch (err) {
      Lg.e('loadAccounts', err);
      return false;
    }
  }

  // 加载账户列表（带加载状态）
  async function loadAccountsWithLoading() {
    accountsLoading.value = true;
    try {
      accounts.value = await moneyStore.getAllAccounts();
      return true;
    } catch (err) {
      Lg.e('loadAccountsWithLoading', err);
      return false;
    } finally {
      accountsLoading.value = false;
    }
  }

  // 包装保存方法，支持自定义回调
  async function handleSaveAccount(
    account: CreateAccountRequest,
    onSuccess?: () => Promise<void> | void,
  ) {
    const success = await saveAccount(account);
    if (success && onSuccess) {
      await onSuccess();
    }
    return success;
  }

  // 包装更新方法，支持自定义回调
  async function handleUpdateAccount(
    serialNum: string,
    account: UpdateAccountRequest,
    onSuccess?: () => Promise<void> | void,
  ) {
    const success = await updateAccount(serialNum, account);
    if (success && onSuccess) {
      await onSuccess();
    }
    return success;
  }

  // 包装删除方法，支持自定义回调
  async function handleDeleteAccount(
    serialNum: string,
    confirmDelete?: (message: string) => Promise<boolean>,
    onSuccess?: () => Promise<void> | void,
  ) {
    const success = await deleteAccount(serialNum, confirmDelete);
    if (success && onSuccess) {
      await onSuccess();
    }
    return success;
  }

  // 包装切换状态方法，支持自定义回调
  async function handleToggleAccountActive(
    serialNum: string,
    isActive: boolean,
    onSuccess?: () => Promise<void> | void,
  ) {
    const success = await toggleAccountActive(serialNum, isActive);
    if (success && onSuccess) {
      await onSuccess();
    }
    return success;
  }

  return {
    // 状态
    showAccount,
    selectedAccount,
    accounts,
    accountsLoading,

    // 基础方法
    showAccountModal,
    closeAccountModal,
    editAccount,
    saveAccount,
    updateAccount,
    deleteAccount,
    toggleAccountActive,
    loadAccounts,
    loadAccountsWithLoading,

    // 包装方法（支持回调）
    handleSaveAccount,
    handleUpdateAccount,
    handleDeleteAccount,
    handleToggleAccountActive,
  };
}
