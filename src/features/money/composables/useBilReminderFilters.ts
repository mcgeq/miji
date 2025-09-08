import { usePagination } from '@/composables/usePagination';
import type { BilReminder, BilReminderFilters } from '@/schema/money';

type ExtendedBilReminderFilters = BilReminderFilters & {
  status?: 'paid' | 'overdue' | 'pending' | '';
  dateRange?: 'today' | 'week' | 'month' | 'overdue' | '';
  period?: string;
};

export function useBilReminderFilters(
  bilReminders: () => BilReminder[],
  defaultPageSize = 4,
) {
  const filters = ref<ExtendedBilReminderFilters>({
    status: '',
    period: '',
    category: undefined,
    dateRange: '',
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
          remindDate.getMonth() === now.getMonth() &&
          remindDate.getFullYear() === now.getFullYear()
        );
      case 'overdue':
        return !reminder.isPaid && remindDate < now;
      default:
        return true;
    }
  }

  const filteredReminders = computed(() => {
    let result = [...bilReminders()];

    // UI层：status
    if (filters.value.status) {
      result = result.filter(r => getStatusClass(r) === filters.value.status);
    }

    // schema字段：repeatPeriod
    if (filters.value.period) {
      result = result.filter(r => r.repeatPeriod.type === filters.value.period);
    }

    // schema字段：category
    if (filters.value.category) {
      result = result.filter(r => r.category === filters.value.category);
    }

    // UI层：dateRange
    if (filters.value.dateRange) {
      result = result.filter(r => isInDateRange(r, filters.value.dateRange!));
    }

    return result;
  });

  const uniqueCategories = computed(() => {
    const categories = bilReminders().map(r => r.category);
    return [...new Set(categories)].filter(Boolean);
  });

  const pagination = usePagination<BilReminder>(
    () => filteredReminders.value,
    defaultPageSize,
  );

  function resetFilters() {
    filters.value = {
      status: '',
      period: '',
      category: undefined,
      dateRange: '',
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
    resetFilters,
    uniqueCategories,
    filteredReminders,
    pagination,
    getStatusClass,
    isOverdue,
  };
}
