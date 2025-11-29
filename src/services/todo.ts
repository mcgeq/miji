// src/lib/api/todos.ts
import { invokeCommand } from '@/types/api';
import { BaseMapper } from './money/baseManager';
import type { DateRange, PageQuery, Status } from '../schema/common';
import type { Todo, TodoCreate, TodoUpdate } from '../schema/todos';
import type { PagedResult } from './money/baseManager';

// 查询过滤器接口
export interface TodoFilters {
  status?: Status;
  dateRange?: DateRange;
  parentId?: string | null; // 用于查询子任务
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

  // ===== 子任务操作 =====
  async listSubtasks(parentId: string): Promise<Todo[]> {
    try {
      // 使用 todo_list 并过滤 parentId
      const filter: TodoFilters = { parentId };
      return await invokeCommand<Todo[]>('todo_list', { filter });
    } catch (error) {
      this.handleError('listSubtasks', error);
    }
  }

  async createSubtask(parentId: string, todo: TodoCreate): Promise<Todo> {
    try {
      // 创建时设置 parentId
      const todoWithParent = { ...todo, parentId };
      return await invokeCommand<Todo>('todo_create', {
        data: todoWithParent,
      });
    } catch (error) {
      this.handleError('createSubtask', error);
    }
  }

  // ===== 项目关联操作（注：需要后端 commands 支持）=====
  // 目前后端有 todo_project service 但没有暴露 commands
  // 临时方案：通过 todo_update 更新项目关联
  // 完整方案：需要后端添加 todo_project_* commands

  // ===== 标签关联操作（注：需要后端 commands 支持）=====
  // 目前后端有 todo_tag service 但没有暴露 commands
  // 临时方案：通过 todo_update 更新标签关联
  // 完整方案：需要后端添加 todo_tag_* commands
}
