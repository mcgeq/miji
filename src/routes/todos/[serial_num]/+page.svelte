<!-- src/routes/todo/[id]/+page.svelte -->
<script lang="ts">
import type { Todo } from '@/types';
import type { PageData } from './$types';

export let data: PageData;
$: todo = data.todo as Todo | undefined;
$: error = data.error as string | undefined;
</script>

{#if error}
  <p>{error}</p>
{:else if todo}
  <h1>{todo.title}</h1>
  <p>Status: {todo.completed ? 'Completed' : 'Pending'}</p>
{:else}
  <p>Loading...</p>
{/if}
