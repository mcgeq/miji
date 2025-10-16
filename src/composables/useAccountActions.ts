import { ref } from 'vue';
import { Lg } from '@/utils/debugLog';
import { toast } from '@/utils/toast';
import type {
  Account,
  CreateAccountRequest,
  UpdateAccountRequest,
} from '@/schema/money';

export function useAccountActions() {
  const moneyStore = useMoneyStore();

  const showAccount = ref(false);
  const selectedAccount = ref<Account | null>(null);
  const accounts = ref<Account[]>([]);

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

  // 加载账户列表
  async function loadAccounts() {
    try {
      accounts.value = await moneyStore.getAllAccounts();
      return true;
    } catch (err) {
      Lg.e('loadAccounts', err);
      return false;
    }
  }

  return {
    // 状态
    showAccount,
    selectedAccount,
    accounts,

    // 方法
    showAccountModal,
    closeAccountModal,
    saveAccount,
    updateAccount,
    loadAccounts,
  };
}
