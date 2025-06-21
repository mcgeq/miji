// src/lib/stores/todos.svelte.ts
import type { Todo, TodoRemain } from '@/lib/schema/todos';
import {
  getLocalISODateTimeWithOffset,
  getEndOfTodayISOWithOffset,
} from '@/lib/utils/date';
import { PrioritySchema, StatusSchema } from '@/lib/schema/common';
import { uuid } from '@/lib/utils/uuid';
import { SvelteMap } from 'svelte/reactivity';
import { differenceInSeconds, format, intervalToDuration } from 'date-fns';
import { t } from 'svelte-i18n';
import { get } from 'svelte/store';

const REFRESH_INTERVAL_MS = 5 * 60 * 1000;

// 定义 store
let todos = $state<SvelteMap<string, Todo>>(new SvelteMap());
let todosRemainingTime = $state<SvelteMap<string, TodoRemain>>(new SvelteMap());
let globalIntervalId: ReturnType<typeof setInterval> | null = null;

// 默认 Todo 对象
const defaultTodo: Partial<Todo> = {
  createdAt: getLocalISODateTimeWithOffset(),
  updatedAt: null,
  dueAt: getEndOfTodayISOWithOffset(),
  priority: PrioritySchema.enum.Medium,
  status: StatusSchema.enum.NotStarted,
  description: null,
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
};

// 创建新 Todo
const createTodo = (title: string): Todo =>
  ({
    serialNum: uuid(38),
    title,
    ...defaultTodo,
  }) as Todo;

export const getTodos = () => todos;

export const getTodosRemainingTime = () => todosRemainingTime;

export const addTodo = (text: string) => {
  if (!text.trim()) return;
  const newTodo = createTodo(text);
  todos.set(newTodo.serialNum, newTodo);
  updateTodoRemainingTime(newTodo);
};

export const toggleTodo = (serialNum: string) => {
  const todo = todos.get(serialNum);
  if (!todo) return;

  const updatedTodo = {
    ...todo,
    status:
      todo.status === StatusSchema.enum.Completed
        ? StatusSchema.enum.NotStarted
        : StatusSchema.enum.Completed,
    completedAt:
      todo.status === StatusSchema.enum.Completed
        ? null
        : getLocalISODateTimeWithOffset(),
  };

  todos.set(serialNum, updatedTodo);
  updateTodoRemainingTime(updatedTodo);
};

export const removeTodo = (serialNum: string) => {
  todos.delete(serialNum);
  todosRemainingTime.delete(serialNum);
};

export const editTodo = (serialNum: string, updatedTodo: Todo) => {
  const todo = todos.get(serialNum);
  if (!todo) return;
  const newTodo = { ...todo, ...updatedTodo };
  todos.set(serialNum, newTodo);
  updateTodoRemainingTime(newTodo);
};

export const startGlobalTimer = () => {
  if (globalIntervalId) return;
  globalIntervalId = setInterval(() => {
    todos.forEach(updateTodoRemainingTime);
  }, REFRESH_INTERVAL_MS);
};

export const stopGlobalTimer = () => {
  if (globalIntervalId) {
    clearInterval(globalIntervalId);
    globalIntervalId = null;
  }
};

const calculateRemainingTime = (todo: Todo) => {
  const tFn = get(t);
  if (todo.status === StatusSchema.enum.Completed) {
    return `${tFn('todos.completed')}: ${format(new Date(), 'yyyy-MM-dd HH:mm:ss')}`;
  }
  const now = new Date();
  const diffSeconds = differenceInSeconds(new Date(todo.dueAt), now);
  if (diffSeconds <= 0) {
    return tFn('todos.expired');
  }
  const duration = intervalToDuration({ start: 0, end: diffSeconds * 1000 });
  if ((duration.days || 0) > 0) {
    return `${tFn('todos.dueAt')}: ${duration.days || 0}d ${duration.hours || 0}h ${duration.minutes || 0}m`;
  }
  return `${tFn('todos.dueAt')}: ${duration.hours || 0}h ${duration.minutes || 0}m`;
};

const updateTodoRemainingTime = (todo: Todo) => {
  const remainingTime =
    todo.status === StatusSchema.enum.Completed
      ? get(t)('todos.completed') +
        `: ${format(new Date(todo.completedAt ?? new Date()), 'yyyy-MM-dd HH:mm:ss')}`
      : calculateRemainingTime(todo);

  todosRemainingTime.set(todo.serialNum, {
    ...todo,
    remainingTime,
  });
};

export const todoStore = {
  getTodos,
  addTodo,
  toggleTodo,
  removeTodo,
  editTodo,
  getTodosRemainingTime,
};
