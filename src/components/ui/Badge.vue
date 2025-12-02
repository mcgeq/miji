<script setup lang="ts">
/**
 * Badge - 徽章组件
 *
 * 用于显示状态、数量或标签
 * 100% Tailwind CSS 4
 */

interface Props {
  /** 变体 */
  variant?: 'default' | 'primary' | 'success' | 'warning' | 'danger' | 'info';
  /** 尺寸 */
  size?: 'sm' | 'md' | 'lg';
  /** 是否为圆点 */
  dot?: boolean;
  /** 是否为轮廓样式 */
  outline?: boolean;
  /** 是否可移除 */
  removable?: boolean;
}

const props = withDefaults(defineProps<Props>(), {
  variant: 'default',
  size: 'md',
  dot: false,
  outline: false,
  removable: false,
});

const emit = defineEmits<{
  remove: [];
}>();

// 变体样式
const variantClasses = {
  default: props.outline
    ? 'border-gray-300 dark:border-gray-600 text-gray-700 dark:text-gray-300'
    : 'bg-gray-100 dark:bg-gray-700 text-gray-700 dark:text-gray-300',
  primary: props.outline
    ? 'border-blue-500 text-blue-600 dark:text-blue-400'
    : 'bg-blue-100 dark:bg-blue-900/30 text-blue-700 dark:text-blue-300',
  success: props.outline
    ? 'border-green-500 text-green-600 dark:text-green-400'
    : 'bg-green-100 dark:bg-green-900/30 text-green-700 dark:text-green-300',
  warning: props.outline
    ? 'border-yellow-500 text-yellow-600 dark:text-yellow-400'
    : 'bg-yellow-100 dark:bg-yellow-900/30 text-yellow-700 dark:text-yellow-300',
  danger: props.outline
    ? 'border-red-500 text-red-600 dark:text-red-400'
    : 'bg-red-100 dark:bg-red-900/30 text-red-700 dark:text-red-300',
  info: props.outline
    ? 'border-cyan-500 text-cyan-600 dark:text-cyan-400'
    : 'bg-cyan-100 dark:bg-cyan-900/30 text-cyan-700 dark:text-cyan-300',
};

// 尺寸样式
const sizeClasses = {
  sm: props.dot ? 'w-2 h-2' : 'px-2 py-0.5 text-xs',
  md: props.dot ? 'w-2.5 h-2.5' : 'px-2.5 py-1 text-sm',
  lg: props.dot ? 'w-3 h-3' : 'px-3 py-1.5 text-base',
};
</script>

<template>
  <span
    class="inline-flex items-center gap-1.5 font-medium rounded-full" :class="[
      props.outline && 'border',
      variantClasses[variant],
      sizeClasses[size],
    ]"
  >
    <!-- 圆点指示器 -->
    <span
      v-if="dot"
      class="rounded-full" :class="[
        variant === 'default' && 'bg-gray-400',
        variant === 'primary' && 'bg-blue-500',
        variant === 'success' && 'bg-green-500',
        variant === 'warning' && 'bg-yellow-500',
        variant === 'danger' && 'bg-red-500',
        variant === 'info' && 'bg-cyan-500',
        size === 'sm' && 'w-1.5 h-1.5',
        size === 'md' && 'w-2 h-2',
        size === 'lg' && 'w-2.5 h-2.5',
      ]"
    />

    <!-- 内容 -->
    <slot />

    <!-- 移除按钮 -->
    <button
      v-if="removable"
      type="button"
      class="ml-0.5 hover:bg-black/10 dark:hover:bg-white/10 rounded-full p-0.5 transition-colors"
      aria-label="移除"
      @click="emit('remove')"
    >
      <svg class="w-3 h-3" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
      </svg>
    </button>
  </span>
</template>
