// src/stores/todoStore.ts

import {differenceInSeconds, format, intervalToDuration} from 'date-fns';
import {defineStore} from 'pinia';
import {computed, reactive, ref} from 'vue';
import {useI18n} from 'vue-i18n';
import {todoStoreConst} from '@/constants/todoStore';
import {
  type FilterBtn,
  FilterBtnSchema,
  type Priority,
  PrioritySchema,
  type QueryFilters,
  StatusSchema,
} from '@/schema/common';
import {type Todo, type TodoRemain, TodoSchema} from '@/schema/todos';
import {todosDb} from '@/services/todos';
import {getCurrentUser} from '@/stores/auth';
import {
  getEndOfTodayISOWithOffset,
  getLocalISODateTimeWithOffset,
  getStartOfTodayISOWithOffset,
} from '@/utils/date';
import {Lg} from '@/utils/debugLog';
import {uuid} from '@/utils/uuid';
import {createRepeatPeriod, createWithDefaults} from '@/utils/zodFactory';

const customOrderBy = `
  CASE WHEN status = '${StatusSchema.enum.Completed}' THEN 1 ELSE 0 END ASC,
  CASE priority
    WHEN '${PrioritySchema.enum.Urgent}' THEN 1
    WHEN '${PrioritySchema.enum.High}' THEN 2
    WHEN '${PrioritySchema.enum.Medium}' THEN 3
    WHEN '${PrioritySchema.enum.Low}' THEN 4
    ELSE 5
  END ASC,
  created_at ASC
`;

export const useTodoStore = defineStore('todo', () => {
  // i18n
  const {t} = useI18n();
  // ---------- state ----------
  const todos = reactive(new Map<string, Todo>());
  const todosWithRemaining = reactive(new Map<string, TodoRemain>());
  const pageSize = ref(todoStoreConst.DEFAULT_PAGE_SIZE);
  const currentPage = ref(0);
  const totalPages = ref(0);
  const filterBtn = ref<FilterBtn>(FilterBtnSchema.enum.TODAY);
  const lastFilterBtn = ref<FilterBtn>(FilterBtnSchema.enum.TODAY);
  let globalIntervalId: ReturnType<typeof setInterval> | null = null;

  // ---------- computed ----------
  const sortedTodos = computed(() =>
    Array.from(todosWithRemaining.values()).sort(compareTodos),
  );

  // ---------- methods ----------
  const reloadPage = async () => {
    const user = getCurrentUser();
    if (!user) return;

    try {
      let allTodos: {rows: Todo[]; totalCount: number} = {
        rows: [],
        totalCount: 0,
      };
      if (filterBtn.value === FilterBtnSchema.enum.TODAY) {
        allTodos = await getTodayTodos(user.serialNum);
      } else if (filterBtn.value === FilterBtnSchema.enum.YESTERDAY) {
        allTodos = await getYesterdayTodos(user.serialNum);
      } else if (filterBtn.value === FilterBtnSchema.enum.TOMORROW) {
        allTodos = await getTomorrowTodos(user.serialNum);
      }

      if (currentPage.value === 1) {
        todos.clear();
        todosWithRemaining.clear();
      }

      if (allTodos.totalCount !== 0 && allTodos.rows) {
        const newTodoSerialNum = new Set(allTodos.rows.map((t) => t.serialNum));
        const todosSerialNum = new Set(todos.keys());
        for (const sn of todosSerialNum) {
          if (!newTodoSerialNum.has(sn)) {
            todos.delete(sn);
            todosWithRemaining.delete(sn);
          }
        }
        for (const todo of allTodos.rows) {
          todos.set(todo.serialNum, todo);
          updateTodoRemainingTime(todo);
        }

        totalPages.value = Math.ceil(allTodos.totalCount / pageSize.value);
        lastFilterBtn.value = filterBtn.value;
        if (totalPages.value === 0) currentPage.value = 0;
      }
    } catch (e) {
      Lg.e('todoStore', 'reloadPage', e);
    }
  };

  const createTodo = (input: Partial<Todo>): Todo =>
    createWithDefaults(
      TodoSchema,
      {
        serialNum: () => uuid(38),
        createdAt: getLocalISODateTimeWithOffset,
        updatedAt: null,
        dueAt: getEndOfTodayISOWithOffset,
        priority: PrioritySchema.enum.Medium,
        status: StatusSchema.enum.NotStarted,
        description: null,
        completedAt: null,
        assigneeId: null,
        progress: 0,
        location: null,
        ownerId: null,
        isArchived: 0,
        isPinned: 0,
        estimateMinutes: null,
        reminderCount: 0,
        repeat: createRepeatPeriod(),
        parentId: null,
        subtaskOrder: null,
      },
      input,
    );

  const addTodo = async (text: string) => {
    if (!text.trim()) return;
    const user = getCurrentUser();
    if (!user) return Lg.e('todoStore', 'No user is logged in');

    const newTodo = createTodo({title: text, ownerId: user.serialNum});
    try {
      await todosDb.insert(newTodo);
      await reloadPage();
    } catch (e) {
      Lg.e('todoStore', 'addTodo', e);
    }

    if (currentPage.value === 0) currentPage.value = 1;
  };

  const toggleTodo = async (serialNum: string) => {
    const todo = await todosDb.getTodo(serialNum);
    if (!todo) return;
    const isCompleted = todo.status === StatusSchema.enum.Completed;
    const updated = {
      ...todo,
      status: isCompleted
        ? StatusSchema.enum.NotStarted
        : StatusSchema.enum.Completed,
      completedAt: isCompleted ? null : getLocalISODateTimeWithOffset(),
      updatedAt: getLocalISODateTimeWithOffset(),
    };
    await setTodo(updated);
  };

  const setTodo = async (todo: Todo) => {
    try {
      await todosDb.updateSmart(todo);
      await reloadPage();
    } catch (e) {
      Lg.e('todoStore', 'setTodo', e);
    }
  };

  const removeTodo = async (serialNum: string) => {
    todos.delete(serialNum);
    todosWithRemaining.delete(serialNum);
    try {
      await todosDb.deletes(serialNum);

      await reloadPage();
      if (totalPages.value === 0) currentPage.value = 0;
    } catch (e) {
      Lg.e('todoStore', 'removeTodo', e);
    }
  };

  const editTodo = async (serialNum: string, updatedTodo: TodoRemain) => {
    const todo = todos.get(serialNum);
    if (!todo) return;
    todos.delete(serialNum);
    todosWithRemaining.delete(serialNum);
    const {remainingTime, ...uTodo} = updatedTodo;
    await setTodo({
      ...todo,
      ...uTodo,
      updatedAt: getLocalISODateTimeWithOffset(),
    });
  };

  const formatCompletedTime = (completedAt: string | null | undefined) =>
    `${t('common.status.completed')}: ${format(new Date(completedAt ?? new Date()), 'yyyy-MM-dd HH:mm:ss')}`;

  const calculateRemainingTime = (todo: Todo): string => {
    if (todo.status === StatusSchema.enum.Completed) {
      return formatCompletedTime(todo.completedAt);
    }
    const now = new Date();
    const due = new Date(todo.dueAt);
    const diff = differenceInSeconds(due, now);
    if (diff <= 0) return t('todos.expired');
    const duration = intervalToDuration({start: 0, end: diff * 1000});
    if ((duration.days || 0) > 0) {
      return `${t('todos.dueAt')}: ${duration.days || 0}d ${duration.hours || 0}h ${
        duration.minutes || 0
      }m`;
    }
    return `${t('todos.dueAt')}: ${duration.hours || 0}h ${duration.minutes || 0}m`;
  };

  const updateTodoRemainingTime = (todo: Todo) => {
    todosWithRemaining.set(todo.serialNum, {
      ...todo,
      remainingTime: calculateRemainingTime(todo),
    });
  };

  const startGlobalTimer = () => {
    if (globalIntervalId) return;
    globalIntervalId = setInterval(() => {
      todos.forEach(updateTodoRemainingTime);
    }, todoStoreConst.REFRESH_INTERVAL_MS);
  };

  const stopGlobalTimer = () => {
    if (globalIntervalId) {
      clearInterval(globalIntervalId);
      globalIntervalId = null;
    }
  };

  const compareTodos = (a: TodoRemain, b: TodoRemain) => {
    const isCompletedA = a.status === StatusSchema.enum.Completed;
    const isCompletedB = b.status === StatusSchema.enum.Completed;
    if (isCompletedA !== isCompletedB) return isCompletedA ? 1 : -1;

    if (!isCompletedA) {
      const priorityOrder: Record<Priority, number> = {
        [PrioritySchema.enum.Urgent]: 1,
        [PrioritySchema.enum.High]: 2,
        [PrioritySchema.enum.Medium]: 3,
        [PrioritySchema.enum.Low]: 4,
      };
      const diff = priorityOrder[a.priority] - priorityOrder[b.priority];
      if (diff !== 0) return diff;
    }

    return a.createdAt.localeCompare(b.createdAt);
  };

  const getPagedTodos = () => {
    let start = (currentPage.value - 1) * pageSize.value;
    let end = start + pageSize.value;
    let slice = sortedTodos.value.slice(start, end);

    if (!slice.length && sortedTodos.value.length > 0) {
      start =
        (Math.ceil(sortedTodos.value.length / pageSize.value) - 1) *
        pageSize.value;
      end = sortedTodos.value.length;
      slice = sortedTodos.value.slice(start, end);
    }

    const pagedMap = new Map<string, TodoRemain>();
    for (const todo of slice) pagedMap.set(todo.serialNum, todo);
    if (sortedTodos.value.length === 0) {
      currentPage.value = 0;
      totalPages.value = 0;
    }
    return pagedMap;
  };

  const nextPage = async () => {
    if (currentPage.value < totalPages.value) {
      currentPage.value += 1;
      await reloadPage();
    }
  };

  const prevPage = async () => {
    if (currentPage.value > 1) {
      currentPage.value -= 1;
      await reloadPage();
    }
  };

  const setPage = async (page: number) => {
    if (page >= 1 && page <= totalPages.value) {
      currentPage.value = page;
      await reloadPage();
    }
  };

  const setPageSize = (size: number) => {
    pageSize.value = size;
  };

  const setFilterBtn = async (filter: FilterBtn) => {
    filterBtn.value = filter;
    await reloadPage();
    if (todos.size === 0) {
      totalPages.value = 0;
      currentPage.value = 0;
    } else {
      totalPages.value = 1;
      currentPage.value = 1;
    }
  };

  const getTodayTodos = async (ownerId: string) => {
    try {
      const filters: QueryFilters = {
        dueAtRange: {
          start: getEndOfTodayISOWithOffset({days: -3}),
          end: getEndOfTodayISOWithOffset(),
        },
        orQuery: true,
      };
      return await todosDb.listPaged(
        ownerId,
        filters,
        currentPage.value,
        pageSize.value,
        {customOrderBy},
      );
    } catch (e) {
      Lg.e('todoStore', 'getTodayTodos', e);
      return {rows: [], totalCount: 0};
    }
  };

  const getYesterdayTodos = async (ownerId: string) => {
    try {
      const filters: QueryFilters = {
        dueAtRange: {end: getEndOfTodayISOWithOffset({days: -3})},
        status: StatusSchema.enum.Completed,
      };
      return await todosDb.listPaged(
        ownerId,
        filters,
        currentPage.value,
        pageSize.value,
        {customOrderBy},
      );
    } catch (e) {
      Lg.e('todoStore', 'getYesterdayTodos', e);
      return {rows: [], totalCount: 0};
    }
  };

  const getTomorrowTodos = async (ownerId: string) => {
    try {
      const filters: QueryFilters = {
        dueAtRange: {start: getStartOfTodayISOWithOffset({days: 1})},
      };
      return await todosDb.listPaged(
        ownerId,
        filters,
        currentPage.value,
        pageSize.value,
        {customOrderBy},
      );
    } catch (e) {
      Lg.e('todoStore', 'getTomorrowTodos', e);
      return {rows: [], totalCount: 0};
    }
  };

  return {
    todos,
    todosWithRemaining,
    pageSize,
    currentPage,
    totalPages,
    filterBtn,
    lastFilterBtn,
    sortedTodos,
    reloadPage,
    addTodo,
    toggleTodo,
    removeTodo,
    editTodo,
    getPagedTodos,
    nextPage,
    prevPage,
    setPage,
    setPageSize,
    setFilterBtn,
    startGlobalTimer,
    stopGlobalTimer,
  };
});
