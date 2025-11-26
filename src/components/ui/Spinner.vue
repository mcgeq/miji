<script setup lang="ts">
/**
 * Spinner - 加载动画组件
 *
 * 多种样式的加载动画
 * 100% Tailwind CSS 4
 */

interface Props {
  /** 尺寸 */
  size?: 'xs' | 'sm' | 'md' | 'lg' | 'xl';
  /** 颜色 */
  color?: 'primary' | 'white' | 'gray' | 'success' | 'warning' | 'danger';
  /** 样式 */
  variant?: 'spin' | 'dots' | 'pulse';
  /** 是否居中 */
  center?: boolean;
  /** 加载文本 */
  text?: string;
}

withDefaults(defineProps<Props>(), {
  size: 'md',
  color: 'primary',
  variant: 'spin',
  center: false,
});

// 尺寸映射
const sizeClasses = {
  xs: 'w-4 h-4',
  sm: 'w-6 h-6',
  md: 'w-8 h-8',
  lg: 'w-10 h-10',
  xl: 'w-12 h-12',
};

// 颜色映射
const colorClasses = {
  primary: 'text-blue-600 dark:text-blue-400',
  white: 'text-white',
  gray: 'text-gray-600 dark:text-gray-400',
  success: 'text-green-600 dark:text-green-400',
  warning: 'text-yellow-600 dark:text-yellow-400',
  danger: 'text-red-600 dark:text-red-400',
};

// 点的尺寸
const dotSizes = {
  xs: 'w-1.5 h-1.5',
  sm: 'w-2 h-2',
  md: 'w-2.5 h-2.5',
  lg: 'w-3 h-3',
  xl: 'w-4 h-4',
};
</script>

<template>
  <div
    class="inline-flex items-center gap-3" :class="[
      center && 'justify-center w-full',
    ]"
  >
    <!-- Spin 样式 -->
    <div
      v-if="variant === 'spin'"
      class="animate-spin rounded-full border-2 border-current border-t-transparent" :class="[
        sizeClasses[size],
        colorClasses[color],
      ]"
    />

    <!-- Dots 样式 -->
    <div
      v-else-if="variant === 'dots'"
      class="flex items-center gap-1"
    >
      <div
        v-for="i in 3"
        :key="i"
        class="rounded-full animate-bounce" :class="[
          dotSizes[size],
          colorClasses[color],
        ]"
        :style="{ animationDelay: `${i * 0.15}s` }"
      />
    </div>

    <!-- Pulse 样式 -->
    <div
      v-else-if="variant === 'pulse'"
      class="rounded-full animate-pulse" :class="[
        sizeClasses[size],
        colorClasses[color],
      ]"
    />

    <!-- 加载文本 -->
    <span
      v-if="text"
      class="font-medium" :class="[
        colorClasses[color],
      ]"
    >
      {{ text }}
    </span>
  </div>
</template>

<style scoped>
@keyframes bounce {
  0%, 80%, 100% {
    transform: scale(0);
    opacity: 0.5;
  }
  40% {
    transform: scale(1);
    opacity: 1;
  }
}

.animate-bounce {
  animation: bounce 1.4s infinite ease-in-out both;
}
</style>
