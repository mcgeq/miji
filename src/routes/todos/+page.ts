// src/routes/todo/+page.ts
import { getTodos } from '$lib/api/todos';
import type { Todo } from '@/types';
import type { PageLoad } from './$types';

export const load: PageLoad = async () => {
  try {
    const todos: Todo[] = await getTodos();
    return { todos };
  } catch (error) {
    return { todos: [], error: 'Failed to load todos' };
  }
};
