import { TodoMapper } from './todo';
import type { PagedResult } from './money/baseManager';
import type { TodoFilters } from './todo';
import type { PageQuery } from '@/schema/common';
import type { Todo, TodoCreate, TodoUpdate } from '@/schema/todos';

export class TodoDb {
  private static todoMapper = new TodoMapper();
  // ========================= Account Start=========================
  // Account 操作
  static async createTodo(todo: TodoCreate): Promise<Todo> {
    return this.todoMapper.create(todo);
  }

  static async getTodo(serialNum: string): Promise<Todo | null> {
    return this.todoMapper.getById(serialNum);
  }

  static async listTodo(): Promise<Todo[]> {
    return this.todoMapper.list();
  }

  static async updateTodo(serialNum: string, todo: TodoUpdate): Promise<Todo> {
    return this.todoMapper.update(serialNum, todo);
  }

  static async deleteTodo(serialNum: string): Promise<void> {
    return this.todoMapper.deleteById(serialNum);
  }

  static async listTodosPaged(
    query: PageQuery<TodoFilters> = {
      currentPage: 1,
      pageSize: 10,
      sortOptions: {},
      filter: {},
    },
  ): Promise<PagedResult<Todo>> {
    return this.todoMapper.listPaged(query);
  }
  // ========================= Account End =========================
}
