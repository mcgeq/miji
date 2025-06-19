// src/lib/stores/todos.svelte.ts
import type { Todo } from '@/lib/schema/todos';
import {
  getLocalISODateTimeWithOffset,
  getEndOfTodayISOWithOffset,
} from '@/lib/utils/date';
import { PrioritySchema, StatusSchema } from '@/lib/schema/common';
import { uuid } from '@/lib/utils/uuid';
import { SvelteMap } from 'svelte/reactivity';

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

// 定义 store
export let todos = $state<SvelteMap<string, Todo>>(new SvelteMap());

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

export const todoStore = {
  addTodo,
  toggleTodo,
  removeTodo,
  editTodo,
};
