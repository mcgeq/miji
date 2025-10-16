import { ref } from 'vue';
import { Lg } from '@/utils/debugLog';
import type { Transaction } from '@/schema/money';

export type TabType = 'accounts' | 'transactions' | 'budgets' | 'reminders';

export function useTabManager() {
  const moneyStore = useMoneyStore();

  const activeTab = ref<TabType>('accounts');
  const transactions = ref<Transaction[]>([]);

  // 加载交易列表
  async function loadTransactions() {
    try {
      const allTransactions = await moneyStore.getAllTransactions();
      transactions.value = allTransactions.slice(0, 10);
      return true;
    } catch (err) {
      Lg.e('loadTransactions', err);
      return false;
    }
  }

  // 切换标签页
  function switchTab(
    tab: TabType,
    loadFunctions: {
      loadAccounts: () => Promise<boolean>;
      loadTransactions: () => Promise<boolean>;
      loadBudgets: () => Promise<boolean>;
      loadReminders: () => Promise<boolean>;
    },
  ) {
    activeTab.value = tab;
    switch (tab) {
      case 'accounts':
        loadFunctions.loadAccounts();
        break;
      case 'transactions':
        loadFunctions.loadTransactions();
        break;
      case 'budgets':
        loadFunctions.loadBudgets();
        break;
      case 'reminders':
        loadFunctions.loadReminders();
        break;
    }
  }

  return {
    // 状态
    activeTab,
    transactions,

    // 方法
    loadTransactions,
    switchTab,
  };
}
