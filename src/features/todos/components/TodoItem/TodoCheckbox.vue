<script setup lang="ts">
import { CheckCircle, Circle } from 'lucide-vue-next';

const props = defineProps<{ completed: boolean }>();
const emit = defineEmits(['toggle']);
const completed = computed(() => props.completed);
</script>

<template>
  <button
    type="button"
    class="flex items-center focus:outline-none"
    :aria-pressed="completed"
    :disabled="completed"
    @click="emit('toggle')"
  >
    <CheckCircle v-if="completed" class="text-green-500 wh-5" />
    <Circle v-else class="text-gray-400 wh-5" />
  </button>
</template>
