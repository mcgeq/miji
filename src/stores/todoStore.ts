// src/stores/todoStore.ts
import { defineStore } from 'pinia';
import { AppError } from '@/errors/appError';
import { SortDirection, StatusSchema } from '@/schema/common';
import { TodoDb } from '@/services/todos';
import { DateUtils } from '@/utils/date';
import { Lg } from '@/utils/debugLog';
import { toast } from '@/utils/toast';
import type { DateRange, PageQuery, Status } from '@/schema/common';
import type { Todo, TodoCreate, TodoUpdate } from '@/schema/todos';
import type { PagedMapResult, PagedResult } from '@/services/money/baseManager';
import type { TodoFilters } from '@/services/todo';

// ==================== Store Constants ====================
const STORE_MODULE = 'TodoStore';

// ==================== Store State Interface ====================
interface TodoStoreState {
  /** 所有待办列表（旧版兼容） */
  todos: Todo[];
  /** 分页待办数据 */
  todosPaged: PagedMapResult<Todo>;
  /** 加载状态 */
  loading: boolean;
  /** 最后获取时间 */
  lastFetched: Date | null;
  /** 缓存过期时间（毫秒） */
  cacheExpiry: number;
  /** 错误信息 */
  error: AppError | null;
  /** 筛选器状态 */
  filters: TodoFilters;
  /** 排序字段 */
  sortBy: string | null;
  /** 排序方向 */
  sortDir: SortDirection;
}

/** TodoStore 错误代码 */
export enum TodoStoreErrorCode {
  TODO_NOT_FOUND = 'TODO_NOT_FOUND',
  CREATE_FAILED = 'CREATE_FAILED',
  UPDATE_FAILED = 'UPDATE_FAILED',
  DELETE_FAILED = 'DELETE_FAILED',
  TOGGLE_FAILED = 'TOGGLE_FAILED',
  LIST_FAILED = 'LIST_FAILED',
  SUBTASK_CREATE_FAILED = 'SUBTASK_CREATE_FAILED',
  SUBTASK_LIST_FAILED = 'SUBTASK_LIST_FAILED',
  DATABASE_OPERATION_FAILED = 'DATABASE_OPERATION_FAILED',
}
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
function createInitialState(): TodoStoreState {
  return {
    todos: [],
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
 * 从 Map 获取待办数组（缓存优化）
 */
function getTodosFromMap(rows: Map<string, Todo>): Todo[] {
  return Array.from(rows.values());
}

export const useTodoStore = defineStore('todos', {
  state: (): TodoStoreState => createInitialState(),

  getters: {
    /**
     * 所有待办的数组（从 Map 转换）
     * 使用 getter 缓存避免重复转换
     */
    todoList: (state): Todo[] => {
      return getTodosFromMap(state.todosPaged.rows);
    },

    /**
     * 筛选后的待办列表
     * 优化：使用单次遍历进行多条件筛选
     */
    filteredTodos: (state): Todo[] => {
      const todos = getTodosFromMap(state.todosPaged.rows);
      const { status, dateRange, parentId } = state.filters;

      // 无筛选条件时直接返回
      if (!status && !dateRange && parentId === undefined) {
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
    },

    /**
     * 逾期的待办
     * 优化：预计算当前时间，避免在循环中重复创建 Date 对象
     */
    overdueTodos: (state): Todo[] => {
      const nowTime = Date.now();
      const todos = getTodosFromMap(state.todosPaged.rows);
      return todos.filter(todo => {
        if (todo.status === StatusSchema.enum.Completed) return false;
        return new Date(todo.dueAt).getTime() < nowTime;
      });
    },

    /**
     * 今日待办
     * 优化：预计算时间边界
     */
    todayTodos: (state): Todo[] => {
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      const todayTime = today.getTime();
      const tomorrowTime = todayTime + 24 * 60 * 60 * 1000;

      const todos = getTodosFromMap(state.todosPaged.rows);
      return todos.filter(todo => {
        if (todo.status === StatusSchema.enum.Completed) return false;
        const dueTime = new Date(todo.dueAt).getTime();
        return dueTime >= todayTime && dueTime < tomorrowTime;
      });
    },

    /**
     * 即将到期的待办（未来7天）
     * 优化：预计算时间边界
     */
    upcomingTodos: (state): Todo[] => {
      const nowTime = Date.now();
      const weekLaterTime = nowTime + 7 * 24 * 60 * 60 * 1000;

      const todos = getTodosFromMap(state.todosPaged.rows);
      return todos.filter(todo => {
        if (todo.status === StatusSchema.enum.Completed) return false;
        const dueTime = new Date(todo.dueAt).getTime();
        return dueTime >= nowTime && dueTime <= weekLaterTime;
      });
    },

    /**
     * 已完成的待办
     */
    completedTodos: (state): Todo[] => {
      const todos = getTodosFromMap(state.todosPaged.rows);
      return todos.filter(todo => todo.status === StatusSchema.enum.Completed);
    },

    /**
     * 置顶的待办
     */
    pinnedTodos: (state): Todo[] => {
      const todos = getTodosFromMap(state.todosPaged.rows);
      return todos.filter(todo => todo.isPinned && todo.status !== StatusSchema.enum.Completed);
    },

    /**
     * 获取用户友好的错误消息
     */
    errorMessage: (state): string | null => {
      return state.error?.getUserMessage() ?? null;
    },
  },
  actions: {
    // ==================== 错误处理 ====================

    /**
     * 统一错误处理
     * @param err - 原始错误
     * @param code - 错误代码
     * @param message - 用户友好消息
     * @param showToast - 是否显示 toast 通知
     */
    handleError(
      err: unknown,
      code: TodoStoreErrorCode,
      message: string,
      showToast = true,
    ): AppError {
      const appError = AppError.wrap(STORE_MODULE, err, code, message);

      // 不可变更新错误状态
      this.error = appError;

      // 结构化日志
      appError.log();

      // Toast 反馈
      if (showToast) {
        toast.error(appError.getUserMessage());
      }

      return appError;
    },

    /**
     * 清除错误状态
     */
    clearError() {
      this.error = null;
    },

    /**
     * 带加载状态的操作包装器
     */
    async withLoading<T>(operation: () => Promise<T>): Promise<T> {
      this.loading = true;
      this.error = null;
      try {
        return await operation();
      } finally {
        this.loading = false;
      }
    },

    /**
     * 带加载状态和错误处理的操作包装器
     * @param operation - 异步操作
     * @param errorCode - 错误代码
     * @param errorMsg - 错误消息
     * @param showToast - 是否显示 toast
     */
    async withLoadingSafe<T>(
      operation: () => Promise<T>,
      errorCode: TodoStoreErrorCode,
      errorMsg: string,
      showToast = true,
    ): Promise<T> {
      this.loading = true;
      this.error = null;
      try {
        return await operation();
      } catch (err) {
        const appError = this.handleError(err, errorCode, errorMsg, showToast);
        throw appError;
      } finally {
        this.loading = false;
      }
    },

    // ==================== CRUD 操作 ====================

    /**
     * 获取分页待办列表（默认参数）
     */
    async fetchdPagedTodos(
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
    ) {
      Lg.i(STORE_MODULE, '获取分页待办列表', { query });
      return this.withLoadingSafe(
        async () => {
          await this.listPagedTodos(query);
        },
        TodoStoreErrorCode.LIST_FAILED,
        '获取待办列表失败',
      );
    },

    /**
     * 创建待办
     */
    async createTodo(todo: TodoCreate): Promise<Todo> {
      Lg.i(STORE_MODULE, '创建待办', { title: todo.title });
      return this.withLoadingSafe(
        async () => {
          const result = await TodoDb.createTodo(todo);
          Lg.i(STORE_MODULE, '待办创建成功', { serialNum: result.serialNum });
          await this.fetchdPagedTodos();
          return result;
        },
        TodoStoreErrorCode.CREATE_FAILED,
        '创建待办失败',
      );
    },

    /**
     * 更新待办
     */
    async updateTodo(serialNum: string, todo: TodoUpdate): Promise<Todo> {
      Lg.i(STORE_MODULE, '更新待办', { serialNum, updates: Object.keys(todo) });
      return this.withLoadingSafe(
        async () => {
          const result = await TodoDb.updateTodo(serialNum, todo);
          Lg.i(STORE_MODULE, '待办更新成功', { serialNum });
          await this.fetchdPagedTodos();
          return result;
        },
        TodoStoreErrorCode.UPDATE_FAILED,
        '更新待办失败',
      );
    },

    /**
     * 切换待办状态
     */
    async toggleTodo(serialNum: string, status: Status): Promise<Todo> {
      Lg.i(STORE_MODULE, '切换待办状态', { serialNum, status });
      return this.withLoadingSafe(
        async () => {
          const result = await TodoDb.toggleTodo(serialNum, status);
          Lg.i(STORE_MODULE, '待办状态切换成功', { serialNum, newStatus: status });
          await this.fetchdPagedTodos();
          return result;
        },
        TodoStoreErrorCode.TOGGLE_FAILED,
        '切换待办状态失败',
      );
    },

    /**
     * 删除待办
     */
    async deleteTodo(serialNum: string): Promise<void> {
      Lg.i(STORE_MODULE, '删除待办', { serialNum });
      return this.withLoadingSafe(
        async () => {
          await TodoDb.deleteTodo(serialNum);
          Lg.i(STORE_MODULE, '待办删除成功', { serialNum });
          await this.fetchdPagedTodos();
        },
        TodoStoreErrorCode.DELETE_FAILED,
        '删除待办失败',
      );
    },

    /**
     * 获取分页待办列表
     * 使用不可变更新模式
     */
    async listPagedTodos(query: PageQuery<TodoFilters>): Promise<PagedResult<Todo>> {
      Lg.i(STORE_MODULE, '查询分页待办', { page: query.currentPage, pageSize: query.pageSize });
      return this.withLoadingSafe(
        async () => {
          const result = await TodoDb.listTodosPaged(query);
          result.rows.sort(compareTodos);

          // 不可变更新：创建新的 Map 和对象
          const rowMap = new Map(result.rows.map(item => [item.serialNum, item]));
          this.todosPaged = {
            ...result,
            rows: rowMap,
          };

          // 更新最后获取时间
          this.lastFetched = new Date();

          Lg.i(STORE_MODULE, '待办列表获取成功', {
            totalCount: result.totalCount,
            currentPage: result.currentPage,
          });

          return result;
        },
        TodoStoreErrorCode.LIST_FAILED,
        '获取待办列表失败',
      );
    },

    // ==================== 子任务操作 ====================

    /**
     * 获取子任务列表
     */
    async listSubtasks(parentId: string): Promise<Todo[]> {
      Lg.i(STORE_MODULE, '获取子任务列表', { parentId });
      return this.withLoadingSafe(
        async () => {
          const result = await TodoDb.listSubtasks(parentId);
          Lg.i(STORE_MODULE, '子任务列表获取成功', { parentId, count: result.length });
          return result;
        },
        TodoStoreErrorCode.SUBTASK_LIST_FAILED,
        '获取子任务失败',
      );
    },

    /**
     * 创建子任务
     */
    async createSubtask(parentId: string, todo: TodoCreate): Promise<Todo> {
      Lg.i(STORE_MODULE, '创建子任务', { parentId, title: todo.title });
      return this.withLoadingSafe(
        async () => {
          const result = await TodoDb.createSubtask(parentId, todo);
          Lg.i(STORE_MODULE, '子任务创建成功', { parentId, serialNum: result.serialNum });
          await this.fetchdPagedTodos();
          return result;
        },
        TodoStoreErrorCode.SUBTASK_CREATE_FAILED,
        '创建子任务失败',
      );
    },

    // ==================== 筛选器管理（不可变更新） ====================

    /**
     * 设置筛选器
     * 使用不可变更新模式
     */
    setFilter(filters: Partial<TodoFilters>) {
      Lg.d(STORE_MODULE, '设置筛选器', { filters });
      // 不可变更新：创建新对象
      this.filters = { ...this.filters, ...filters };
    },

    /**
     * 清除所有筛选器
     */
    clearFilter() {
      Lg.d(STORE_MODULE, '清除筛选器');
      // 不可变更新：创建新空对象
      this.filters = {};
    },

    /**
     * 设置状态筛选
     */
    setStatusFilter(status: Status | null) {
      Lg.d(STORE_MODULE, '设置状态筛选', { status });
      if (status) {
        // 不可变更新：创建新对象
        this.filters = { ...this.filters, status };
      } else {
        // 不可变更新：解构排除 status
        const { status: _, ...rest } = this.filters;
        this.filters = rest;
      }
    },

    /**
     * 设置日期范围筛选
     */
    setDateRangeFilter(dateRange: DateRange | null) {
      Lg.d(STORE_MODULE, '设置日期范围筛选', { dateRange });
      if (dateRange) {
        // 不可变更新：创建新对象
        this.filters = { ...this.filters, dateRange };
      } else {
        // 不可变更新：解构排除 dateRange
        const { dateRange: _, ...rest } = this.filters;
        this.filters = rest;
      }
    },

    // ==================== 排序管理（不可变更新） ====================

    /**
     * 设置排序选项
     */
    setSortOptions(sortBy: string, sortDir: SortDirection) {
      Lg.d(STORE_MODULE, '设置排序选项', { sortBy, sortDir });
      this.sortBy = sortBy;
      this.sortDir = sortDir;
    },

    /**
     * 重置排序为默认值
     */
    clearSort() {
      Lg.d(STORE_MODULE, '重置排序');
      this.sortBy = 'dueAt';
      this.sortDir = SortDirection.Asc;
    },

    /**
     * 重置整个 store 状态
     */
    $reset() {
      Lg.i(STORE_MODULE, '重置 store 状态');
      const initialState = createInitialState();
      this.todos = initialState.todos;
      this.todosPaged = initialState.todosPaged;
      this.loading = initialState.loading;
      this.lastFetched = initialState.lastFetched;
      this.cacheExpiry = initialState.cacheExpiry;
      this.error = initialState.error;
      this.filters = initialState.filters;
      this.sortBy = initialState.sortBy;
      this.sortDir = initialState.sortDir;
    },
  },
});
