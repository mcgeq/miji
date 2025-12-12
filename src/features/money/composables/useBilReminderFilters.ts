import type { PageQuery } from '@/schema/common';
import { SortDirection } from '@/schema/common';
import type { BilReminder, BilReminderFilters } from '@/schema/money';
import type { PagedResult } from '@/services/money/baseManager';
import { useReminderStore } from '@/stores/money';
import { Lg } from '@/utils/debugLog';

type ExtendedBilReminderFilters = BilReminderFilters & {
  status?: 'paid' | 'overdue' | 'pending' | '';
  dateRange?: 'today' | 'week' | 'month' | 'overdue' | '';
};

export function useBilReminderFilters(
  bilReminders: () => PagedResult<BilReminder>,
  defaultPageSize = 4,
) {
  const loading = ref(false);
  const reminderStore = useReminderStore();
  const filters = ref<ExtendedBilReminderFilters>({
    status: '',
    repeatPeriodType: undefined,
    category: undefined,
    dateRange: '',
    description: null,
    currency: null,
    relatedTransactionSerialNum: null,
  });

  const { sortOptions } = useSort({
    sortBy: undefined,
    sortDir: SortDirection.Desc,
    desc: true,
    customOrderBy: undefined,
  });

  function isOverdue(reminder: BilReminder) {
    return !reminder.isPaid && new Date(reminder.remindDate) < new Date();
  }

  function getStatusClass(reminder: BilReminder) {
    if (reminder.isPaid) return 'paid';
    if (isOverdue(reminder)) return 'overdue';
    return 'pending';
  }

  function isInDateRange(reminder: BilReminder, range: string): boolean {
    const now = new Date();
    const remindDate = new Date(reminder.remindDate);

    switch (range) {
      case 'today':
        return remindDate.toDateString() === now.toDateString();
      case 'week': {
        const weekStart = new Date(now);
        weekStart.setDate(now.getDate() - now.getDay());
        const weekEnd = new Date(weekStart);
        weekEnd.setDate(weekStart.getDate() + 6);
        return remindDate >= weekStart && remindDate <= weekEnd;
      }
      case 'month':
        return (
          remindDate.getMonth() === now.getMonth() && remindDate.getFullYear() === now.getFullYear()
        );
      case 'overdue':
        return !reminder.isPaid && remindDate < now;
      default:
        return true;
    }
  }

  const filteredReminders = computed(() => {
    let result = [...bilReminders().rows];

    // UI层：status
    if (filters.value.status) {
      result = result.filter(r => getStatusClass(r) === filters.value.status);
    }

    // schema字段：repeatPeriod
    if (filters.value.repeatPeriodType) {
      result = result.filter(r => r.repeatPeriodType === filters.value.repeatPeriodType);
    }

    // schema字段：category
    if (filters.value.category) {
      result = result.filter(r => r.category === filters.value.category);
    }

    // UI层：dateRange
    if (filters.value.dateRange) {
      const dateRange = filters.value.dateRange;
      result = result.filter(r => isInDateRange(r, dateRange));
    }

    return result;
  });

  const uniqueCategories = computed(() => {
    const categories = bilReminders().rows.map(r => r.category);
    return [...new Set(categories)].filter(Boolean);
  });

  const pagination = usePaginationFilters<BilReminder>(() => bilReminders(), defaultPageSize);
  async function loadReminders() {
    loading.value = true;
    try {
      const params: PageQuery<BilReminderFilters> = {
        currentPage: pagination.currentPage.value,
        pageSize: pagination.pageSize.value,
        sortOptions: sortOptions.value,
        filter: filters.value,
      };
      await reminderStore.fetchRemindersPaged(params);
    } catch (error) {
      Lg.e('BilReminder', error);
    } finally {
      loading.value = false;
    }
  }
  watch(pagination.currentPage, async () => {
    await loadReminders();
  });

  watch(pagination.pageSize, async () => {
    await loadReminders();
  });

  watch(
    filters,
    async () => {
      pagination.currentPage.value = 1;
      await loadReminders();
    },
    { deep: true },
  );

  function resetFilters() {
    filters.value = {
      status: '',
      repeatPeriodType: undefined,
      category: undefined,
      dateRange: '',
    };
  }

  return {
    loading,
    filters,
    resetFilters,
    uniqueCategories,
    filteredReminders,
    pagination,
    getStatusClass,
    isOverdue,
    loadReminders,
  };
}
