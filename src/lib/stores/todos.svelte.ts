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
  created_at: getLocalISODateTimeWithOffset(),
  updated_at: null,
  due_at: getEndOfTodayISOWithOffset(),
  priority: PrioritySchema.enum.Medium,
  status: StatusSchema.enum.NotStarted,
  description: null,
  completed_at: null,
  assignee_id: null,
  progress: 0,
  location: null,
  owner_id: null,
  is_archived: false,
  is_pinned: false,
  estimate_minutes: null,
  reminder_count: 0,
  parent_id: null,
  subtask_order: null,
};

// 创建新 Todo
const createTodo = (title: string): Todo =>
  ({
    serial_num: uuid(38),
    title,
    ...defaultTodo,
  }) as Todo;

// 定义 store
export let todos = $state<SvelteMap<string, Todo>>(new SvelteMap());

export const addTodo = (text: string) => {
  if (!text.trim()) return;
  const newTodo = createTodo(text);
  todos.set(newTodo.serial_num, newTodo);
};

export const toggleTodo = (serial_num: string) => {
  const todo = todos.get(serial_num);
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

  todos.set(serial_num, updatedTodo);
};

export const removeTodo = (serial_num: string) => {
  todos.delete(serial_num);
};

export const editTodo = (serial_num: string, updatedTodo: Todo) => {
  const todo = todos.get(serial_num);
  if (!todo) return;
  todos.set(serial_num, { ...todo, ...updatedTodo });
};

export const todoStore = {
  addTodo,
  toggleTodo,
  removeTodo,
  editTodo,
};
