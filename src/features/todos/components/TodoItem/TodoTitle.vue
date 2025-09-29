<script setup lang="ts">
const props = defineProps<{ title: string; completed: boolean }>();
const emit = defineEmits(['toggle']);

const title = computed(() => props.title);
const completed = computed(() => props.completed);
</script>

<template>
  <span
    class="todo-title"
    :class="{ 'todo-title-completed': completed }"
    :title="title"
    @click="emit('toggle')"
  >
    {{ title }}
  </span>
</template>

<style scoped lang="postcss">
.todo-title {
  font-size: 0.875rem;
  line-height: 1.375rem;
  text-align: left;
  display: block;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  cursor: pointer;
  color: var(--color-neutral);
  transition: color 0.2s ease;
}

.todo-title-completed {
  color: var(--color-secondary-content, #9ca3af);
}
</style>
