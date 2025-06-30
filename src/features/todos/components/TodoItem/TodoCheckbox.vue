<template>
  <button
    type="button"
    class="flex items-center focus:outline-none"
    :aria-pressed="completed"
    :disabled="completed"
    @click="emit('toggle')"
  >
    <CheckCircle v-if="completed" class="wh-5 text-green-500" />
    <Circle v-else class="wh-5 text-gray-400" />
  </button>
</template>

<script setup lang="ts">
import { CheckCircle, Circle } from 'lucide-vue-next';

const props = defineProps<{ completed: boolean }>();
const emit = defineEmits(['toggle']);
const completed = computed(() => props.completed);
</script>
