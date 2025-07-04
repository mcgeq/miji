<template>
  <div
    class="fixed inset-0 z-50 bg-black/40 flex items-center justify-center"
    @click.self="onClose"
  >
    <div class="bg-white dark:bg-gray-900 rounded-xl p-5 w-[90vw] max-w-xl shadow-xl relative">
      <!-- 关闭按钮 -->
      <button
        class="absolute top-2 right-2 text-gray-500 hover:text-red-500"
        @click="onClose"
      >
        ✕
      </button>

      <!-- 插槽用于嵌入内容页面 -->
      <slot />
    </div>
  </div>
</template>

<script setup lang="ts">
const emit = defineEmits(['close']);
const onClose = () => emit('close');
</script>
