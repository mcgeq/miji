<!-- src/components/TodoList.vue -->
<script setup lang="ts">
import { computed, toRaw } from 'vue';
import TodoItem from './TodoItem.vue';
import { TodoRemain } from '@/schema/todos';

// 定义 Props 类型
const props = defineProps<{
  todos: Map<string, TodoRemain>;
}>();

// 定义事件
const emit = defineEmits<{
  (e: 'toggle', serialNum: string): void;
  (e: 'remove', serialNum: string): void;
  (e: 'edit', serialNum: string, todo: TodoRemain): void;
  (e: 'changePriority', ...args: any[]): void;
}>();

// 转成数组，便于遍历
const todoList = computed(() => {
  const rawTodos = toRaw(props.todos);
  if (!(rawTodos instanceof Map)) {
    console.warn('props.todos is not a Map!', rawTodos);
    return [];
  }
  return Array.from(rawTodos.values());
});
// 示例动画钩子（Vue TransitionGroup 或其他动画方案）
</script>

<template>
  <div class="mt-4 bg-white rounded-lg shadow">
    <transition-group name="slide-fade" tag="div">
      <TodoItem
        v-for="todo in todoList"
        :key="todo.serialNum"
        :serialNum="todo.serialNum.toString()"
        :todo="todo"
        @toggle="() => emit('toggle', todo.serialNum.toString())"
        @remove="() => emit('remove', todo.serialNum.toString())"
        @edit="() => emit('edit', todo.serialNum, todo)"
        @changePriority="emit('changePriority', $event)"
      />
    </transition-group>
  </div>
</template>

<style scoped>
/* 简单实现 slide-fade 动画 */
.slide-fade-enter-active,
.slide-fade-leave-active {
  transition: all 0.3s ease;
}
.slide-fade-enter-from,
.slide-fade-leave-to {
  opacity: 0;
  transform: translateY(10px);
}
</style>
