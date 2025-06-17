<!-- src/routes/todo/+page.svelte -->
<script lang="ts">
import TodoInput from '@/components/features/todos/TodoInput.svelte';
import TodoList from '@/components/features/todos/TodoList.svelte';
import { useTodos } from '@/lib/hooks/useTodos';
import type { Todo } from '@/lib/schema/todos';

const { addTodo, removeTodo, toggleTodo } = useTodos();

let newT = $state('');
let todos = $state([] as Todo[]);

function handleAdd(text: string) {
  if (text.trim()) {
    todos = addTodo(todos, text);
    newT = '';
  }
}
const handleToggle = (serial_num: string) => {
  todos = toggleTodo(todos, serial_num);
};

const handleRemove = (serial_num: string) => {
  todos = removeTodo(todos, serial_num);
};
</script>

<main class="max-w-xl mx-auto p-4">
  <!-- TodoInput 监听 add 事件 -->
  <TodoInput  bind:newT handleAdd={handleAdd}/>

  <TodoList bind:todos onToggle={handleToggle} onRemove={handleRemove}/>
</main>
