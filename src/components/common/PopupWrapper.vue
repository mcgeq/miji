<script setup lang="ts">
import { X } from 'lucide-vue-next';

const emit = defineEmits(['close']);
const onClose = () => emit('close');
</script>

<template>
  <Teleport to="body">
    <div
      class="fixed inset-0 flex items-center justify-center bg-black/40 z-[1000000]"
      @click.self="onClose"
    >
      <div class="relative w-[90vw] max-w-xl p-5 rounded-xl bg-white dark:bg-gray-900 text-gray-900 dark:text-gray-100 shadow-2xl transition-colors duration-300">
        <!-- 关闭按钮 -->
        <button
          class="absolute top-2 right-2 bg-transparent border-none cursor-pointer text-gray-500 hover:text-red-500 transition-colors duration-200"
          @click="onClose"
        >
          <X class="w-5 h-5" />
        </button>

        <!-- 插槽内容 -->
        <slot />
      </div>
    </div>
  </Teleport>
</template>

<style scoped>
/* 所有样式已使用 Tailwind CSS 4 */
</style>
