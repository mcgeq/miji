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

  display: -webkit-box;
  display: box; /* 旧标准，部分兼容 */
  -webkit-box-orient: vertical;
  box-orient: vertical;

  -webkit-line-clamp: 1; /* WebKit 浏览器支持 */
  line-clamp: 1; /* 标准属性，PostCSS 会加前缀 */

  overflow: hidden;
  text-overflow: ellipsis;

  cursor: pointer;
  color: var(--color-base-content, #374151); /* 默认文字色 */
  transition: color 0.2s ease;
}

.todo-title-completed {
  color: var(--color-neutral-content, #9ca3af);
}
</style>
