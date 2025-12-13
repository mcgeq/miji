/**
 * TodoStore 单元测试
 * 测试 Store actions、错误处理和 $reset 方法
 */

import { describe, it, expect, beforeEach, vi } from 'vitest';
import { setActivePinia, createPinia } from 'pinia';
import { useTodoStore } from '@/stores/todoStore';
import { todoService } from '@/services/todoService';
import type { Todo, TodoCreate, TodoUpdate } from '@/schema/todos';
import type { Status } from '@/schema/common';
import { StatusSchema } from '@/schema/common';
import type { PagedResult } from '@/services/money/baseManager';

// Mock todoService
vi.mock('@/services/todoService', () => ({
  todoService: {
    list: vi.fn(),
    getById: vi.fn(),
    create: vi.fn(),
    update: vi.fn(),
    delete: vi.fn(),
    toggle: vi.fn(),
    listPaged: vi.fn(),
    listSubtasks: vi.fn(),
    createSubtask: vi.fn(),
    findByStatus: vi.fn(),
    getOverdueTodos: vi.fn(),
    getTodayTodos: vi.fn(),
    getUpcomingTodos: vi.fn(),
    getPinnedTodos: vi.fn(),
  },
}));

// Helper function to create mock todos with all required fields
function createMockTodo(overrides?: Partial<Todo>): Todo {
  return {
    serialNum: 'todo-1',
    title: 'Test Todo',
    description: 'Test Description',
    status: StatusSchema.enum.NotStarted,
    priority: 'Medium',
    dueAt: '2025-12-31T00:00:00Z',
    isPinned: false,
    parentId: null,
    createdAt: '2025-01-01T00:00:00Z',
    updatedAt: '2025-01-01T00:00:00Z',
    repeatPeriodType: 'None',
    repeat: { type: 'None' },
    completedAt: null,
    assigneeId: null,
    progress: 0,
    location: null,
    ownerId: null,
    isArchived: false,
    estimateMinutes: null,
    reminderCount: 0,
    subtaskOrder: null,
    reminderEnabled: false,
    reminderAdvanceValue: null,
    reminderAdvanceUnit: null,
    lastReminderSentAt: null,
    reminderFrequency: null,
    snoozeUntil: null,
    reminderMethods: null,
    timezone: null,
    smartReminderEnabled: false,
    locationBasedReminder: false,
    weatherDependent: false,
    priorityBoostEnabled: false,
    batchReminderId: null,
    ...overrides,
  };
}

describe('TodoStore', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    vi.clearAllMocks();
  });

  const mockTodo = createMockTodo();
  const mockTodo2 = createMockTodo({
    serialNum: 'todo-2',
    title: 'Another Todo',
    description: 'Another Description',
    status: StatusSchema.enum.InProgress,
    priority: 'High',
    dueAt: '2025-12-30T00:00:00Z',
    isPinned: true,
    createdAt: '2025-01-02T00:00:00Z',
    updatedAt: '2025-01-02T00:00:00Z',
  });

  const mockPagedResult: PagedResult<Todo> = {
    rows: [mockTodo, mockTodo2],
    totalCount: 2,
    currentPage: 1,
    pageSize: 10,
    totalPages: 1,
  };

  describe('listPagedTodos', () => {
    it('should fetch and store paged todos', async () => {
      const store = useTodoStore();
      vi.mocked(todoService.listPaged).mockResolvedValue(mockPagedResult);

      await store.listPagedTodos({
        currentPage: 1,
        pageSize: 10,
        sortOptions: {},
        filter: {},
      });

      expect(todoService.listPaged).toHaveBeenCalledOnce();
      expect(store.todoList).toHaveLength(2);
      expect(store.error).toBeNull();
    });

    it('should handle fetch error', async () => {
      const store = useTodoStore();
      const mockError = new Error('Fetch failed');
      vi.mocked(todoService.listPaged).mockRejectedValue(mockError);

      await expect(
        store.listPagedTodos({
          currentPage: 1,
          pageSize: 10,
          sortOptions: {},
          filter: {},
        }),
      ).rejects.toThrow();
      expect(store.error).not.toBeNull();
      expect(store.error?.code).toBe('LIST_FAILED');
    });
  });

  describe('createTodo', () => {
    it('should create a new todo', async () => {
      const store = useTodoStore();
      const createData: TodoCreate = {
        title: 'New Todo',
        description: 'New Description',
        status: StatusSchema.enum.NotStarted,
        priority: 'Medium',
        dueAt: '2025-12-31T00:00:00Z',
        repeatPeriodType: 'None',
        repeat: { type: 'None' },
        completedAt: null,
        assigneeId: null,
        progress: 0,
        location: null,
        ownerId: null,
        isArchived: false,
        isPinned: false,
        estimateMinutes: null,
        reminderCount: 0,
        parentId: null,
        subtaskOrder: null,
        reminderEnabled: false,
        reminderAdvanceValue: null,
        reminderAdvanceUnit: null,
        lastReminderSentAt: null,
        reminderFrequency: null,
        snoozeUntil: null,
        reminderMethods: null,
        timezone: null,
        smartReminderEnabled: false,
        locationBasedReminder: false,
        weatherDependent: false,
        priorityBoostEnabled: false,
        batchReminderId: null,
      };
      vi.mocked(todoService.create).mockResolvedValue(mockTodo);
      vi.mocked(todoService.listPaged).mockResolvedValue(mockPagedResult);

      const result = await store.createTodo(createData);

      expect(todoService.create).toHaveBeenCalledWith(createData);
      expect(result).toEqual(mockTodo);
    });

    it('should handle create error', async () => {
      const store = useTodoStore();
      const createData: TodoCreate = {
        title: 'New Todo',
        description: null,
        status: StatusSchema.enum.NotStarted,
        priority: 'Medium',
        dueAt: '2025-12-31T00:00:00Z',
        repeatPeriodType: 'None',
        repeat: { type: 'None' },
        completedAt: null,
        assigneeId: null,
        progress: 0,
        location: null,
        ownerId: null,
        isArchived: false,
        isPinned: false,
        estimateMinutes: null,
        reminderCount: 0,
        parentId: null,
        subtaskOrder: null,
        reminderEnabled: false,
        reminderAdvanceValue: null,
        reminderAdvanceUnit: null,
        lastReminderSentAt: null,
        reminderFrequency: null,
        snoozeUntil: null,
        reminderMethods: null,
        timezone: null,
        smartReminderEnabled: false,
        locationBasedReminder: false,
        weatherDependent: false,
        priorityBoostEnabled: false,
        batchReminderId: null,
      };
      const mockError = new Error('Create failed');
      vi.mocked(todoService.create).mockRejectedValue(mockError);

      await expect(store.createTodo(createData)).rejects.toThrow();
      expect(store.error).not.toBeNull();
      expect(store.error?.code).toBe('CREATE_FAILED');
    });
  });

  describe('updateTodo', () => {
    it('should update an existing todo', async () => {
      const store = useTodoStore();
      const updateData: TodoUpdate = { title: 'Updated Todo' };
      const updatedTodo = { ...mockTodo, title: 'Updated Todo' };
      vi.mocked(todoService.update).mockResolvedValue(updatedTodo);
      vi.mocked(todoService.listPaged).mockResolvedValue(mockPagedResult);

      const result = await store.updateTodo('todo-1', updateData);

      expect(todoService.update).toHaveBeenCalledWith('todo-1', updateData);
      expect(result).toEqual(updatedTodo);
    });

    it('should handle update error', async () => {
      const store = useTodoStore();
      const updateData: TodoUpdate = { title: 'Updated Todo' };
      const mockError = new Error('Update failed');
      vi.mocked(todoService.update).mockRejectedValue(mockError);

      await expect(store.updateTodo('todo-1', updateData)).rejects.toThrow();
      expect(store.error).not.toBeNull();
      expect(store.error?.code).toBe('UPDATE_FAILED');
    });
  });

  describe('toggleTodo', () => {
    it('should toggle todo status', async () => {
      const store = useTodoStore();
      const newStatus: Status = StatusSchema.enum.Completed;
      const toggledTodo = { ...mockTodo, status: newStatus };
      vi.mocked(todoService.toggle).mockResolvedValue(toggledTodo);
      vi.mocked(todoService.listPaged).mockResolvedValue(mockPagedResult);

      const result = await store.toggleTodo('todo-1', newStatus);

      expect(todoService.toggle).toHaveBeenCalledWith('todo-1', newStatus);
      expect(result).toEqual(toggledTodo);
    });

    it('should handle toggle error', async () => {
      const store = useTodoStore();
      const mockError = new Error('Toggle failed');
      vi.mocked(todoService.toggle).mockRejectedValue(mockError);

      await expect(store.toggleTodo('todo-1', StatusSchema.enum.Completed)).rejects.toThrow();
      expect(store.error).not.toBeNull();
      expect(store.error?.code).toBe('TOGGLE_FAILED');
    });
  });

  describe('deleteTodo', () => {
    it('should delete a todo', async () => {
      const store = useTodoStore();
      vi.mocked(todoService.delete).mockResolvedValue();
      vi.mocked(todoService.listPaged).mockResolvedValue(mockPagedResult);

      await store.deleteTodo('todo-1');

      expect(todoService.delete).toHaveBeenCalledWith('todo-1');
    });

    it('should handle delete error', async () => {
      const store = useTodoStore();
      const mockError = new Error('Delete failed');
      vi.mocked(todoService.delete).mockRejectedValue(mockError);

      await expect(store.deleteTodo('todo-1')).rejects.toThrow();
      expect(store.error).not.toBeNull();
      expect(store.error?.code).toBe('DELETE_FAILED');
    });
  });

  describe('listSubtasks', () => {
    it('should list subtasks for a parent todo', async () => {
      const store = useTodoStore();
      const subtasks = [createMockTodo({ parentId: 'todo-1' })];
      vi.mocked(todoService.listSubtasks).mockResolvedValue(subtasks);

      const result = await store.listSubtasks('todo-1');

      expect(todoService.listSubtasks).toHaveBeenCalledWith('todo-1');
      expect(result).toEqual(subtasks);
    });

    it('should handle list subtasks error', async () => {
      const store = useTodoStore();
      const mockError = new Error('List subtasks failed');
      vi.mocked(todoService.listSubtasks).mockRejectedValue(mockError);

      await expect(store.listSubtasks('todo-1')).rejects.toThrow();
      expect(store.error).not.toBeNull();
      expect(store.error?.code).toBe('SUBTASK_LIST_FAILED');
    });
  });

  describe('createSubtask', () => {
    it('should create a subtask', async () => {
      const store = useTodoStore();
      const createData: TodoCreate = {
        title: 'Subtask',
        description: null,
        status: StatusSchema.enum.NotStarted,
        priority: 'Low',
        dueAt: '2025-12-31T00:00:00Z',
        repeatPeriodType: 'None',
        repeat: { type: 'None' },
        completedAt: null,
        assigneeId: null,
        progress: 0,
        location: null,
        ownerId: null,
        isArchived: false,
        isPinned: false,
        estimateMinutes: null,
        reminderCount: 0,
        parentId: null,
        subtaskOrder: null,
        reminderEnabled: false,
        reminderAdvanceValue: null,
        reminderAdvanceUnit: null,
        lastReminderSentAt: null,
        reminderFrequency: null,
        snoozeUntil: null,
        reminderMethods: null,
        timezone: null,
        smartReminderEnabled: false,
        locationBasedReminder: false,
        weatherDependent: false,
        priorityBoostEnabled: false,
        batchReminderId: null,
      };
      const subtask = createMockTodo({ parentId: 'todo-1' });
      vi.mocked(todoService.createSubtask).mockResolvedValue(subtask);
      vi.mocked(todoService.listPaged).mockResolvedValue(mockPagedResult);

      const result = await store.createSubtask('todo-1', createData);

      expect(todoService.createSubtask).toHaveBeenCalledWith('todo-1', createData);
      expect(result).toEqual(subtask);
    });

    it('should handle create subtask error', async () => {
      const store = useTodoStore();
      const createData: TodoCreate = {
        title: 'Subtask',
        description: null,
        status: StatusSchema.enum.NotStarted,
        priority: 'Low',
        dueAt: '2025-12-31T00:00:00Z',
        repeatPeriodType: 'None',
        repeat: { type: 'None' },
        completedAt: null,
        assigneeId: null,
        progress: 0,
        location: null,
        ownerId: null,
        isArchived: false,
        isPinned: false,
        estimateMinutes: null,
        reminderCount: 0,
        parentId: null,
        subtaskOrder: null,
        reminderEnabled: false,
        reminderAdvanceValue: null,
        reminderAdvanceUnit: null,
        lastReminderSentAt: null,
        reminderFrequency: null,
        snoozeUntil: null,
        reminderMethods: null,
        timezone: null,
        smartReminderEnabled: false,
        locationBasedReminder: false,
        weatherDependent: false,
        priorityBoostEnabled: false,
        batchReminderId: null,
      };
      const mockError = new Error('Create subtask failed');
      vi.mocked(todoService.createSubtask).mockRejectedValue(mockError);

      await expect(store.createSubtask('todo-1', createData)).rejects.toThrow();
      expect(store.error).not.toBeNull();
      expect(store.error?.code).toBe('SUBTASK_CREATE_FAILED');
    });
  });

  describe('filter management', () => {
    it('should set filter', () => {
      const store = useTodoStore();
      store.setFilter({ status: StatusSchema.enum.Completed });

      expect(store.filters.status).toBe(StatusSchema.enum.Completed);
    });

    it('should clear filter', () => {
      const store = useTodoStore();
      store.setFilter({ status: StatusSchema.enum.Completed });
      store.clearFilter();

      expect(store.filters).toEqual({});
    });

    it('should set status filter', () => {
      const store = useTodoStore();
      store.setStatusFilter(StatusSchema.enum.InProgress);

      expect(store.filters.status).toBe(StatusSchema.enum.InProgress);
    });

    it('should clear status filter', () => {
      const store = useTodoStore();
      store.setStatusFilter(StatusSchema.enum.InProgress);
      store.setStatusFilter(null);

      expect(store.filters.status).toBeUndefined();
    });

    it('should set date range filter', () => {
      const store = useTodoStore();
      const dateRange = { start: '2025-01-01', end: '2025-12-31' };
      store.setDateRangeFilter(dateRange);

      expect(store.filters.dateRange).toEqual(dateRange);
    });

    it('should clear date range filter', () => {
      const store = useTodoStore();
      const dateRange = { start: '2025-01-01', end: '2025-12-31' };
      store.setDateRangeFilter(dateRange);
      store.setDateRangeFilter(null);

      expect(store.filters.dateRange).toBeUndefined();
    });
  });

  describe('sort management', () => {
    it('should set sort options', () => {
      const store = useTodoStore();
      store.setSortOptions('title', 'asc' as any);

      expect(store.sortBy).toBe('title');
      expect(store.sortDir).toBe('asc');
    });

    it('should clear sort', () => {
      const store = useTodoStore();
      store.setSortOptions('title', 'desc' as any);
      store.clearSort();

      expect(store.sortBy).toBe('dueAt');
      expect(store.sortDir).toBe('Asc');
    });
  });

  describe('$reset', () => {
    it('should reset store to initial state', async () => {
      const store = useTodoStore();
      vi.mocked(todoService.listPaged).mockResolvedValue(mockPagedResult);
      await store.listPagedTodos({
        currentPage: 1,
        pageSize: 10,
        sortOptions: {},
        filter: {},
      });
      store.setFilter({ status: StatusSchema.enum.Completed });

      store.$reset();

      expect(store.todoList).toEqual([]);
      expect(store.isLoading).toBe(false);
      expect(store.error).toBeNull();
      expect(store.filters).toEqual({});
    });
  });

  describe('computed properties', () => {
    beforeEach(async () => {
      const store = useTodoStore();
      vi.mocked(todoService.listPaged).mockResolvedValue(mockPagedResult);
      await store.listPagedTodos({
        currentPage: 1,
        pageSize: 10,
        sortOptions: {},
        filter: {},
      });
    });

    it('should compute todoList correctly', () => {
      const store = useTodoStore();
      expect(store.todoList).toHaveLength(2);
    });

    it('should compute pinnedTodos correctly', () => {
      const store = useTodoStore();
      expect(store.pinnedTodos).toHaveLength(1);
      expect(store.pinnedTodos[0].serialNum).toBe('todo-2');
    });
  });
});
