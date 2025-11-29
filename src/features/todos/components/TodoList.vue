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

const todoList = computed(() => Array.from(props.todos.values()));

function updateTodo(serialNum: string, updated: TodoUpdate) {
  emit('edit', serialNum, updated);
}
</script>

<template>
  <div class="flex flex-col gap-2 p-1 w-full max-w-full box-border overflow-hidden">
    <TodoItem
      v-for="todo in todoList"
      :key="todo.serialNum"
      :todo="todo"
      @update:todo="updateTodo"
      @toggle="() => emit('toggle', todo.serialNum, StatusSchema.enum.Completed)"
      @remove="() => emit('remove', todo.serialNum)"
    />
  </div>
</template>
