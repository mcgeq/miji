// src/lib/api/todos.ts
import { invokeCommand } from '@/types/api';
import { BaseMapper } from './money/baseManager';
import type { PageQuery, Status } from '../schema/common';
import type { Todo, TodoCreate, TodoUpdate } from '../schema/todos';
import type { PagedResult } from './money/baseManager';

// 查询过滤器接口
export interface TodoFilters {
  status?: Status;
}

/**
 * 账户数据映射器
 */
export class TodoMapper extends BaseMapper<TodoCreate, TodoUpdate, Todo> {
  protected entityName = 'Account';

  async create(account: TodoCreate): Promise<Todo> {
    try {
      return await invokeCommand<Todo>('todo_create', { data: account });
    } catch (error) {
      this.handleError('create', error);
    }
  }

  async getById(serialNum: string): Promise<Todo | null> {
    try {
      const account = await invokeCommand<Todo>('todo_get', {
        serialNum,
      });
      return account;
    } catch (error) {
      this.handleError('getById', error);
    }
  }

  async list(): Promise<Todo[]> {
    try {
      return await invokeCommand<Todo[]>('todo_list', { filter: {} });
    } catch (error) {
      this.handleError('list', error);
    }
  }

  async update(serialNum: string, account: TodoUpdate): Promise<Todo> {
    try {
      const result = await invokeCommand<Todo>('todo_update', {
        serialNum,
        data: account,
      });
      return result;
    } catch (error) {
      this.handleError('update', error);
    }
  }

  async toggle(serialNum: string, status: Status): Promise<Todo> {
    try {
      const result = await invokeCommand<Todo>('todo_toggle', {
        serialNum,
        status,
      });
      return result;
    } catch (error) {
      this.handleError('update', error);
    }
  }

  async deleteById(serialNum: string): Promise<void> {
    try {
      await invokeCommand('todo_delete', { serialNum });
    } catch (error) {
      this.handleError('deleteById', error);
    }
  }

  async listPaged(
    query: PageQuery<TodoFilters> = {
      currentPage: 1,
      pageSize: 10,
      sortOptions: {},
      filter: {},
    },
  ): Promise<PagedResult<Todo>> {
    try {
      const result = await invokeCommand<PagedResult<Todo>>('todo_list_paged', {
        query,
      });
      return result;
    } catch (err) {
      this.handleError('listPaged', err);
    }
  }
}
