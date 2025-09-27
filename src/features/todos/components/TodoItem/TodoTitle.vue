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
  font-size: 0.875rem; /* text-sm */
  line-height: 1.375rem; /* snug */
  text-align: left;

  display: block; /* 或 inline-block，根据需求 */
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap; /* 单行省略 */

  cursor: pointer;
  color: var(--color-base-content, #374151); /* 默认文字色 */
  transition: color 0.2s ease;
}

.todo-title-completed {
  color: var(--color-neutral-content, #9ca3af);
}
</style>
