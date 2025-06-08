// src/routes/api/todos/+server.ts
import { json } from '@sveltejs/kit';
import { getTodos, createTodo } from '$lib/api/todos';
import type { RequestHandler } from '@sveltejs/kit';
import type { Todo } from '@/types';

export const GET: RequestHandler = async () => {
  try {
    const todos: Todo[] = await getTodos();
    return json(todos);
  } catch (error) {
    return json({ error: 'Failed to fetch todos' }, { status: 500 });
  }
};

export const POST: RequestHandler = async ({ request }) => {
  try {
    const data = (await request.json()) as Omit<Todo, 'id'>;
    const newTodo = await createTodo(data);
    return json(newTodo, { status: 201 });
  } catch (error) {
    return json({ error: 'Failed to create todo' }, { status: 400 });
  }
};
