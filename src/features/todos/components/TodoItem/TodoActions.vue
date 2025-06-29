<template>
  <div v-if="show" class="flex items-center gap-3">
    <button
      type="button"
      :disabled="completed"
      aria-label="Edit task"
      class="transition text-gray-400 hover:text-blue-500 disabled:text-gray-300 disabled:cursor-not-allowed"
      @click="emit('edit')"
    >
      <Pencil class="w-4 h-4" />
      <span class="sr-only">Edit</span>
    </button>
    <button
      type="button"
      aria-label="Add task"
      class="transition text-blue-500 hover:text-blue-700"
      @click="emit('add')"
    >
      <Plus class="w-5 h-5" />
      <span class="sr-only">Add</span>
    </button>
    <button
      type="button"
      :disabled="completed"
      aria-label="Delete task"
      class="transition text-red-400 hover:text-red-600 disabled:text-gray-300 disabled:cursor-not-allowed"
      @click="emit('remove')"
    >
      <Trash2 class="w-5 h-5" />
      <span class="sr-only">Delete</span>
    </button>
  </div>
</template>

<script setup lang="ts">
import { Pencil, Plus, Trash2 } from 'lucide-vue-next';

const props = defineProps<{ show: boolean; completed: boolean }>();
const emit = defineEmits(['edit', 'add', 'remove']);

const show = computed(() => props.show);
const completed = computed(() => props.completed);
</script>
