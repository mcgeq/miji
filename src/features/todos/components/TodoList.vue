<!-- src/components/TodoList.vue -->
<script setup lang="ts">
import { StatusSchema } from '@/schema/common';
import TodoItem from './TodoItem/TodoItem.vue';
import type { Status } from '@/schema/common';
import type { Todo, TodoUpdate } from '@/schema/todos';

const props = defineProps<{
  todos: Map<string, Todo>;
}>();

const emit = defineEmits<{
  (e: 'toggle', serialNum: string, status: Status): void;
  (e: 'remove', serialNum: string): void;
  (e: 'edit', serialNum: string, todo: TodoUpdate): void;
}>();

// 直接转换Map为数组用于渲染
const todoList = computed(() => Array.from(props.todos.values()));

// 更新 Map 中的某条 todo，响应式生效
function updateTodo(serialNum, updated: TodoUpdate) {
  props.todos.set(serialNum, updated);
  emit('edit', serialNum, updated);
}
</script>

<template>
  <div class="todolist-main">
    <TodoItem
      v-for="todo in todoList"
      :key="todo.serialNum"
      :todo="todo"
      @update:todo="updateTodo(todo.serialNum, todo)"
      @toggle="() => emit('toggle', todo.serialNum, StatusSchema.enum.Completed)"
      @remove="() => emit('remove', todo.serialNum)"
      @edit="() => emit('edit', todo.serialNum, todo)"
    />
  </div>
</template>

<style scoped>
.todolist-main {
  -webkit-margin-top: 1rem;
  margin-top: 1rem;
  margin-top: 1rem;
  border-radius: 0.5rem;
  background-color: #ffffff;
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.1);
}

.slide-fade-enter-active,
.slide-fade-leave-active {
  transition: opacity 0.5s ease, transform 0.5s ease;
  will-change: opacity, transform;
}

.slide-fade-enter-from,
.slide-fade-leave-to {
  opacity: 0;
  transform: translateX(-20px); /* 从左侧滑入/滑出 */
}
</style>
