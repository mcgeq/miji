<script setup lang="ts">
import { X } from 'lucide-vue-next';

const emit = defineEmits(['close']);
const onClose = () => emit('close');
</script>

<template>
  <div class="modal-backdrop" @click.self="onClose">
    <div class="modal">
      <!-- 关闭按钮 -->
      <button class="modal-close" @click="onClose">
        <X class="icon" />
      </button>

      <!-- 插槽内容 -->
      <slot />
    </div>
  </div>
</template>

<style scoped lang="postcss">
/* 遮罩层 */
.modal-backdrop {
  position: fixed;
  inset: 0; /* top/right/bottom/left = 0 */
  display: flex;
  align-items: center;
  justify-content: center;
  background-color: rgba(0, 0, 0, 0.4); /* bg-black/40 */
  z-index: 50;
}

/* 内容容器 */
.modal {
  position: relative;
  width: 90vw;
  max-width: 36rem; /* 576px ≈ max-w-xl */
  padding: 1.25rem; /* 20px */
  border-radius: 0.75rem; /* 12px */
  background: var(--color-base-100, #fff);
  color: var(--color-base-content, #111);
  box-shadow: 0 10px 25px rgba(0, 0, 0, 0.25); /* shadow-xl */
  transition: background-color 0.3s ease, color 0.3s ease;
}

/* 深色模式 */
@media (prefers-color-scheme: dark) {
  .modal {
    background: var(--color-base-200, #111827); /* dark:bg-gray-900 */
    color: var(--color-base-content, #e5e7eb);
  }
}

/* 关闭按钮 */
.modal-close {
  position: absolute;
  top: 0.5rem; /* 8px */
  right: 0.5rem;
  background: none;
  border: none;
  cursor: pointer;
  color: #6b7280; /* text-gray-500 */
  transition: color 0.2s ease-in-out;
}
.modal-close:hover {
  color: #ef4444; /* hover:text-red-500 */
}

/* 图标 */
.icon {
  width: 1.25rem;  /* 20px */
  height: 1.25rem;
}
</style>
