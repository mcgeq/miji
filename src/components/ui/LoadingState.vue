<script setup lang="ts">
/**
 * LoadingState - 加载状态组件
 *
 * 用于显示数据加载中的友好提示
 * 100% Tailwind CSS 4
 */

import Spinner from './Spinner.vue';

interface Props {
  /** 加载提示文本 */
  message?: string;
  /** Spinner 大小 */
  size?: 'sm' | 'md' | 'lg' | 'xl';
}

withDefaults(defineProps<Props>(), {
  message: '加载中...',
  size: 'lg',
});
</script>

<template>
  <div class="flex flex-col items-center gap-4 py-16 text-center text-gray-500 dark:text-gray-400 bg-gradient-to-b from-white to-gray-50 dark:from-gray-800 dark:to-gray-900 rounded-lg border-2 border-gray-200 dark:border-gray-700 my-4">
    <!-- 加载动画 -->
    <Spinner :size="size" />

    <!-- 加载提示文本 -->
    <span>{{ message }}</span>
  </div>
</template>
