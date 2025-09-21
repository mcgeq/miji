<!-- src/components/FloatingErrorTip.vue -->
<script setup lang="ts">
defineProps<{
  message?: string;
  visible?: boolean;
}>();
</script>

<template>
  <div
    v-if="visible && message"
    class="floating-error-tip"
  >
    {{ message }}
  </div>
</template>

<style scoped>
/* 错误提示浮层核心样式 */
.floating-error-tip {
  /* 定位相关 */
  position: absolute;
  top: 50%;          /* 相对于父容器垂直居中 */
  right: 0.125rem;   /* 右侧距离父容器 2px（原 right-2） */
  transform: translateY(-50%);  /* 向上偏移自身高度的 50% 实现垂直居中（原 -translate-y-1/2） */
  z-index: 10;       /* 确保显示在输入框上方（原 z-10） */

  /* 文字样式 */
  font-size: 0.75rem; /* 原 text-xs（12px） */
  color: #ef4444;     /* 原 text-red-500（红色系主色） */
  white-space: nowrap; /* 禁止换行（原 whitespace-nowrap） */
  pointer-events: none; /* 禁止鼠标交互（原 pointer-events-none） */
  user-select: none;    /* 禁止文本选中（原 select-none） */
}
</style>
