<!-- src/components/TodoList.vue -->
<template>
  <div class="mt-4 bg-white rounded-lg shadow">
      <TodoItem
        v-for="todo in todoList"
        :key="todo.serialNum"
        :todo="todo"
        @update:todo="updateTodo"
        @toggle="() => emit('toggle', todo.serialNum)"
        @remove="() => emit('remove', todo.serialNum)"
        @edit="() => emit('edit', todo.serialNum, todo)"
      />
  </div>
</template>

<script setup lang="ts">
import type { TodoRemain } from '@/schema/todos';
import TodoItem from './TodoItem/TodoItem.vue';

const props = defineProps<{
  todos: Map<string, TodoRemain>;
}>();

const emit = defineEmits<{
  (e: 'toggle', serialNum: string): void;
  (e: 'remove', serialNum: string): void;
  (e: 'edit', serialNum: string, todo: TodoRemain): void;
}>();

// 直接转换Map为数组用于渲染
const todoList = computed(() => Array.from(props.todos.values()));

// 更新 Map 中的某条 todo，响应式生效
function updateTodo(updated: TodoRemain) {
  props.todos.set(updated.serialNum, updated);
  emit('edit', updated.serialNum, updated);
}
</script>

<style scoped>
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
