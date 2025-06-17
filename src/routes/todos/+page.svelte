<!-- src/routes/todo/+page.svelte -->
<script lang="ts">
import TodoInput from '@/components/features/todos/TodoInput.svelte';
import TodoList from '@/components/features/todos/TodoList.svelte';
import { todoStore, todos } from '@/lib/stores/todos';

let newT = $state('');

function handleAdd(text: string) {
  if (text.trim()) {
    todoStore.addTodo(text);
    newT = '';
  }
}

const handleToggle = (serial_num: string) => {
  todoStore.toggleTodo(serial_num);
};

const handleRemove = (serial_num: string) => {
  todoStore.removeTodo(serial_num);
};
</script>

<main class="max-w-xl mx-auto p-4">
  <TodoInput bind:newT handleAdd={handleAdd} />
  <TodoList todos={$todos} onToggle={handleToggle} onRemove={handleRemove} />
</main>
