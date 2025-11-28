import { TodoMapper } from './todo';
import type { PagedResult } from './money/baseManager';
import type { TodoFilters } from './todo';
import type { PageQuery, Status } from '@/schema/common';
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

  static async toggleTodo(serialNum: string, status: Status): Promise<Todo> {
    return this.todoMapper.toggle(serialNum, status);
  }

  static async deleteTodo(serialNum: string): Promise<void> {
    return this.todoMapper.deleteById(serialNum);
  }

  static async listTodosPaged(query: PageQuery<TodoFilters>): Promise<PagedResult<Todo>> {
    return this.todoMapper.listPaged(query);
  }

  // ========================= 子任务操作 Start =========================
  static async listSubtasks(parentId: string): Promise<Todo[]> {
    return this.todoMapper.listSubtasks(parentId);
  }

  static async createSubtask(parentId: string, todo: TodoCreate): Promise<Todo> {
    return this.todoMapper.createSubtask(parentId, todo);
  }
  // ========================= 子任务操作 End =========================

  // ========================= 项目关联操作 Start =========================
  // 注：目前后端有 todo_project service 但没有暴露 Tauri commands
  // 需要后端添加以下 commands 才能完整实现：
  // - todo_project_add(todo_id, project_id)
  // - todo_project_remove(todo_id, project_id)
  // - todo_project_list(todo_id)
  //
  // 临时方案：可以通过 TodoUpdate 在前端管理项目 ID 列表
  // 完整方案：等待后端添加 commands 后实现
  // ========================= 项目关联操作 End =========================

  // ========================= 标签关联操作 Start =========================
  // 注：目前后端有 todo_tag service 但没有暴露 Tauri commands
  // 需要后端添加以下 commands 才能完整实现：
  // - todo_tag_add(todo_id, tag_id)
  // - todo_tag_remove(todo_id, tag_id)
  // - todo_tag_list(todo_id)
  //
  // 临时方案：可以通过 TodoUpdate 在前端管理标签 ID 列表
  // 完整方案：等待后端添加 commands 后实现
  // ========================= 标签关联操作 End =========================
  // ========================= Account End =========================
}
