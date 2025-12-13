/**
 * Todo Service
 * 待办服务层，负责待办的数据访问和业务逻辑
 * @module services/todoService
 */

import type { PageQuery, Status } from '@/schema/common';
import type { Todo, TodoCreate, TodoUpdate } from '@/schema/todos';
import { wrapError } from '@/utils/errorHandler';
import type { PagedResult } from './money/baseManager';
import type { TodoFilters } from './todo';
import { TodoMapper } from './todo';

/**
 * 待办服务类
 * 提供待办的 CRUD 操作和自定义业务方法
 */
class TodoService {
  private mapper: TodoMapper;

  constructor() {
    this.mapper = new TodoMapper();
  }

  /**
   * 创建待办
   */
  async create(data: TodoCreate): Promise<Todo> {
    try {
      return await this.mapper.create(data);
    } catch (error) {
      throw wrapError('TodoService', error, 'CREATE_FAILED', '创建待办失败');
    }
  }

  /**
   * 根据 ID 获取待办
   */
  async getById(id: string): Promise<Todo | null> {
    try {
      return await this.mapper.getById(id);
    } catch (error) {
      throw wrapError('TodoService', error, 'GET_FAILED', '获取待办失败');
    }
  }

  /**
   * 获取待办列表
   */
  async list(): Promise<Todo[]> {
    try {
      return await this.mapper.list();
    } catch (error) {
      throw wrapError('TodoService', error, 'LIST_FAILED', '获取待办列表失败');
    }
  }

  /**
   * 更新待办
   */
  async update(id: string, data: TodoUpdate): Promise<Todo> {
    try {
      return await this.mapper.update(id, data);
    } catch (error) {
      throw wrapError('TodoService', error, 'UPDATE_FAILED', '更新待办失败');
    }
  }

  /**
   * 删除待办
   */
  async delete(id: string): Promise<void> {
    try {
      await this.mapper.delete(id);
    } catch (error) {
      throw wrapError('TodoService', error, 'DELETE_FAILED', '删除待办失败');
    }
  }

  /**
   * 切换待办状态
   * @param serialNum - 待办序列号
   * @param status - 新状态
   * @returns 更新后的待办
   */
  async toggle(serialNum: string, status: Status): Promise<Todo> {
    try {
      return await this.mapper.toggle(serialNum, status);
    } catch (error) {
      throw wrapError('TodoService', error, 'TOGGLE_FAILED', `切换待办状态失败: ${serialNum}`);
    }
  }

  /**
   * 分页查询待办列表
   * @param query - 分页查询参数
   * @returns 分页结果
   */
  async listPaged(query: PageQuery<TodoFilters>): Promise<PagedResult<Todo>> {
    try {
      return await this.mapper.listPaged(query);
    } catch (error) {
      throw wrapError('TodoService', error, 'LIST_PAGED_FAILED', '分页查询待办失败');
    }
  }

  /**
   * 获取子任务列表
   * @param parentId - 父任务 ID
   * @returns 子任务列表
   */
  async listSubtasks(parentId: string): Promise<Todo[]> {
    try {
      return await this.mapper.listSubtasks(parentId);
    } catch (error) {
      throw wrapError('TodoService', error, 'LIST_SUBTASKS_FAILED', `获取子任务失败: ${parentId}`);
    }
  }

  /**
   * 创建子任务
   * @param parentId - 父任务 ID
   * @param todo - 子任务数据
   * @returns 创建的子任务
   */
  async createSubtask(parentId: string, todo: TodoCreate): Promise<Todo> {
    try {
      return await this.mapper.createSubtask(parentId, todo);
    } catch (error) {
      throw wrapError('TodoService', error, 'CREATE_SUBTASK_FAILED', `创建子任务失败: ${parentId}`);
    }
  }

  /**
   * 根据状态筛选待办
   * @param status - 待办状态
   * @returns 匹配的待办列表
   */
  async findByStatus(status: Status): Promise<Todo[]> {
    try {
      const allTodos = await this.list();
      return allTodos.filter(todo => todo.status === status);
    } catch (error) {
      throw wrapError(
        'TodoService',
        error,
        'FIND_BY_STATUS_FAILED',
        `根据状态查找待办失败: ${status}`,
      );
    }
  }

  /**
   * 获取逾期的待办
   * @returns 逾期的待办列表
   */
  async getOverdueTodos(): Promise<Todo[]> {
    try {
      const allTodos = await this.list();
      const now = Date.now();
      return allTodos.filter(todo => {
        if (todo.status === 'Completed') return false;
        return new Date(todo.dueAt).getTime() < now;
      });
    } catch (error) {
      throw wrapError('TodoService', error, 'GET_OVERDUE_FAILED', '获取逾期待办失败');
    }
  }

  /**
   * 获取今日待办
   * @returns 今日待办列表
   */
  async getTodayTodos(): Promise<Todo[]> {
    try {
      const allTodos = await this.list();
      const today = new Date();
      today.setHours(0, 0, 0, 0);
      const todayTime = today.getTime();
      const tomorrowTime = todayTime + 24 * 60 * 60 * 1000;

      return allTodos.filter(todo => {
        if (todo.status === 'Completed') return false;
        const dueTime = new Date(todo.dueAt).getTime();
        return dueTime >= todayTime && dueTime < tomorrowTime;
      });
    } catch (error) {
      throw wrapError('TodoService', error, 'GET_TODAY_FAILED', '获取今日待办失败');
    }
  }

  /**
   * 获取即将到期的待办（未来7天）
   * @returns 即将到期的待办列表
   */
  async getUpcomingTodos(): Promise<Todo[]> {
    try {
      const allTodos = await this.list();
      const nowTime = Date.now();
      const weekLaterTime = nowTime + 7 * 24 * 60 * 60 * 1000;

      return allTodos.filter(todo => {
        if (todo.status === 'Completed') return false;
        const dueTime = new Date(todo.dueAt).getTime();
        return dueTime >= nowTime && dueTime <= weekLaterTime;
      });
    } catch (error) {
      throw wrapError('TodoService', error, 'GET_UPCOMING_FAILED', '获取即将到期待办失败');
    }
  }

  /**
   * 获取置顶的待办
   * @returns 置顶的待办列表
   */
  async getPinnedTodos(): Promise<Todo[]> {
    try {
      const allTodos = await this.list();
      return allTodos.filter(todo => todo.isPinned && todo.status !== 'Completed');
    } catch (error) {
      throw wrapError('TodoService', error, 'GET_PINNED_FAILED', '获取置顶待办失败');
    }
  }
}

/**
 * 待办服务单例实例
 * 导出单例以便在整个应用中使用
 */
export const todoService = new TodoService();
