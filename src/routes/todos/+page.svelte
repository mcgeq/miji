<!-- src/routes/todo/+page.svelte -->
<script lang="ts">
import TodoInput from '@/components/features/todos/TodoInput.svelte';
import TodoList from '@/components/features/todos/TodoList.svelte';
import type { Todo } from '@/lib/schema/todos';
import { todoStore, todos } from '@/lib/stores/todos';

let newT = $state('');

function handleAdd(text: string) {
  if (text.trim()) {
    todoStore.addTodo(text);
    newT = '';
  }
}

const handleToggle = (serialNum: string) => {
  todoStore.toggleTodo(serialNum);
};

const handleRemove = (serialNum: string) => {
  todoStore.removeTodo(serialNum);
};

const handleEdit = (serialNum: string, todo: Todo) => {
  todoStore.editTodo(serialNum, todo);
};
</script>

<main class="max-w-xl mx-auto p-4">
  <TodoInput bind:newT handleAdd={handleAdd} />
  <TodoList todos={$todos} onToggle={handleToggle} onRemove={handleRemove} onEdit={handleEdit}/>
</main>
