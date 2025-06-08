<!-- src/routes/todo/+page.svelte -->
<script lang="ts">
import { getTodos, createTodo } from '$lib/api/todos';
import type { Todo } from '@/types';
import type { PageData } from './$types';

export let data: PageData;
let todos: Todo[] = data.todos;
let newTodo = '';

async function addTodo() {
  if (newTodo) {
    await createTodo({ title: newTodo, completed: false });
    todos = await getTodos();
    newTodo = '';
  }
}
</script>

<h1>Todos</h1>
<input type="text" bind:value={newTodo} placeholder="New todo" />
<button on:click={addTodo}>Add</button>
<ul>
  {#each todos as todo}
    <li>{todo.title} - {todo.completed ? 'Done' : 'Pending'}</li>
  {/each}
</ul>
