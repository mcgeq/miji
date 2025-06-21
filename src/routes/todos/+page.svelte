<!-- src/routes/todo/+page.svelte -->
<script lang="ts">
import TodoInput from '@/components/features/todos/TodoInput.svelte';
import TodoList from '@/components/features/todos/TodoList.svelte';
import type { Priority } from '@/lib/schema/common';
import type { Todo } from '@/lib/schema/todos';
import {
  startGlobalTimer,
  stopGlobalTimer,
  todoStore,
} from '@/lib/stores/todos.svelte';
import { onDestroy, onMount } from 'svelte';
import { SvelteMap } from 'svelte/reactivity';

let newT = $state('');
let todos = $state(new SvelteMap<string, Todo>());

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

const handleChangePriority = (serialNum: string, priority: Priority) => {
  todoStore.changePriority(serialNum, priority);
};

onMount(async () => {
  todos = await todoStore.getTodosRemainingTime();
  startGlobalTimer();
});

onDestroy(() => {
  stopGlobalTimer();
});
</script>

<main class="max-w-xl mx-auto p-4">
  <TodoInput bind:newT handleAdd={handleAdd} />
  <TodoList {todos} onToggle={handleToggle} onRemove={handleRemove} onEdit={handleEdit} onChangePriority={handleChangePriority}/>
</main>
