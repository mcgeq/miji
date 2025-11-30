import { usePagination } from '@/composables/usePagination';
import type { Account } from '@/schema/money';
import type { AccountFilters } from '@/services/money/accounts';

type UiAccountFilters = AccountFilters & {
  status?: 'all' | 'active' | 'inactive';
  sortBy: 'updatedAt' | 'createdAt' | 'name' | 'balance' | 'type';
  sortOrder: 'asc' | 'desc';
};

export function useAccountFilters(accounts: () => Account[], defaultPageSize = 4) {
  const filters = ref<UiAccountFilters>({
    status: 'all',
    sortBy: 'updatedAt',
    sortOrder: 'desc',
    type: '',
    currency: '',
  });

  const allAccounts = computed(() => [...accounts()]);
  // 获取所有账户类型（排除虚账户）
  const accountTypes = computed(() => {
    const types = new Set(
      allAccounts.value.filter(account => !account.isVirtual).map(account => account.type),
    );
    return Array.from(types);
  });

  // 获取所有币种（排除虚账户）
  const currencies = computed(() => {
    const currencies = new Set(
      allAccounts.value
        .filter(account => !account.isVirtual)
        .map(account => account.currency?.code)
        .filter(Boolean),
    );
    return Array.from(currencies);
  });
  // 计算统计数据（排除虚账户）
  const activeAccounts = computed(
    () => allAccounts.value.filter(account => account.isActive && !account.isVirtual).length,
  );
  const inactiveAccounts = computed(
    () => allAccounts.value.filter(account => !account.isActive && !account.isVirtual).length,
  );

  // 过滤后的账户
  const filteredAccounts = computed(() => {
    let filtered = allAccounts.value;

    // 首先排除虚账户
    filtered = filtered.filter(account => !account.isVirtual);

    // 状态过滤
    if (filters.value.status === 'active') {
      filtered = filtered.filter(account => account.isActive);
    } else if (filters.value.status === 'inactive') {
      filtered = filtered.filter(account => !account.isActive);
    }

    // 类型过滤
    if (filters.value.type) {
      filtered = filtered.filter(account => account.type === filters.value.type);
    }

    // 币种过滤
    if (filters.value.currency) {
      filtered = filtered.filter(account => account.currency?.code === filters.value.currency);
    }

    // 排序
    return [...filtered].sort((a, b) => {
      let aValue, bValue;

      switch (filters.value.sortBy) {
        case 'name':
          aValue = a.name.toLowerCase();
          bValue = b.name.toLowerCase();
          break;
        case 'balance':
          aValue = Number.parseFloat(a.balance);
          bValue = Number.parseFloat(b.balance);
          break;
        case 'type':
          aValue = a.type;
          bValue = b.type;
          break;
        case 'updatedAt':
        default:
          if (a.updatedAt && b.updatedAt) {
            aValue = new Date(a.updatedAt).getTime();
            bValue = new Date(b.updatedAt).getTime();
          } else {
            aValue = new Date(a.createdAt).getTime();
            bValue = new Date(b.createdAt).getTime();
          }
          break;
      }

      if (aValue < bValue) return filters.value.sortOrder === 'asc' ? -1 : 1;
      if (aValue > bValue) return filters.value.sortOrder === 'asc' ? 1 : -1;
      return 0;
    });
  });
  // 过滤器方法
  const setActiveFilter = (status: 'all' | 'active' | 'inactive') => {
    filters.value.status = status;
  };

  const toggleSortOrder = () => {
    filters.value.sortOrder = filters.value.sortOrder === 'asc' ? 'desc' : 'asc';
  };

  const pagination = usePagination<Account>(() => filteredAccounts.value, defaultPageSize);

  function resetFilters() {
    filters.value = {
      status: 'all',
      sortBy: 'updatedAt',
      sortOrder: 'desc',
      type: '',
      currency: '',
    };
    pagination.setPage(1);
  }

  watch(
    filters,
    () => {
      pagination.setPage(1);
    },
    { deep: true },
  );

  return {
    filters,
    accountTypes,
    currencies,
    pagination,
    activeAccounts,
    inactiveAccounts,
    resetFilters,
    setActiveFilter,
    toggleSortOrder,
  };
}
