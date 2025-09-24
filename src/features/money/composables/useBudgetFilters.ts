import { SortDirection } from '@/schema/common';
import { Lg } from '@/utils/debugLog';
import type { PageQuery } from '@/schema/common';
import type { Budget } from '@/schema/money';
import type { PagedResult } from '@/services/money/baseManager';
import type { BudgetFilters } from '@/services/money/budgets';

export interface UIFilters {
  isActive: '' | 'active' | 'inactive';
  category: string | null;
  accountSerialNum: string;
  name: string;
  amount?: number;
  repeatPeriod: string;
  startDate: { start?: string; end?: string };
  endDate: { start?: string; end?: string };
  usedAmount?: number;
  alertThreshold: string;
  alertEnabled?: boolean;
}

const initialFilters: UIFilters = {
  isActive: '',
  category: null,
  accountSerialNum: '',
  name: '',
  amount: undefined,
  repeatPeriod: '',
  startDate: { start: undefined, end: undefined },
  endDate: { start: undefined, end: undefined },
  usedAmount: undefined,
  alertThreshold: '',
  alertEnabled: undefined,
};

export function mapUIFiltersToAPIFilters(ui: UIFilters): BudgetFilters {
  return {
    category: ui.category || undefined,
    accountSerialNum: ui.accountSerialNum || undefined,
    name: ui.name || undefined,
    amount: ui.amount || undefined,
    repeatPeriod: ui.repeatPeriod || undefined,
    startDate: ui.startDate?.start || ui.startDate?.end ? { ...ui.startDate } : undefined,
    endDate: ui.endDate?.start || ui.endDate?.end ? { ...ui.endDate } : undefined,
    usedAmount: ui.usedAmount || undefined,
    alertThreshold: ui.alertThreshold || undefined,
    alertEnabled: ui.alertEnabled,
    isActive: ui.isActive === 'active' ? true : ui.isActive === 'inactive' ? false : undefined,
  };
}

export function useBudgetFilters(budgets: () => PagedResult<Budget>, defaultPageSize = 4) {
  const filters = ref<UIFilters>({ ...initialFilters });
  const loading = ref(false);
  const moneyStore = useMoneyStore();
  const { sortOptions } = useSort({
    sortBy: undefined,
    sortDir: SortDirection.Desc,
    desc: true,
    customOrderBy: undefined,
  });

  const pagination = usePaginationFilters<Budget>(() => budgets(), defaultPageSize);
  // 加载交易数据
  async function loadBudgets() {
    loading.value = true;
    try {
      const params: PageQuery<BudgetFilters> = {
        currentPage: pagination.currentPage.value,
        pageSize: pagination.pageSize.value,
        sortOptions: sortOptions.value,
        filter: mapUIFiltersToAPIFilters(filters.value),
      };
      await moneyStore.getPagedBudgets(params);
    } catch (error) {
      Lg.e('Transaction', error);
    } finally {
      loading.value = false;
    }
  }

  function resetFilters() {
    filters.value = structuredClone(initialFilters);
    pagination.currentPage.value = 1;
  }

  return {
    filters,
    loading,
    pagination,
    loadBudgets,
    mapUIFiltersToAPIFilters,
    resetFilters,
  };
}
