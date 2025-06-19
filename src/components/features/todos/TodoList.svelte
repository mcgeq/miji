<!-- src/components/TodoList.svelte -->
<script lang="ts">
import type { Todo } from '@/lib/schema/todos';
import TodoItem from './TodoItem.svelte';
import { slideFade } from '@/lib/animations/slideFade';

let {
  todos = $bindable(new Map<string, Todo>()),
  onToggle = () => {},
  onRemove = () => {},
  onEdit = () => {},
} = $props<import('@/types/todos').TodoListProps>();
</script>


<div class="mt-4 bg-white rounded-lg shadow">
  {#each todos.values() as todo (todo.serialNum)}
    <div in:slideFade={{}} out:slideFade={{}}>
      <TodoItem
        serialNum={todo.serialNum.toString()}
        todo={todo}
        onToggle={() => onToggle(todo.serialNum.toString())}
        onRemove={() => onRemove(todo.serialNum.toString())}
        onEdit={() => onEdit()}
      />
    </div>
  {/each}
</div>
