<!-- src/routes/todo/+page.svelte -->
<script lang="ts">
import TodoInput from '@/components/features/todos/TodoInput.svelte';
import TodoList from '@/components/features/todos/TodoList.svelte';
import { useTodos } from '@/lib/hooks/useTodos';
import type { Todo } from '@/lib/schema/todos';

const { addTodo, removeTodo, toggleTodo } = useTodos();

let newT = $state('');
let todos = $state([] as Todo[]);
</script>

<main class="max-w-xl mx-auto p-4">
  <!-- TodoInput 监听 add 事件 -->
  <TodoInput  bind:newT handleAdd={addTodo}/>

  <h1>{newT}</h1>
  <TodoList bind:todos onToggle={toggleTodo} onRemove={removeTodo}/>
</main>
