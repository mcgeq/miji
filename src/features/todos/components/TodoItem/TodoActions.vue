<script setup lang="ts">
  import { Pencil, Plus, Trash2 } from 'lucide-vue-next';

  const props = defineProps<{ show: boolean; completed: boolean }>();
  const emit = defineEmits(['edit', 'add', 'remove']);

  const show = computed(() => props.show);
  const completed = computed(() => props.completed);
</script>

<template>
  <div v-if="show" class="flex gap-3 items-center">
    <!-- 编辑按钮：只在未完成时显示 -->
    <button
      v-if="!completed"
      type="button"
      aria-label="Edit task"
      class="inline-flex items-center justify-center bg-transparent border-none p-1 rounded-lg cursor-pointer transition-all duration-200 outline-none hover:not-disabled:scale-110 focus:not-disabled:scale-110 disabled:cursor-not-allowed disabled:opacity-50 text-neutral hover:not-disabled:text-primary dark:text-neutral dark:hover:not-disabled:text-primary"
      @click="emit('edit')"
    >
      <Pencil class="w-5 h-5 transition-all duration-200" />
    </button>

    <!-- 添加按钮：始终显示 -->
    <button
      type="button"
      aria-label="Add task"
      class="inline-flex items-center justify-center bg-transparent border-none p-1 rounded-lg cursor-pointer transition-all duration-200 outline-none hover:not-disabled:scale-110 focus:not-disabled:scale-110 disabled:cursor-not-allowed disabled:opacity-50 text-primary hover:not-disabled:text-primary-hover dark:text-primary dark:hover:not-disabled:text-primary-hover"
      @click="emit('add')"
    >
      <Plus class="w-5 h-5 transition-all duration-200" />
    </button>

    <!-- 删除按钮：只在未完成时显示 -->
    <button
      v-if="!completed"
      type="button"
      aria-label="Delete task"
      class="inline-flex items-center justify-center bg-transparent border-none p-1 rounded-lg cursor-pointer transition-all duration-200 outline-none hover:not-disabled:scale-110 focus:not-disabled:scale-110 disabled:cursor-not-allowed disabled:opacity-50 text-error hover:not-disabled:text-error-hover dark:text-error dark:hover:not-disabled:text-error-hover"
      @click="emit('remove')"
    >
      <Trash2 class="w-5 h-5 transition-all duration-200" />
    </button>
  </div>
</template>
