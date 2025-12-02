<script setup lang="ts">
/**
 * Button - 按钮组件
 *
 * 基于 Tailwind CSS 4 的按钮组件
 * 支持多种变体、尺寸和状态
 */

interface Props {
  /** 按钮变体 */
  variant?: 'primary' | 'secondary' | 'success' | 'warning' | 'danger' | 'ghost' | 'outline';
  /** 按钮尺寸 */
  size?: 'xs' | 'sm' | 'md' | 'lg' | 'xl';
  /** 是否为圆形按钮 */
  circle?: boolean;
  /** 是否全宽 */
  fullWidth?: boolean;
  /** 加载状态 */
  loading?: boolean;
  /** 禁用状态 */
  disabled?: boolean;
  /** 按钮类型 */
  type?: 'button' | 'submit' | 'reset';
  /** 图标（前置） */
  icon?: any;
  /** 图标（后置） */
  iconRight?: any;
}

const props = withDefaults(defineProps<Props>(), {
  variant: 'primary',
  size: 'md',
  circle: false,
  fullWidth: false,
  loading: false,
  disabled: false,
  type: 'button',
});

// 变体样式
const variantClasses = {
  primary: 'bg-blue-600 hover:bg-blue-700 text-white',
  secondary: 'bg-gray-200 hover:bg-gray-300 dark:bg-gray-700 dark:hover:bg-gray-600 text-gray-900 dark:text-white',
  success: 'bg-green-600 hover:bg-green-700 text-white',
  warning: 'bg-yellow-600 hover:bg-yellow-700 text-white',
  danger: 'bg-red-600 hover:bg-red-700 text-white',
  ghost: 'hover:bg-gray-100 dark:hover:bg-gray-700 text-gray-900 dark:text-white',
  outline: 'border-2 border-gray-300 dark:border-gray-600 hover:bg-gray-50 dark:hover:bg-gray-700 text-gray-900 dark:text-white',
};

// 尺寸样式
const sizeClasses = {
  xs: 'px-2 py-1 text-xs',
  sm: 'px-3 py-1.5 text-sm',
  md: 'px-4 py-2 text-base',
  lg: 'px-6 py-3 text-lg',
  xl: 'px-8 py-4 text-xl',
};

// 圆形按钮尺寸
const circleSizes = {
  xs: 'w-6 h-6',
  sm: 'w-8 h-8',
  md: 'w-10 h-10',
  lg: 'w-12 h-12',
  xl: 'w-14 h-14',
};

// 图标尺寸
const iconSizes = {
  xs: 'w-3 h-3',
  sm: 'w-4 h-4',
  md: 'w-5 h-5',
  lg: 'w-6 h-6',
  xl: 'w-7 h-7',
};
</script>

<template>
  <button
    :type="props.type"
    :disabled="props.disabled || props.loading"
    class="inline-flex items-center justify-center gap-2 font-medium transition-all focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed" :class="[
      props.circle ? ['rounded-full', circleSizes[props.size]] : ['rounded-lg', sizeClasses[props.size]],
      variantClasses[props.variant],
      props.fullWidth && 'w-full',
    ]"
  >
    <!-- 加载动画 -->
    <svg
      v-if="props.loading"
      class="animate-spin"
      :class="iconSizes[props.size]"
      xmlns="http://www.w3.org/2000/svg"
      fill="none"
      viewBox="0 0 24 24"
    >
      <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" />
      <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z" />
    </svg>

    <!-- 前置图标 -->
    <component
      :is="props.icon"
      v-else-if="props.icon"
      :class="iconSizes[props.size]"
    />

    <!-- 按钮文本 -->
    <slot v-if="!props.circle" />

    <!-- 后置图标 -->
    <component
      :is="props.iconRight"
      v-if="props.iconRight && !props.circle"
      :class="iconSizes[props.size]"
    />
  </button>
</template>
