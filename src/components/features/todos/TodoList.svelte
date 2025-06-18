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
  {#each todos as todo (todo.serial_num)}
    <div in:slideFade={{}} out:slideFade={{}}>
      <TodoItem
        serial_num={todo.serial_num.toString()}
        text={todo.title}
        completed={todo.status === 'Completed'}
        dueAt={todo.due_at}
        onToggle={() => onToggle(todo.serial_num.toString())}
        onRemove={() => onRemove(todo.serial_num.toString())}
        onEdit={() => onEdit()}
      />
    </div>
  {/each}
</div>
