<script setup lang="ts">
import { X } from 'lucide-vue-next';

const emit = defineEmits(['close']);
const onClose = () => emit('close');
</script>

<template>
  <div
    class="fixed inset-0 z-50 flex items-center justify-center bg-black/40"
    @click.self="onClose"
  >
    <div class="relative max-w-xl w-[90vw] rounded-xl bg-white p-5 shadow-xl dark:bg-gray-900">
      <!-- 关闭按钮 -->
      <button
        class="absolute right-2 top-2 text-gray-500 hover:text-red-500"
        @click="onClose"
      >
        <X class="wh-5" />
      </button>

      <!-- 插槽用于嵌入内容页面 -->
      <slot />
    </div>
  </div>
</template>
