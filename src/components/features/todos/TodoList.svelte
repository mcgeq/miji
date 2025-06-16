<!-- src/components/TodoList.svelte -->

<script lang="ts">
import type { Todo } from '@/lib/schema/todos';
import TodoItem from './TodoItem.svelte';
import type { TodoListEvents } from '@/types/events';

export let todos: Todo[] = [];

export let dispatch: <K extends keyof TodoListEvents>(
  type: K,
  detail: TodoListEvents[K],
) => void;

const handleToggle = (e: CustomEvent<TodoListEvents['toggle']>) =>
  dispatch('toggle', e.detail);

const handleRemove = (e: CustomEvent<TodoListEvents['remove']>) =>
  dispatch('remove', e.detail);
</script>

<div class="mt-4 bg-white rounded-lg shadow">
  {#each todos as todo (todo.serial_num)}
    <TodoItem
      serial_num={todo.serial_num.toString()}
      text={todo.title}
      completed={todo.status === 'Completed'}
      on:toggle={handleToggle}
      on:remove={handleRemove}
    />
  {/each}
</div>
