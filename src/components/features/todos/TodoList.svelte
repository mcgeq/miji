<!-- src/components/TodoList.svelte -->

<script lang="ts">
import type { Todo } from '@/lib/schema/todos';
import TodoItem from './TodoItem.svelte';
import { slideFade } from '@/lib/animations/slideFade';
import { Lg } from '@/lib/utils/debugLog';

let {
  todos = $bindable([] as Todo[]),
  onToggle = () => {},
  onRemove = () => {},
  onEdit = () => {},
} = $props<import('@/types/todos').TodoListProps>();
Lg.i('TodoList', todos);
</script>


<div class="mt-4 bg-white rounded-lg shadow">
  {#each todos as todo (todo.serialNum)}
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
