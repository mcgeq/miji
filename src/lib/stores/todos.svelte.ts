// src/lib/stores/todos.svelte.ts
import type { Todo, TodoRemain } from '@/lib/schema/todos';
import {
  getLocalISODateTimeWithOffset,
  getEndOfTodayISOWithOffset,
} from '@/lib/utils/date';
import { PrioritySchema, StatusSchema } from '@/lib/schema/common';
import { uuid } from '@/lib/utils/uuid';
import { SvelteMap } from 'svelte/reactivity';
import { differenceInSeconds, intervalToDuration } from 'date-fns';
import { t } from 'svelte-i18n';
import { get } from 'svelte/store';

// 定义 store
export let todos = $state<SvelteMap<string, Todo>>(new SvelteMap());
export let todosRemainingTime = $derived.by(() => {
  let todosRemainMap = new SvelteMap<string, TodoRemain>();
  todos.forEach((v, k) => {
    if (v.status === StatusSchema.enum.Completed) {
      todosRemainMap.set(k, v);
    }
  });
  return todosRemainMap;
});

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

export const addTodo = (text: string) => {
  if (!text.trim()) return;
  const newTodo = createTodo(text);
  todos.set(newTodo.serialNum, newTodo);
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
    completed_at:
      todo.status === StatusSchema.enum.Completed
        ? null
        : getLocalISODateTimeWithOffset(),
  };

  todos.set(serialNum, updatedTodo);
};

export const removeTodo = (serialNum: string) => {
  todos.delete(serialNum);
};

export const editTodo = (serialNum: string, updatedTodo: Todo) => {
  const todo = todos.get(serialNum);
  if (!todo) return;
  todos.set(serialNum, { ...todo, ...updatedTodo });
};

const startGlobalTimer = () => {
  if (globalIntervalId) return;
};

const stopGlobalTimer = () => {
  if (globalIntervalId) {
    clearInterval(globalIntervalId);
    globalIntervalId = null;
  }
};

const calculateRemainingTime = (dueDate: string | Date) => {
  const $t = get(t);
  const now = new Date();
  const diffSeconds = differenceInSeconds(new Date(dueDate), now);
  if (diffSeconds <= 0) {
    return $t('todos.expired');
  }
  const duration = intervalToDuration({ start: 0, end: diffSeconds * 1000 });
  if ((duration.days || 0) > 0) {
    return `${$t('todos.dueAt')}: ${duration.days || 0}d ${duration.hours || 0}h ${duration.minutes || 0}m`;
  }
  return `${$t('todos.dueAt')}: ${duration.hours || 0}h ${duration.minutes || 0}m`;
};

export const todoStore = {
  addTodo,
  toggleTodo,
  removeTodo,
  editTodo,
};
