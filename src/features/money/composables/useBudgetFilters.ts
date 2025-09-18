import { usePagination } from '@/composables/usePagination';
import type { Budget } from '@/schema/money';
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

export function useBudgetFilters(budgets: () => Budget[], defaultPageSize = 4) {
  const filters = ref<UIFilters>({ ...initialFilters });

  const filteredBudgets = computed(() => {
    let result = [...budgets()] as Budget[];

    if (filters.value.isActive === 'active') result = result.filter(b => b.isActive);
    else if (filters.value.isActive === 'inactive') result = result.filter(b => !b.isActive);

    if (filters.value.repeatPeriod) {
      result = result.filter(b => b.repeatPeriod.type === filters.value.repeatPeriod);
    }
    if (filters.value.category) {
      result = result.filter(b => b.categoryScope.includes(filters.value.category ?? ''));
    }
    result = result.sort((a, b) => {
      if (a.isActive === b.isActive) return 0; // 相同时保持原有顺序
      return a.isActive ? -1 : 1; // true 排前面，false 排后面
    });
    return result;
  });

  const pagination = usePagination<Budget>(() => filteredBudgets.value, defaultPageSize);

  function resetFilters() {
    filters.value = structuredClone(initialFilters);
    pagination.currentPage.value = 1;
  }

  return {
    filters,
    resetFilters,
    filteredBudgets,
    pagination,
    mapUIFiltersToAPIFilters,
  };
}
