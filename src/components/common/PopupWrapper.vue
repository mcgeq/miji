<script setup lang="ts">
import { X } from 'lucide-vue-next';

const emit = defineEmits(['close']);
const onClose = () => emit('close');
</script>

<template>
  <div
    class="bg-black/40 flex items-center inset-0 justify-center fixed z-50"
    @click.self="onClose"
  >
    <div class="p-5 rounded-xl bg-white max-w-xl w-[90vw] shadow-xl relative dark:bg-gray-900">
      <!-- 关闭按钮 -->
      <button
        class="text-gray-500 right-2 top-2 absolute hover:text-red-500"
        @click="onClose"
      >
        <X class="wh-5" />
      </button>

      <!-- 插槽用于嵌入内容页面 -->
      <slot />
    </div>
  </div>
</template>
