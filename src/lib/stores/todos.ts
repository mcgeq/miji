// src/lib/stores/todos.ts
import { writable } from 'svelte/store';
import type { Todo } from '@/lib/schema/todos';
import {
  getLocalISODateTimeWithOffset,
  getEndOfTodayISOWithOffset,
} from '@/lib/utils/date';
import { PrioritySchema, StatusSchema } from '@/lib/schema/common';
import { uuid } from '@/lib/utils/uuid';

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
export const todos = writable<Todo[]>([]);

export const todoStore = {
  addTodo: (text: string) => {
    if (!text.trim()) return;
    const newTodo = createTodo(text);
    todos.update((currentTodos) => [...currentTodos, newTodo]);
  },
  toggleTodo: (serial_num: string) => {
    todos.update((currentTodos) =>
      currentTodos.map((todo) =>
        todo.serial_num === serial_num
          ? {
              ...todo,
              status:
                todo.status === StatusSchema.enum.Completed
                  ? StatusSchema.enum.NotStarted
                  : StatusSchema.enum.Completed,
              completed_at:
                todo.status === StatusSchema.enum.Completed
                  ? null
                  : getLocalISODateTimeWithOffset(),
            }
          : todo,
      ),
    );
  },
  removeTodo: (serial_num: string) => {
    todos.update((currentTodos) =>
      currentTodos.filter((todo) => todo.serial_num !== serial_num),
    );
  },
  editTodo: (serial_num: string, updatedTodo: Todo) => {
    todos.update((currentTodos) =>
      currentTodos.map((todo) =>
        todo.serial_num === serial_num ? { ...todo, ...updatedTodo } : todo,
      ),
    );
  },
};
