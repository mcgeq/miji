<template>
  <TodoView />
</template>

<script setup lang="ts">
import TodoView from '@/features/todos/views/TodoView.vue';

definePage({
  name: 'todos',
  meta: {
    requiresAuth: true,
  },
});
</script>
