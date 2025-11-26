<script setup lang="ts">
/**
 * Progress - 进度条组件
 *
 * 支持多种样式和动画效果
 * 100% Tailwind CSS 4
 */

import { computed } from 'vue';

interface Props {
  /** 当前值 (0-100) */
  value: number;
  /** 最大值 */
  max?: number;
  /** 尺寸 */
  size?: 'xs' | 'sm' | 'md' | 'lg';
  /** 颜色 */
  color?: 'primary' | 'success' | 'warning' | 'danger' | 'info';
  /** 是否显示文本 */
  showText?: boolean;
  /** 是否显示动画 */
  animated?: boolean;
  /** 是否为不确定状态 */
  indeterminate?: boolean;
}

const props = withDefaults(defineProps<Props>(), {
  max: 100,
  size: 'md',
  color: 'primary',
  showText: false,
  animated: false,
  indeterminate: false,
});

// 计算百分比
const percentage = computed(() => {
  if (props.indeterminate) return 0;
  return Math.min(100, Math.max(0, (props.value / props.max) * 100));
});

// 尺寸样式
const sizeClasses = {
  xs: 'h-1',
  sm: 'h-2',
  md: 'h-3',
  lg: 'h-4',
};

// 颜色样式
const colorClasses = {
  primary: 'bg-blue-600',
  success: 'bg-green-600',
  warning: 'bg-yellow-600',
  danger: 'bg-red-600',
  info: 'bg-cyan-600',
};
</script>

<template>
  <div>
    <div v-if="showText && !indeterminate" class="flex items-center justify-between mb-1">
      <span class="text-sm font-medium text-gray-700 dark:text-gray-300">
        进度
      </span>
      <span class="text-sm font-medium text-gray-700 dark:text-gray-300">
        {{ Math.round(percentage) }}%
      </span>
    </div>

    <div
      class="w-full overflow-hidden rounded-full bg-gray-200 dark:bg-gray-700" :class="[
        sizeClasses[size],
      ]"
    >
      <!-- 确定进度 -->
      <div
        v-if="!indeterminate"
        class="h-full transition-all duration-300 ease-out rounded-full" :class="[
          colorClasses[color],
          animated && 'animate-pulse',
        ]"
        :style="{ width: `${percentage}%` }"
      />

      <!-- 不确定进度 -->
      <div
        v-else
        class="h-full rounded-full animate-progress-indeterminate" :class="[
          colorClasses[color],
        ]"
        style="width: 40%"
      />
    </div>
  </div>
</template>

<style scoped>
@keyframes progress-indeterminate {
  0% {
    transform: translateX(-100%);
  }
  100% {
    transform: translateX(350%);
  }
}

.animate-progress-indeterminate {
  animation: progress-indeterminate 1.5s ease-in-out infinite;
}
</style>
