import { usePaginationMapFilters } from '@/composables/usePaginationFilters';
import { useSort } from '@/composables/useSortable';
import { FilterBtnSchema, SortDirection, StatusSchema } from '@/schema/common';
import { DateUtils } from '@/utils/date';
import { Lg } from '@/utils/debugLog';
import type { DateRange, FilterBtn, PageQuery } from '@/schema/common';
import type { Todo } from '@/schema/todos';
import type { PagedMapResult } from '@/services/money/baseManager';
import type { TodoFilters } from '@/services/todo';

type UiTodoFilters = TodoFilters & {
  dateRange?: DateRange;
};

export function useTodosFilters(todos: () => PagedMapResult<Todo>, defaultPageSize = 5) {
  const { sortOptions } = useSort({
    sortBy: undefined,
    sortDir: SortDirection.Desc,
    desc: true,
    customOrderBy: undefined,
  });

  const loading = ref(false);
  const { t } = useI18n();
  const filterButtons = [
    {
      label: t('todos.quickFilter.yesterday'),
      value: FilterBtnSchema.enum.YESTERDAY,
    },
    { label: t('todos.quickFilter.today'), value: FilterBtnSchema.enum.TODAY },
    {
      label: t('todos.quickFilter.tomorrow'),
      value: FilterBtnSchema.enum.TOMORROW,
    },
  ] as const;

  const todoStore = useTodoStore();
  const filters = ref<UiTodoFilters>({
    dateRange: undefined,
  });
  const filterBtn = ref<FilterBtn>(FilterBtnSchema.enum.TODAY);
  const showBtn = computed(() => filterBtn.value !== FilterBtnSchema.enum.YESTERDAY);

  const pagination = usePaginationMapFilters<Todo>(() => todos(), defaultPageSize);

  async function loadTodos() {
    loading.value = true;
    try {
      const params: PageQuery<TodoFilters> = {
        currentPage: pagination.currentPage.value,
        pageSize: pagination.pageSize.value,
        sortOptions: sortOptions.value,
        filter: filters.value,
      };
      await todoStore.listPagedTodos(params);
    } catch (error) {
      Lg.e('Todos', error);
    } finally {
      loading.value = false;
    }
  }

  function resetFilters() {
    filters.value = {
      dateRange: undefined,
    };
  }

  watch(pagination.currentPage, async () => {
    await loadTodos();
  });

  watch(pagination.pageSize, async () => {
    await loadTodos();
  });

  watch(filterBtn, async () => {
    resetFilters();
    if (filterBtn.value === FilterBtnSchema.enum.TODAY) {
      filters.value.dateRange = {
        start: DateUtils.getStartOfTodayISOWithOffset({ days: -2 }),
        end: DateUtils.getEndOfTodayISOWithOffset(),
      };
    } else if (filterBtn.value === FilterBtnSchema.enum.TOMORROW) {
      filters.value.dateRange = {
        start: DateUtils.getStartOfTodayISOWithOffset({ days: 1 }),
      };
    } else if (filterBtn.value === FilterBtnSchema.enum.YESTERDAY) {
      filters.value.status = StatusSchema.enum.Completed;
      filters.value.dateRange = {
        end: DateUtils.getEndOfTodayISOWithOffset({ days: -2 }),
      };
    } else {
      filters.value.dateRange = undefined;
    }
  });

  watch(
    filters,
    async () => {
      await loadTodos();
    },
    { deep: true },
  );

  return {
    loading,
    filters,
    filterBtn,
    filterButtons,
    pagination,
    showBtn,
    resetFilters,
    loadTodos,
  };
}
