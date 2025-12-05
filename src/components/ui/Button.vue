<script setup lang="ts">
import type { Component } from 'vue';

/**
 * Button - 按钮组件
 *
 * 基于 Tailwind CSS 4 设计令牌的按钮组件
 * 支持多种变体、尺寸和状态
 * 完整的无障碍支持
 */

/** 按钮变体类型 */
type ButtonVariant = 'primary' | 'secondary' | 'success' | 'warning' | 'danger' | 'ghost' | 'outline';

/** 按钮尺寸类型 */
type ButtonSize = 'xs' | 'sm' | 'md' | 'lg' | 'xl';

interface Props {
  /** 按钮变体 */
  variant?: ButtonVariant;
  /** 按钮尺寸 */
  size?: ButtonSize;
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
  icon?: Component;
  /** 图标（后置） */
  iconRight?: Component;
  /** 无障碍标签（用于图标按钮） */
  ariaLabel?: string;
  /** 是否为切换按钮 */
  pressed?: boolean;
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
const variantClasses: Record<ButtonVariant, string> = {
  primary: [
    'bg-blue-600 text-white',
    'hover:bg-blue-700',
    'active:bg-blue-800',
    'focus-visible:ring-blue-500',
    'dark:bg-blue-500 dark:hover:bg-blue-600 dark:active:bg-blue-700',
  ].join(' '),
  secondary: [
    'bg-gray-600 text-white',
    'hover:bg-gray-700',
    'active:bg-gray-800',
    'focus-visible:ring-gray-500',
    'dark:bg-gray-500 dark:hover:bg-gray-600 dark:active:bg-gray-700',
  ].join(' '),
  success: [
    'bg-green-600 text-white',
    'hover:bg-green-700',
    'active:bg-green-800',
    'focus-visible:ring-green-500',
    'dark:bg-green-500 dark:hover:bg-green-600 dark:active:bg-green-700',
  ].join(' '),
  warning: [
    'bg-yellow-600 text-white',
    'hover:bg-yellow-700',
    'active:bg-yellow-800',
    'focus-visible:ring-yellow-500',
    'dark:bg-yellow-500 dark:hover:bg-yellow-600 dark:active:bg-yellow-700',
  ].join(' '),
  danger: [
    'bg-red-600 text-white',
    'hover:bg-red-700',
    'active:bg-red-800',
    'focus-visible:ring-red-500',
    'dark:bg-red-500 dark:hover:bg-red-600 dark:active:bg-red-700',
  ].join(' '),
  ghost: [
    'bg-transparent text-gray-900',
    'hover:bg-gray-100',
    'active:bg-gray-200',
    'focus-visible:ring-gray-500',
    'dark:text-white dark:hover:bg-gray-800 dark:active:bg-gray-700',
  ].join(' '),
  outline: [
    'bg-transparent text-gray-900',
    'border-2 border-gray-300',
    'hover:bg-gray-100 hover:border-gray-400',
    'active:bg-gray-200 active:border-gray-500',
    'focus-visible:ring-gray-500',
    'dark:text-white dark:border-gray-600 dark:hover:bg-gray-800 dark:hover:border-gray-500',
  ].join(' '),
};

// 尺寸样式
const sizeClasses: Record<ButtonSize, string> = {
  xs: 'px-2 py-1 text-xs',
  sm: 'px-3 py-1.5 text-sm',
  md: 'px-4 py-2 text-base',
  lg: 'px-6 py-3 text-lg',
  xl: 'px-8 py-4 text-xl',
};

// 圆形按钮尺寸
const circleSizes: Record<ButtonSize, string> = {
  xs: 'w-6 h-6',
  sm: 'w-8 h-8',
  md: 'w-10 h-10',
  lg: 'w-12 h-12',
  xl: 'w-14 h-14',
};

// 图标尺寸
const iconSizes: Record<ButtonSize, string> = {
  xs: 'w-3 h-3',
  sm: 'w-4 h-4',
  md: 'w-5 h-5',
  lg: 'w-6 h-6',
  xl: 'w-7 h-7',
};

// 计算 ARIA 属性
const ariaAttributes = computed(() => {
  const attrs: Record<string, string | boolean | undefined> = {};
  
  if (props.ariaLabel) {
    attrs['aria-label'] = props.ariaLabel;
  }
  
  if (props.loading) {
    attrs['aria-busy'] = true;
    attrs['aria-disabled'] = true;
  }
  
  if (props.pressed !== undefined) {
    attrs['aria-pressed'] = props.pressed;
  }
  
  return attrs;
});
</script>

<template>
  <button
    :type="props.type"
    :disabled="props.disabled || props.loading"
    v-bind="ariaAttributes"
    class="inline-flex items-center justify-center gap-2 font-medium rounded-md transition-colors duration-200 focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-offset-2 disabled:opacity-50 disabled:cursor-not-allowed disabled:pointer-events-none"
    :class="[
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
      aria-hidden="true"
    >
      <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" />
      <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z" />
    </svg>

    <!-- 前置图标 -->
    <component
      :is="props.icon"
      v-else-if="props.icon"
      :class="iconSizes[props.size]"
      aria-hidden="true"
    />

    <!-- 按钮文本 -->
    <span v-if="!props.circle" class="truncate">
      <slot />
    </span>

    <!-- 加载时的屏幕阅读器文本 -->
    <span v-if="props.loading" class="sr-only">加载中...</span>

    <!-- 后置图标 -->
    <component
      :is="props.iconRight"
      v-if="props.iconRight && !props.circle"
      :class="iconSizes[props.size]"
      aria-hidden="true"
    />
  </button>
</template>
