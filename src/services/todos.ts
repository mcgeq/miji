import type { PageQuery, Status } from '@/schema/common';
import type { Tags } from '@/schema/tags';
import type { Projects, Todo, TodoCreate, TodoUpdate } from '@/schema/todos';
import { invokeCommand } from '@/types/api';
import type { PagedResult } from './money/baseManager';
import type { TodoFilters } from './todo';
import { TodoMapper } from './todo';

const todoMapper = new TodoMapper();

// ========================= Todo 操作 Start =========================
export async function createTodo(todo: TodoCreate): Promise<Todo> {
  return todoMapper.create(todo);
}

export async function getTodo(serialNum: string): Promise<Todo | null> {
  return todoMapper.getById(serialNum);
}

export async function listTodo(): Promise<Todo[]> {
  return todoMapper.list();
}

export async function updateTodo(serialNum: string, todo: TodoUpdate): Promise<Todo> {
  return todoMapper.update(serialNum, todo);
}

export async function toggleTodo(serialNum: string, status: Status): Promise<Todo> {
  return todoMapper.toggle(serialNum, status);
}

export async function deleteTodo(serialNum: string): Promise<void> {
  return todoMapper.deleteById(serialNum);
}

export async function listTodosPaged(query: PageQuery<TodoFilters>): Promise<PagedResult<Todo>> {
  return todoMapper.listPaged(query);
}
// ========================= Todo 操作 End =========================

// ========================= 子任务操作 Start =========================
export async function listSubtasks(parentId: string): Promise<Todo[]> {
  return todoMapper.listSubtasks(parentId);
}

export async function createSubtask(parentId: string, todo: TodoCreate): Promise<Todo> {
  return todoMapper.createSubtask(parentId, todo);
}
// ========================= 子任务操作 End =========================

// ========================= 项目关联操作 Start =========================
export async function addProject(todoSerialNum: string, projectSerialNum: string): Promise<void> {
  await invokeCommand('todo_project_add', {
    todoSerialNum,
    projectSerialNum,
  });
}

export async function removeProject(
  todoSerialNum: string,
  projectSerialNum: string,
): Promise<void> {
  await invokeCommand('todo_project_remove', {
    todoSerialNum,
    projectSerialNum,
  });
}

export async function listProjects(todoSerialNum: string): Promise<Projects[]> {
  return invokeCommand<Projects[]>('todo_project_list', {
    todoSerialNum,
  });
}
// ========================= 项目关联操作 End =========================

// ========================= 标签关联操作 Start =========================
export async function addTag(todoSerialNum: string, tagSerialNum: string): Promise<void> {
  await invokeCommand('todo_tag_add', {
    todoSerialNum,
    tagSerialNum,
  });
}

export async function removeTag(todoSerialNum: string, tagSerialNum: string): Promise<void> {
  await invokeCommand('todo_tag_remove', {
    todoSerialNum,
    tagSerialNum,
  });
}

export async function listTags(todoSerialNum: string): Promise<Tags[]> {
  return invokeCommand<Tags[]>('todo_tag_list', {
    todoSerialNum,
  });
}
// ========================= 标签关联操作 End =========================

// Legacy export for backward compatibility
export const TodoDb = {
  createTodo,
  getTodo,
  listTodo,
  updateTodo,
  toggleTodo,
  deleteTodo,
  listTodosPaged,
  listSubtasks,
  createSubtask,
  addProject,
  removeProject,
  listProjects,
  addTag,
  removeTag,
  listTags,
};
