import { FilterBtnSchema, SortDirection } from '@/schema/common';
import { Lg } from '@/utils/debugLog';
import type { DateRange, FilterBtn, PageQuery } from '@/schema/common';
import type { Todo } from '@/schema/todos';
import type { PagedMapResult } from '@/services/money/baseManager';
import type { TodoFilters } from '@/services/todo';

type UiTodoFilters = TodoFilters & {
  dateRange?: DateRange;
};

export function useTodosFilters(todos: () => PagedMapResult<Todo>, defaultPageSize = 4) {
  const { sortOptions } = useSort({
    sortBy: undefined,
    sortDir: SortDirection.Desc,
    desc: true,
    customOrderBy: undefined,
  });

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

  const loading = ref(false);
  const moneyStore = useTodoStore();
  const filters = ref<UiTodoFilters>({
    dateRange: undefined,
  });
  const filterBtn = ref<FilterBtn>(FilterBtnSchema.enum.TODAY);
  const showBtn = computed(() => filterBtn.value !== FilterBtnSchema.enum.YESTERDAY);

  const pagination = usePaginationFilters<Todo>(() => todos(), defaultPageSize);
  async function loadTodos() {
    loading.value = true;
    try {
      const params: PageQuery<TodoFilters> = {
        currentPage: pagination.currentPage.value,
        pageSize: pagination.pageSize.value,
        sortOptions: sortOptions.value,
        filter: filters.value,
      };
      await moneyStore.listPagedTodos(params);
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
