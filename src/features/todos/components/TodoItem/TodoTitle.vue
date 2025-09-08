<script setup lang="ts">
const props = defineProps<{ title: string; completed: boolean }>();
const emit = defineEmits(['toggle']);

const title = computed(() => props.title);
const completed = computed(() => props.completed);
</script>

<template>
  <span
    class="text-sm leading-snug text-left line-clamp-1"
    :class="{ 'text-gray-400': completed }"
    :title="title"
    @click="emit('toggle')"
  >
    {{ title }}
  </span>
</template>
