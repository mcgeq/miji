import { ref } from 'vue';
import { SortDirection } from '@/schema/common';
import { useTransactionStore } from '@/stores/money';
import { Lg } from '@/utils/debugLog';
import type { PageQuery } from '@/schema/common';
import type { Transaction } from '@/schema/money';
import type { TransactionFilters } from '@/services/money/transactions';

export type TabType = 'accounts' | 'transactions' | 'budgets' | 'reminders';

export function useTabManager() {
  const transactionStore = useTransactionStore();

  const activeTab = ref<TabType>('accounts');
  const transactions = ref<Transaction[]>([]);

  // 加载交易列表
  async function loadTransactions() {
    try {
      const params: PageQuery<TransactionFilters> = {
        currentPage: 1,
        pageSize: 10,
        sortOptions: {
          sortBy: 'updated_at',
          sortDir: SortDirection.Desc,
          desc: true,
        },
        filter: {
          isDeleted: false,
        },
      };
      await transactionStore.fetchTransactionsPaged(params);
      transactions.value = transactionStore.transactionsPaged.rows;
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
