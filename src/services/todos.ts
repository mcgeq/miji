import type { Tags } from '@/schema/tags';
import type { Projects } from '@/schema/todos';
import { invokeCommand } from '@/types/api';

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
