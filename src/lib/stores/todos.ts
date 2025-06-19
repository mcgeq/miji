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
export const todos = writable<Todo[]>([]);

export const todoStore = {
  addTodo: (text: string) => {
    if (!text.trim()) return;
    const newTodo = createTodo(text);
    todos.update((currentTodos) => [...currentTodos, newTodo]);
  },
  toggleTodo: (serialNum: string) => {
    todos.update((currentTodos) =>
      currentTodos.map((todo) =>
        todo.serialNum === serialNum
          ? {
              ...todo,
              status:
                todo.status === StatusSchema.enum.Completed
                  ? StatusSchema.enum.NotStarted
                  : StatusSchema.enum.Completed,
              completedAt:
                todo.status === StatusSchema.enum.Completed
                  ? null
                  : getLocalISODateTimeWithOffset(),
            }
          : todo,
      ),
    );
  },
  removeTodo: (serialNum: string) => {
    todos.update((currentTodos) =>
      currentTodos.filter((todo) => todo.serialNum !== serialNum),
    );
  },
  editTodo: (serialNum: string, updatedTodo: Todo) => {
    todos.update((currentTodos) =>
      currentTodos.map((todo) =>
        todo.serialNum === serialNum ? { ...todo, ...updatedTodo } : todo,
      ),
    );
  },
};
