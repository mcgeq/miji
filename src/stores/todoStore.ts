// src/stores/todoStore.ts
import { defineStore } from 'pinia';
import { computed, ref } from 'vue';
import type { AppError } from '@/errors/appError';
import type { DateRange, PageQuery, Status } from '@/schema/common';
import { SortDirection, StatusSchema } from '@/schema/common';
import type { Todo, TodoCreate, TodoUpdate } from '@/schema/todos';
import type { PagedMapResult, PagedResult } from '@/services/money/baseManager';
import type { TodoFilters } from '@/services/todo';
import { todoService } from '@/services/todoService';
import { withLoadingSafe } from '@/stores/utils/withLoadingSafe';
import { DateUtils } from '@/utils/date';
import { Lg } from '@/utils/debugLog';
import { wrapError } from '@/utils/errorHandler';

// ==================== Store Constants ====================
const STORE_MODULE = 'TodoStore';
const priorityOrder: Record<Todo['priority'], number> = {
  Urgent: 4,
  High: 3,
  Medium: 2,
  Low: 1,
};

export function compareTodos(a: Todo, b: Todo): number {
  // 1. pinned 在最前
  if (a.isPinned && !b.isPinned) return -1;
  if (!a.isPinned && b.isPinned) return 1;

  // 2. 未完成在前
  if (a.status === StatusSchema.enum.Completed && b.status !== StatusSchema.enum.Completed)
    return 1;
  if (a.status !== StatusSchema.enum.Completed && b.status === StatusSchema.enum.Completed)
    return -1;

  // 3. 按优先级 (Urgent > High > Medium > Low)
  const priorityDiff = priorityOrder[b.priority] - priorityOrder[a.priority];
  if (priorityDiff !== 0) return priorityDiff;

  // 4. 按 dueAt 先到期在前
  if (a.dueAt && b.dueAt) {
    const dueDiff = new Date(a.dueAt).getTime() - new Date(b.dueAt).getTime();
    if (dueDiff !== 0) return dueDiff;
  }

  // 5. 更新时间倒序
  const dateA = new Date(a.updatedAt ?? a.createdAt).getTime();
  const dateB = new Date(b.updatedAt ?? b.createdAt).getTime();
  return dateB - dateA;
}

// ==================== Helper Functions ====================

/**
 * 创建初始状态（用于不可变更新）
 */
function createInitialState() {
  return {
    todosPaged: { rows: new Map(), totalPages: 0, currentPage: 1, totalCount: 0, pageSize: 10 },
    loading: false,
    lastFetched: null,
    cacheExpiry: 8 * 60 * 60 * 1000,
    error: null,
    filters: {},
    sortBy: 'dueAt',
    sortDir: SortDirection.Asc,
  };
}

/**
 * 从 Map 获取待办数组（带缓存优化）
 * 使用 WeakMap 缓存转换结果，避免重复转换
 */
const todoArrayCache = new WeakMap<Map<string, Todo>, Todo[]>();

function getTodosFromMap(rows: Map<string, Todo>): Todo[] {
  // 检查缓存
  const cached = todoArrayCache.get(rows);
  if (cached) {
    return cached;
  }

  // 转换并缓存
  const result = Array.from(rows.values());
  todoArrayCache.set(rows, result);
  return result;
}

export const useTodoStore = defineStore('todos', () => {
  // ============ 状态 ============
  const todosPaged = ref<PagedMapResult<Todo>>({
    rows: new Map(),
    totalPages: 0,
    currentPage: 1,
    totalCount: 0,
    pageSize: 10,
  });
  const isLoading = ref(false);
  const lastFetched = ref<Date | null>(null);
  const cacheExpiry = ref(8 * 60 * 60 * 1000);
  const error = ref<AppError | null>(null);
  const filters = ref<TodoFilters>({});
  const sortBy = ref<string | null>('dueAt');
  const sortDir = ref<SortDirection>(SortDirection.Asc);
  // 保存最后使用的查询参数，用于刷新列表
  const lastQuery = ref<PageQuery<TodoFilters> | null>(null);

  // ============ 计算属性 ============
  /**
   * 所有待办的数组（从 Map 转换）
   */
  const todoList = computed((): Todo[] => {
    return getTodosFromMap(todosPaged.value.rows);
  });

  /**
   * 筛选后的待办列表
   */
  const filteredTodos = computed((): Todo[] => {
    const todos = getTodosFromMap(todosPaged.value.rows);
    const { status, dateRange, parentId } = filters.value;

    // 无筛选条件时直接返回
    if (!(status || dateRange) && parentId === undefined) {
      return todos;
    }

    // 预计算日期范围边界
    const startDate = dateRange?.start ? new Date(dateRange.start) : null;
    const endDate = dateRange?.end ? new Date(dateRange.end) : null;

    return todos.filter(todo => {
      // 状态筛选
      if (status && todo.status !== status) return false;

      // 日期范围筛选
      if (startDate && endDate) {
        const dueDate = new Date(todo.dueAt);
        if (dueDate < startDate || dueDate > endDate) return false;
      }

      // 父任务筛选
      if (parentId !== undefined && todo.parentId !== parentId) return false;

      return true;
    });
  });

  /**
   * 逾期的待办
   */
  const overdueTodos = computed((): Todo[] => {
    const nowTime = Date.now();
    const todos = getTodosFromMap(todosPaged.value.rows);
    return todos.filter(todo => {
      if (todo.status === StatusSchema.enum.Completed) return false;
      return new Date(todo.dueAt).getTime() < nowTime;
    });
  });

  /**
   * 今日待办
   */
  const todayTodos = computed((): Todo[] => {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const todayTime = today.getTime();
    const tomorrowTime = todayTime + 24 * 60 * 60 * 1000;

    const todos = getTodosFromMap(todosPaged.value.rows);
    return todos.filter(todo => {
      if (todo.status === StatusSchema.enum.Completed) return false;
      const dueTime = new Date(todo.dueAt).getTime();
      return dueTime >= todayTime && dueTime < tomorrowTime;
    });
  });

  /**
   * 即将到期的待办（未来7天）
   */
  const upcomingTodos = computed((): Todo[] => {
    const nowTime = Date.now();
    const weekLaterTime = nowTime + 7 * 24 * 60 * 60 * 1000;

    const todos = getTodosFromMap(todosPaged.value.rows);
    return todos.filter(todo => {
      if (todo.status === StatusSchema.enum.Completed) return false;
      const dueTime = new Date(todo.dueAt).getTime();
      return dueTime >= nowTime && dueTime <= weekLaterTime;
    });
  });

  /**
   * 已完成的待办
   */
  const completedTodos = computed((): Todo[] => {
    const todos = getTodosFromMap(todosPaged.value.rows);
    return todos.filter(todo => todo.status === StatusSchema.enum.Completed);
  });

  /**
   * 置顶的待办
   */
  const pinnedTodos = computed((): Todo[] => {
    const todos = getTodosFromMap(todosPaged.value.rows);
    return todos.filter(todo => todo.isPinned && todo.status !== StatusSchema.enum.Completed);
  });

  /**
   * 获取用户友好的错误消息
   */
  const errorMessage = computed((): string | null => {
    return error.value?.getUserMessage() ?? null;
  });
  // ============ Actions ============

  /**
   * 清除错误状态
   */
  function clearError() {
    error.value = null;
  }

  /**
   * 刷新当前列表（使用最后的查询参数）
   */
  async function refreshCurrentList() {
    if (lastQuery.value) {
      await listPagedTodos(lastQuery.value);
    } else {
      // 如果没有保存的查询参数，使用默认参数
      await fetchdPagedTodos();
    }
  }

  /**
   * 获取分页待办列表（默认参数）
   */
  const fetchdPagedTodos = withLoadingSafe(
    async (
      query: PageQuery<TodoFilters> = {
        currentPage: 1,
        pageSize: 4,
        sortOptions: {
          desc: true,
          sortDir: SortDirection.Desc,
        },
        filter: {
          dateRange: DateUtils.getCurrentDateRange(),
        },
      },
    ) => {
      Lg.i(STORE_MODULE, '获取分页待办列表', { query });
      await listPagedTodos(query);
    },
    isLoading,
    error,
  );

  /**
   * 创建待办
   */
  const createTodo = withLoadingSafe(
    async (todo: TodoCreate): Promise<Todo> => {
      try {
        Lg.i(STORE_MODULE, '创建待办', { title: todo.title });
        const result = await todoService.create(todo);
        Lg.i(STORE_MODULE, '待办创建成功', { serialNum: result.serialNum });
        await refreshCurrentList();
        return result;
      } catch (err) {
        error.value = wrapError(STORE_MODULE, err, 'CREATE_FAILED', '创建待办失败');
        throw error.value;
      }
    },
    isLoading,
    error,
  );

  /**
   * 更新待办
   */
  const updateTodo = withLoadingSafe(
    async (serialNum: string, todo: TodoUpdate): Promise<Todo> => {
      try {
        Lg.i(STORE_MODULE, '更新待办', { serialNum, updates: Object.keys(todo) });
        const result = await todoService.update(serialNum, todo);
        Lg.i(STORE_MODULE, '待办更新成功', { serialNum });
        await refreshCurrentList();
        return result;
      } catch (err) {
        error.value = wrapError(STORE_MODULE, err, 'UPDATE_FAILED', '更新待办失败');
        throw error.value;
      }
    },
    isLoading,
    error,
  );

  /**
   * 切换待办状态
   */
  const toggleTodo = withLoadingSafe(
    async (serialNum: string, status: Status): Promise<Todo> => {
      try {
        Lg.i(STORE_MODULE, '切换待办状态', { serialNum, status });
        const result = await todoService.toggle(serialNum, status);
        Lg.i(STORE_MODULE, '待办状态切换成功', { serialNum, newStatus: status });
        await refreshCurrentList();
        return result;
      } catch (err) {
        error.value = wrapError(STORE_MODULE, err, 'TOGGLE_FAILED', '切换待办状态失败');
        throw error.value;
      }
    },
    isLoading,
    error,
  );

  /**
   * 删除待办
   */
  const deleteTodo = withLoadingSafe(
    async (serialNum: string): Promise<void> => {
      try {
        Lg.i(STORE_MODULE, '删除待办', { serialNum });
        await todoService.delete(serialNum);
        Lg.i(STORE_MODULE, '待办删除成功', { serialNum });
        await refreshCurrentList();
      } catch (err) {
        error.value = wrapError(STORE_MODULE, err, 'DELETE_FAILED', '删除待办失败');
        throw error.value;
      }
    },
    isLoading,
    error,
  );

  /**
   * 获取分页待办列表
   */
  const listPagedTodos = withLoadingSafe(
    async (query: PageQuery<TodoFilters>): Promise<PagedResult<Todo>> => {
      try {
        Lg.i(STORE_MODULE, '查询分页待办', { page: query.currentPage, pageSize: query.pageSize });

        // 保存查询参数，用于后续刷新
        lastQuery.value = query;

        const result = await todoService.listPagedWithFilters(query);
        result.items.sort(compareTodos);

        // 不可变更新：创建新的 Map 和对象
        const rowMap = new Map(result.items.map(item => [item.serialNum, item]));
        todosPaged.value = {
          rows: rowMap,
          totalCount: result.total,
          currentPage: result.page,
          pageSize: result.pageSize,
          totalPages: result.totalPages,
        };

        // 更新最后获取时间
        lastFetched.value = new Date();

        Lg.i(STORE_MODULE, '待办列表获取成功', {
          totalCount: result.total,
          currentPage: result.page,
        });

        // Return in the old format for compatibility
        return {
          rows: result.items,
          totalCount: result.total,
          currentPage: result.page,
          pageSize: result.pageSize,
          totalPages: result.totalPages,
        };
      } catch (err) {
        error.value = wrapError(STORE_MODULE, err, 'LIST_FAILED', '获取待办列表失败');
        throw error.value;
      }
    },
    isLoading,
    error,
  );

  /**
   * 获取子任务列表
   */
  const listSubtasks = withLoadingSafe(
    async (parentId: string): Promise<Todo[]> => {
      try {
        Lg.i(STORE_MODULE, '获取子任务列表', { parentId });
        const result = await todoService.listSubtasks(parentId);
        Lg.i(STORE_MODULE, '子任务列表获取成功', { parentId, count: result.length });
        return result;
      } catch (err) {
        error.value = wrapError(STORE_MODULE, err, 'SUBTASK_LIST_FAILED', '获取子任务失败');
        throw error.value;
      }
    },
    isLoading,
    error,
  );

  /**
   * 创建子任务
   */
  const createSubtask = withLoadingSafe(
    async (parentId: string, todo: TodoCreate): Promise<Todo> => {
      try {
        Lg.i(STORE_MODULE, '创建子任务', { parentId, title: todo.title });
        const result = await todoService.createSubtask(parentId, todo);
        Lg.i(STORE_MODULE, '子任务创建成功', { parentId, serialNum: result.serialNum });
        await refreshCurrentList();
        return result;
      } catch (err) {
        error.value = wrapError(STORE_MODULE, err, 'SUBTASK_CREATE_FAILED', '创建子任务失败');
        throw error.value;
      }
    },
    isLoading,
    error,
  );

  /**
   * 设置筛选器
   */
  function setFilter(newFilters: Partial<TodoFilters>) {
    Lg.d(STORE_MODULE, '设置筛选器', { filters: newFilters });
    filters.value = { ...filters.value, ...newFilters };
  }

  /**
   * 清除所有筛选器
   */
  function clearFilter() {
    Lg.d(STORE_MODULE, '清除筛选器');
    filters.value = {};
  }

  /**
   * 设置状态筛选
   */
  function setStatusFilter(status: Status | null) {
    Lg.d(STORE_MODULE, '设置状态筛选', { status });
    if (status) {
      filters.value = { ...filters.value, status };
    } else {
      const { status: _, ...rest } = filters.value;
      filters.value = rest;
    }
  }

  /**
   * 设置日期范围筛选
   */
  function setDateRangeFilter(dateRange: DateRange | null) {
    Lg.d(STORE_MODULE, '设置日期范围筛选', { dateRange });
    if (dateRange) {
      filters.value = { ...filters.value, dateRange };
    } else {
      const { dateRange: _, ...rest } = filters.value;
      filters.value = rest;
    }
  }

  /**
   * 设置排序选项
   */
  function setSortOptions(newSortBy: string, newSortDir: SortDirection) {
    Lg.d(STORE_MODULE, '设置排序选项', { sortBy: newSortBy, sortDir: newSortDir });
    sortBy.value = newSortBy;
    sortDir.value = newSortDir;
  }

  /**
   * 重置排序为默认值
   */
  function clearSort() {
    Lg.d(STORE_MODULE, '重置排序');
    sortBy.value = 'dueAt';
    sortDir.value = SortDirection.Asc;
  }

  /**
   * 重置整个 store 状态
   */
  function $reset() {
    Lg.i(STORE_MODULE, '重置 store 状态');
    const initialState = createInitialState();
    todosPaged.value = initialState.todosPaged;
    isLoading.value = initialState.loading;
    lastFetched.value = initialState.lastFetched;
    cacheExpiry.value = initialState.cacheExpiry;
    error.value = initialState.error;
    filters.value = initialState.filters;
    sortBy.value = initialState.sortBy;
    sortDir.value = initialState.sortDir;
    lastQuery.value = null;
  }

  return {
    // 状态
    todosPaged,
    isLoading,
    lastFetched,
    cacheExpiry,
    error,
    filters,
    sortBy,
    sortDir,
    lastQuery,
    // 计算属性
    todoList,
    filteredTodos,
    overdueTodos,
    todayTodos,
    upcomingTodos,
    completedTodos,
    pinnedTodos,
    errorMessage,
    // Actions
    clearError,
    refreshCurrentList,
    fetchdPagedTodos,
    createTodo,
    updateTodo,
    toggleTodo,
    deleteTodo,
    listPagedTodos,
    listSubtasks,
    createSubtask,
    setFilter,
    clearFilter,
    setStatusFilter,
    setDateRangeFilter,
    setSortOptions,
    clearSort,
    $reset,
  };
});
