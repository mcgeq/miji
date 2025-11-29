// src/stores/todoStore.ts
import { defineStore } from 'pinia';
import { AppError } from '@/errors/appError';
import { SortDirection, StatusSchema } from '@/schema/common';
import { TodoDb } from '@/services/todos';
import { DateUtils } from '@/utils/date';
import type { DateRange, PageQuery, Status } from '@/schema/common';
import type { Todo, TodoCreate, TodoUpdate } from '@/schema/todos';
import type { PagedMapResult, PagedResult } from '@/services/money/baseManager';
import type { TodoFilters } from '@/services/todo';

// ==================== Store State Interface ====================
interface TodoStoreState {
  todos: Todo[];
  todosPaged: PagedMapResult<Todo>;
  loading: boolean;
  lastFetched: Date | null;
  cacheExpiry: number;
  error: string | null;
  // 筛选器状态
  filters: TodoFilters;
  // 排序状态
  sortBy: string | null;
  sortDir: SortDirection;
}

export enum TodoStoreErrorCode {
  TODO_NOT_FOUND = 'TODO_NOT_FOUND',
  TRANSACTION_NOT_FOUND = 'TRANSACTION_NOT_FOUND',
  RELATED_TRANSACTION_NOT_FOUND = 'RELATED_TRANSACTION_NOT_FOUND',
  INVALID_TRANSACTION_TYPE = 'INVALID_TRANSACTION_TYPE',
  CREDIT_CARD_BALANCE_INVALID = 'CREDIT_CARD_BALANCE_INVALID',
  DATABASE_OPERATION_FAILED = 'DATABASE_OPERATION_FAILED',
  NOT_FOUND = 'NOT_FOUND',
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

export const useTodoStore = defineStore('todos', {
  state: (): TodoStoreState => ({
    todos: [],
    todosPaged: { rows: new Map(), totalPages: 0, currentPage: 1, totalCount: 0, pageSize: 10 },
    loading: false,
    lastFetched: null,
    cacheExpiry: 8 * 60 * 60 * 1000,
    error: null,
    filters: {},
    sortBy: 'dueAt',
    sortDir: SortDirection.Asc,
  }),
  getters: {
    // 所有待办的数组（从 Map 转换）
    todoList: (state): Todo[] => {
      return Array.from(state.todosPaged.rows.values());
    },

    // 筛选后的待办列表
    filteredTodos: (state): Todo[] => {
      const todos = Array.from(state.todosPaged.rows.values());
      let filtered = todos;

      // 按状态筛选
      if (state.filters.status) {
        filtered = filtered.filter(todo => todo.status === state.filters.status);
      }

      // 按日期范围筛选
      if (state.filters.dateRange) {
        const { start, end } = state.filters.dateRange;
        if (start && end) {
          filtered = filtered.filter(todo => {
            const dueDate = new Date(todo.dueAt);
            return dueDate >= new Date(start) && dueDate <= new Date(end);
          });
        }
      }

      // 按父任务筛选（子任务）
      if (state.filters.parentId !== undefined) {
        filtered = filtered.filter(todo => todo.parentId === state.filters.parentId);
      }

      return filtered;
    },

    // 逾期的待办
    overdueTodos: (state): Todo[] => {
      const now = new Date();
      const todos = Array.from(state.todosPaged.rows.values());
      return todos.filter(todo => {
        if (todo.status === StatusSchema.enum.Completed) return false;
        return new Date(todo.dueAt) < now;
      });
    },

    // 今日待办
    todayTodos: (state): Todo[] => {
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      const tomorrow = new Date(today);
      tomorrow.setDate(tomorrow.getDate() + 1);

      const todos = Array.from(state.todosPaged.rows.values());
      return todos.filter(todo => {
        if (todo.status === StatusSchema.enum.Completed) return false;
        const dueDate = new Date(todo.dueAt);
        return dueDate >= today && dueDate < tomorrow;
      });
    },

    // 即将到期的待办（未来7天）
    upcomingTodos: (state): Todo[] => {
      const now = new Date();
      const weekLater = new Date(now.getTime() + 7 * 24 * 60 * 60 * 1000);
      const todos = Array.from(state.todosPaged.rows.values());
      return todos.filter(todo => {
        if (todo.status === StatusSchema.enum.Completed) return false;
        const dueDate = new Date(todo.dueAt);
        return dueDate >= now && dueDate <= weekLater;
      });
    },

    // 已完成的待办
    completedTodos: (state): Todo[] => {
      const todos = Array.from(state.todosPaged.rows.values());
      return todos.filter(todo => todo.status === StatusSchema.enum.Completed);
    },

    // 置顶的待办
    pinnedTodos: (state): Todo[] => {
      const todos = Array.from(state.todosPaged.rows.values());
      return todos.filter(todo => todo.isPinned && todo.status !== StatusSchema.enum.Completed);
    },
  },
  actions: {
    // 错误处理辅助函数
    handleError(err: unknown, defaultMessage: string): AppError {
      const appError: AppError = AppError.wrap(
        'money',
        err,
        TodoStoreErrorCode.DATABASE_OPERATION_FAILED,
        defaultMessage,
      );
      this.error = appError.getUserMessage();
      appError.log();
      return appError;
    },
    async withLoading<T>(operation: () => Promise<T>): Promise<T> {
      this.loading = true;
      this.error = null;
      try {
        return await operation();
      } finally {
        this.loading = false;
      }
    },
    async withLoadingSafe<T>(operation: () => Promise<T>, errorMsg: string): Promise<T> {
      this.loading = true;
      this.error = null;
      try {
        return await operation();
      } catch (err) {
        const appError = this.handleError(err, errorMsg);
        throw appError;
      } finally {
        this.loading = false;
      }
    },

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
      return this.withLoadingSafe(async () => {
        await this.listPagedTodos(query);
      }, '获取TODO信息失败');
    },

    async createTodo(todo: TodoCreate): Promise<Todo> {
      return this.withLoadingSafe(async () => {
        const result = await TodoDb.createTodo(todo);
        await this.fetchdPagedTodos();
        return result;
      }, 'Create todo failed');
    },

    async updateTodo(serialNum: string, todo: TodoUpdate): Promise<Todo> {
      return this.withLoadingSafe(async () => {
        const result = await TodoDb.updateTodo(serialNum, todo);
        await this.fetchdPagedTodos();
        return result;
      }, 'Create todo failed');
    },

    async toggleTodo(serialNum: string, status: Status): Promise<Todo> {
      return this.withLoadingSafe(async () => {
        const result = await TodoDb.toggleTodo(serialNum, status);
        await this.fetchdPagedTodos();
        return result;
      }, 'Create todo failed');
    },

    async deleteTodo(serialNum: string): Promise<void> {
      return this.withLoadingSafe(async () => {
        const result = await TodoDb.deleteTodo(serialNum);
        await this.fetchdPagedTodos();
        return result;
      }, 'Create todo failed');
    },

    async listPagedTodos(query: PageQuery<TodoFilters>): Promise<PagedResult<Todo>> {
      return this.withLoadingSafe(async () => {
        const result = await TodoDb.listTodosPaged(query);
        result.rows.sort(compareTodos);
        const rowMap = new Map(result.rows.map(item => [item.serialNum, item]));
        this.todosPaged = { ...result, rows: rowMap };
        return result;
      }, '获取TODO信息失败');
    },

    // ===== 子任务操作 =====
    async listSubtasks(parentId: string): Promise<Todo[]> {
      return this.withLoadingSafe(async () => {
        return await TodoDb.listSubtasks(parentId);
      }, '获取子任务失败');
    },

    async createSubtask(parentId: string, todo: TodoCreate): Promise<Todo> {
      return this.withLoadingSafe(async () => {
        const result = await TodoDb.createSubtask(parentId, todo);
        await this.fetchdPagedTodos(); // 刷新列表
        return result;
      }, '创建子任务失败');
    },

    // ===== 筛选器管理 =====
    setFilter(filters: Partial<TodoFilters>) {
      this.filters = { ...this.filters, ...filters };
    },

    clearFilter() {
      this.filters = {};
    },

    setStatusFilter(status: Status | null) {
      if (status) {
        this.filters = { ...this.filters, status };
      } else {
        const { status: _, ...rest } = this.filters;
        this.filters = rest;
      }
    },

    setDateRangeFilter(dateRange: DateRange | null) {
      if (dateRange) {
        this.filters = { ...this.filters, dateRange };
      } else {
        const { dateRange: _, ...rest } = this.filters;
        this.filters = rest;
      }
    },

    // ===== 排序管理 =====
    setSortOptions(sortBy: string, sortDir: SortDirection) {
      this.sortBy = sortBy;
      this.sortDir = sortDir;
    },

    clearSort() {
      this.sortBy = 'dueAt';
      this.sortDir = SortDirection.Asc;
    },
  },
});
