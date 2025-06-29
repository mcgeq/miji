<template>
  <span
    class="text-left text-sm leading-snug line-clamp-1"
    :class="{ 'text-gray-400': completed }"
    :title="title"
    @click="emit('toggle')"
  >
    {{ title }}
  </span>
</template>

<script setup lang="ts">
import { defineProps, defineEmits } from 'vue';

const props = defineProps<{ title: string; completed: boolean }>();
const emit = defineEmits(['toggle']);

const title = computed(() => props.title);
const completed = computed(() => props.completed);
</script>
