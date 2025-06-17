<!-- src/components/TodoList.svelte -->

<script lang="ts">
import type { Todo } from '@/lib/schema/todos';
import TodoItem from './TodoItem.svelte';
import { slideFade } from '@/lib/animations/slideFade';

let {
  todos = $bindable([] as Todo[]),
  onToggle = () => {},
  onRemove = () => {},
} = $props<import('@/types/todos').TodoListProps>();
</script>


<div class="mt-4 bg-white rounded-lg shadow">
  {#each todos as todo (todo.serial_num)}
    <div in:slideFade={{}} out:slideFade={{}}>
      <TodoItem
        serial_num={todo.serial_num.toString()}
        text={todo.title}
        completed={todo.status === 'Completed'}
        onToggle={() => onToggle(todo.serial_num.toString())}
        onRemove={() => onRemove(todo.serial_num.toString())}
      />
    </div>
  {/each}
</div>
