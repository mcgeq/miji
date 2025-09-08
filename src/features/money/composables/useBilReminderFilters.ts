import { usePagination } from '@/composables/usePagination';
import type { BilReminder, BilReminderFilters } from '@/schema/money';

const initialFilters: BilReminderFilters = {

};

export function useBilReminderFilters(bilReminders: () => BilReminder[], defaultPageSize: number = 4) {
  const filters = ref<BilReminderFilters>({ ...initialFilters });
  const filterdBilReminders = computed(() => {
    const result = [...bilReminders()] as BilReminder[];
    return result;
  });

  const pagination = usePagination<BilReminder>(
    () => filterdBilReminders.value,
    defaultPageSize,
  );

  return {
    pagination,
    filterdBilReminders,
  };
}
