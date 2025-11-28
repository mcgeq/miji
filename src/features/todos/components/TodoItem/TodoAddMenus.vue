<script setup lang="ts">
import { Folder, StickyNote, Tag, X } from 'lucide-vue-next';
import { Modal } from '@/components/ui';

defineProps<{ show: boolean }>();
const emit = defineEmits(['openPopup', 'close']);
</script>

<template>
  <Modal
    :open="show"
    size="sm"
    :show-header="false"
    :show-footer="false"
    @close="emit('close')"
  >
    <div class="flex flex-col gap-3 -mx-6 -my-4 px-4 py-4">
      <!-- 描述按钮 -->
      <button
        class="w-full rounded-xl px-4 py-3 bg-white dark:bg-gray-800 text-gray-700 dark:text-gray-200 flex items-center justify-center gap-3 transition-all duration-200 border border-gray-200 dark:border-gray-700 shadow-sm hover:bg-gray-50 dark:hover:bg-gray-700 hover:border-blue-500 dark:hover:border-blue-400 hover:text-blue-600 dark:hover:text-blue-400 hover:-translate-y-0.5 hover:shadow-md active:translate-y-0"
        @click="emit('openPopup', 'description')"
      >
        <StickyNote class="w-5 h-5" />
        <span class="text-sm font-medium">描述</span>
      </button>

      <!-- 标签按钮 -->
      <button
        class="w-full rounded-xl px-4 py-3 bg-white dark:bg-gray-800 text-gray-700 dark:text-gray-200 flex items-center justify-center gap-3 transition-all duration-200 border border-gray-200 dark:border-gray-700 shadow-sm hover:bg-gray-50 dark:hover:bg-gray-700 hover:border-blue-500 dark:hover:border-blue-400 hover:text-blue-600 dark:hover:text-blue-400 hover:-translate-y-0.5 hover:shadow-md active:translate-y-0"
        @click="emit('openPopup', 'tags')"
      >
        <Tag class="w-5 h-5" />
        <span class="text-sm font-medium">标签</span>
      </button>

      <!-- 项目按钮 -->
      <button
        class="w-full rounded-xl px-4 py-3 bg-white dark:bg-gray-800 text-gray-700 dark:text-gray-200 flex items-center justify-center gap-3 transition-all duration-200 border border-gray-200 dark:border-gray-700 shadow-sm hover:bg-gray-50 dark:hover:bg-gray-700 hover:border-blue-500 dark:hover:border-blue-400 hover:text-blue-600 dark:hover:text-blue-400 hover:-translate-y-0.5 hover:shadow-md active:translate-y-0"
        @click="emit('openPopup', 'projects')"
      >
        <Folder class="w-5 h-5" />
        <span class="text-sm font-medium">项目</span>
      </button>

      <!-- 关闭按钮 -->
      <button
        class="w-full rounded-xl px-4 py-3 bg-white dark:bg-gray-800 text-gray-700 dark:text-gray-200 flex items-center justify-center gap-3 transition-all duration-200 border border-gray-200 dark:border-gray-700 shadow-sm hover:bg-gray-50 dark:hover:bg-gray-700 hover:border-red-500 dark:hover:border-red-400 hover:text-red-600 dark:hover:text-red-400 hover:-translate-y-0.5 hover:shadow-md active:translate-y-0"
        @click="emit('close')"
      >
        <X class="w-4 h-4" />
        <span class="text-sm font-medium">关闭</span>
      </button>
    </div>
  </Modal>
</template>

<style scoped>
/* 所有样式已使用 Tailwind CSS 4 */
</style>
