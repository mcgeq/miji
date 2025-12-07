import type { PageQuery, Status } from '@/schema/common';
import type { Tags } from '@/schema/tags';
import type { Projects, Todo, TodoCreate, TodoUpdate } from '@/schema/todos';
import { invokeCommand } from '@/types/api';
import type { PagedResult } from './money/baseManager';
import type { TodoFilters } from './todo';
import { TodoMapper } from './todo';

export class TodoDb {
  private static todoMapper = new TodoMapper();
  // ========================= Account Start=========================
  // Account 操作
  static async createTodo(todo: TodoCreate): Promise<Todo> {
    return TodoDb.todoMapper.create(todo);
  }

  static async getTodo(serialNum: string): Promise<Todo | null> {
    return TodoDb.todoMapper.getById(serialNum);
  }

  static async listTodo(): Promise<Todo[]> {
    return TodoDb.todoMapper.list();
  }

  static async updateTodo(serialNum: string, todo: TodoUpdate): Promise<Todo> {
    return TodoDb.todoMapper.update(serialNum, todo);
  }

  static async toggleTodo(serialNum: string, status: Status): Promise<Todo> {
    return TodoDb.todoMapper.toggle(serialNum, status);
  }

  static async deleteTodo(serialNum: string): Promise<void> {
    return TodoDb.todoMapper.deleteById(serialNum);
  }

  static async listTodosPaged(query: PageQuery<TodoFilters>): Promise<PagedResult<Todo>> {
    return TodoDb.todoMapper.listPaged(query);
  }

  // ========================= 子任务操作 Start =========================
  static async listSubtasks(parentId: string): Promise<Todo[]> {
    return TodoDb.todoMapper.listSubtasks(parentId);
  }

  static async createSubtask(parentId: string, todo: TodoCreate): Promise<Todo> {
    return TodoDb.todoMapper.createSubtask(parentId, todo);
  }
  // ========================= 子任务操作 End =========================

  // ========================= 项目关联操作 Start =========================
  static async addProject(todoSerialNum: string, projectSerialNum: string): Promise<void> {
    await invokeCommand('todo_project_add', {
      todoSerialNum,
      projectSerialNum,
    });
  }

  static async removeProject(todoSerialNum: string, projectSerialNum: string): Promise<void> {
    await invokeCommand('todo_project_remove', {
      todoSerialNum,
      projectSerialNum,
    });
  }

  static async listProjects(todoSerialNum: string): Promise<Projects[]> {
    return invokeCommand<Projects[]>('todo_project_list', {
      todoSerialNum,
    });
  }
  // ========================= 项目关联操作 End =========================

  // ========================= 标签关联操作 Start =========================
  static async addTag(todoSerialNum: string, tagSerialNum: string): Promise<void> {
    await invokeCommand('todo_tag_add', {
      todoSerialNum,
      tagSerialNum,
    });
  }

  static async removeTag(todoSerialNum: string, tagSerialNum: string): Promise<void> {
    await invokeCommand('todo_tag_remove', {
      todoSerialNum,
      tagSerialNum,
    });
  }

  static async listTags(todoSerialNum: string): Promise<Tags[]> {
    return invokeCommand<Tags[]>('todo_tag_list', {
      todoSerialNum,
    });
  }
  // ========================= 标签关联操作 End =========================
  // ========================= Account End =========================
}
