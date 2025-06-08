// src/lib/api/todos.ts
import type { Todo } from '@/types';
import { invoke } from '@tauri-apps/api/core';

export async function getTodos(): Promise<Todo[]> {
  return await invoke('get_todos');
}

export async function createTodo(todo: Omit<Todo, 'id'>): Promise<Todo> {
  return await invoke('create_todo', { todo });
}
