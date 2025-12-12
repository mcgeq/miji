import { usePaginationMapFilters } from '@/composables/usePaginationFilters';
import { useSort } from '@/composables/useSortable';
import type { FilterBtn, PageQuery } from '@/schema/common';
import { FilterBtnSchema, SortDirection, StatusSchema } from '@/schema/common';
import type { Todo } from '@/schema/todos';
import type { PagedMapResult } from '@/services/money/baseManager';
import type { TodoFilters } from '@/services/todo';
import { DateUtils } from '@/utils/date';
import { Lg } from '@/utils/debugLog';

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
  const filters = ref<TodoFilters>({
    dateRange: DateUtils.getCurrentDateRange(),
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
      dateRange: DateUtils.getCurrentDateRange(),
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
      // TODAY逻辑：1. 查询截至dateRange.end的所有未完成待办任务
      // 2. 查询dateRange期间内的所有待办任务
      filters.value.dateRange = DateUtils.getCurrentDateRange();
      // 不设置status，这样会查询所有状态的待办任务
      // 使用默认排序，不设置自定义排序
      sortOptions.value.customOrderBy = undefined;
    } else if (filterBtn.value === FilterBtnSchema.enum.TOMORROW) {
      filters.value.dateRange = {
        start: DateUtils.getStartOfTodayISOWithOffset({ days: 1 }),
      };
      // 重置排序为默认
      sortOptions.value.customOrderBy = undefined;
    } else if (filterBtn.value === FilterBtnSchema.enum.YESTERDAY) {
      filters.value.status = StatusSchema.enum.Completed;
      filters.value.dateRange = {
        end: DateUtils.getEndOfTodayISOWithOffset({ days: -2 }),
      };
      // 重置排序为默认
      sortOptions.value.customOrderBy = undefined;
    } else {
      filters.value.dateRange = undefined;
      // 重置排序为默认
      sortOptions.value.customOrderBy = undefined;
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
