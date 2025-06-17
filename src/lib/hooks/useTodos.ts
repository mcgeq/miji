// src/lib/hooks/useTodos.ts
import type { Todo } from '@/lib/schema/todos';
import {
  getEndOfTodayISOWithOffset,
  getLocalISODateTimeWithOffset,
} from '@/lib/utils/date';
import { PrioritySchema, StatusSchema } from '../schema/common';
import { uuid } from '../utils/uuid';

export function useTodos(todos: Todo[] = []) {
  const addTodo = (text: string) => {
    const now = getLocalISODateTimeWithOffset();
    const newTodo: Todo = {
      serial_num: uuid(38),
      title: text,
      created_at: now,
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
    return newTodo;
  };

  const toggleTodo = (serial_num: string) => {
    todos = todos.map((todo) =>
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
    );
  };

  const removeTodo = (serial_num: string) => {
    todos = todos.filter((todo) => todo.serial_num !== serial_num);
  };

  return {
    todos,
    addTodo,
    toggleTodo,
    removeTodo,
  };
}
