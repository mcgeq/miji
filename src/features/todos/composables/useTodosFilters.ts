import { SortDirection } from '@/schema/common';
import { Lg } from '@/utils/debugLog';
import type { PageQuery } from '@/schema/common';
import type { Todo } from '@/schema/todos';
import type { PagedResult } from '@/services/money/baseManager';
import type { TodoFilters } from '@/services/todo';

type UiTodoFilters = TodoFilters & {
  status?: 'paid' | 'overdue' | 'pending' | '';
  dateRange?: 'today' | 'week' | 'month' | 'overdue' | '';
};

export function useTodosFilters(todos: () => PagedResult<Todo>, defaultPageSize = 4) {
  const loading = ref(false);
  const moneyStore = useTodoStore();
  const filters = ref<UiTodoFilters>({
    status: '',
    dateRange: '',
  });

  const { sortOptions } = useSort({
    sortBy: undefined,
    sortDir: SortDirection.Desc,
    desc: true,
    customOrderBy: undefined,
  });

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
      status: '',
    };
  }

  return {
    loading,
    filters,
    resetFilters,
    pagination,
    loadTodos,
  };
}
