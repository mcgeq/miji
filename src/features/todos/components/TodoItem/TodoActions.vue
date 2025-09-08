<script setup lang="ts">
import { Pencil, Plus, Trash2 } from 'lucide-vue-next';

const props = defineProps<{ show: boolean; completed: boolean }>();
const emit = defineEmits(['edit', 'add', 'remove']);

const show = computed(() => props.show);
const completed = computed(() => props.completed);
</script>

<template>
  <div v-if="show" class="flex gap-3 items-center">
    <button
      type="button"
      :disabled="completed"
      aria-label="Edit task"
      class="action-btn text-gray-400 hover:text-blue-500"
      @click="emit('edit')"
    >
      <Pencil class="h-4 w-4" />
      <span class="sr-only">Edit</span>
    </button>
    <button
      type="button"
      aria-label="Add task"
      class="text-blue-500 transition hover:text-blue-700"
      @click="emit('add')"
    >
      <Plus class="wh-5" />
      <span class="sr-only">Add</span>
    </button>
    <button
      type="button"
      :disabled="completed"
      aria-label="Delete task"
      class="action-btn text-red-400 hover:text-red-600"
      @click="emit('remove')"
    >
      <Trash2 class="wh-5" />
      <span class="sr-only">Delete</span>
    </button>
  </div>
</template>

<style scoped lang="postcss">
.action-btn {
  @apply transition  disabled:text-gray-300 disabled:cursor-not-allowed
}
</style>
