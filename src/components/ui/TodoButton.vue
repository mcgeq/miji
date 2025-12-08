<script setup lang="ts">
  /**
   * TodoButton - Todo 专用按钮组件
   *
   * 专为 Todo 功能设计的微型按钮，支持：
   * - active/readonly/disabled 状态
   * - 图标按钮和文本按钮
   * - 响应式和无障碍支持
   *
   * 完全使用 Tailwind CSS，零自定义 CSS
   */

  import type { Component } from 'vue';

  interface Props {
    /** 是否激活状态（高亮显示） */
    active?: boolean;
    /** 是否只读（不可点击但可见） */
    readonly?: boolean;
    /** 是否禁用 */
    disabled?: boolean;
    /** 图标组件 */
    icon?: Component;
    /** 按钮文本 */
    text?: string;
    /** 工具提示 */
    title?: string;
    /** 尺寸变体 */
    size?: 'small' | 'medium' | 'large';
    /** 是否仅显示图标 */
    iconOnly?: boolean;
    /** 颜色变体 */
    variant?: 'default' | 'primary' | 'success' | 'warning' | 'error';
  }

  const props = withDefaults(defineProps<Props>(), {
    active: false,
    readonly: false,
    disabled: false,
    size: 'medium',
    iconOnly: false,
    variant: 'default',
  });

  // 基础样式
  const baseClasses =
    'inline-flex items-center justify-center border rounded-lg transition-all duration-200 outline-none';

  // 尺寸样式
  const sizeClasses = computed(() => {
    switch (props.size) {
      case 'small':
        return props.iconOnly ? 'p-1' : 'px-1.5 py-0.5 gap-1 text-[0.625rem]';
      case 'large':
        return props.iconOnly ? 'p-1.5' : 'px-3 py-1.5 gap-2 text-sm';
      default: // medium
        return props.iconOnly ? 'p-1' : 'px-2 py-1 gap-1.5 text-xs';
    }
  });

  // 图标尺寸
  const iconSize = computed(() => {
    switch (props.size) {
      case 'small':
        return 12;
      case 'large':
        return 16;
      default:
        return 14;
    }
  });

  // 状态样式
  const stateClasses = computed(() => {
    // Readonly 状态
    if (props.readonly) {
      return 'cursor-default opacity-60';
    }

    // Disabled 状态
    if (props.disabled) {
      return 'cursor-not-allowed opacity-50';
    }

    // Active 状态
    if (props.active) {
      return 'bg-gray-200 dark:bg-gray-700 border-gray-900 dark:border-gray-100 font-semibold';
    }

    // 默认状态（可交互）
    return 'hover:bg-gray-100 dark:hover:bg-gray-700 hover:border-blue-500 dark:hover:border-blue-400';
  });

  // 颜色变体样式
  const variantClasses = computed(() => {
    if (props.readonly || props.disabled) {
      return ''; // readonly/disabled 不应用颜色变体
    }

    switch (props.variant) {
      case 'primary':
        return 'bg-blue-600 text-white border-blue-600 hover:bg-blue-700 hover:border-blue-700';
      case 'success':
        return 'bg-green-600 text-white border-green-600 hover:bg-green-700 hover:border-green-700';
      case 'warning':
        return 'bg-yellow-600 text-white border-yellow-600 hover:bg-yellow-700 hover:border-yellow-700';
      case 'error':
        return 'bg-red-600 text-white border-red-600 hover:bg-red-700 hover:border-red-700';
      default:
        return 'bg-white dark:bg-gray-800 border-gray-300 dark:border-gray-600 text-gray-900 dark:text-white';
    }
  });

  // 焦点样式
  const focusClasses =
    'focus-visible:ring-2 focus-visible:ring-blue-500 focus-visible:ring-offset-2';

  // 文本截断样式（当有文本时）
  const textClasses = 'whitespace-nowrap overflow-hidden text-ellipsis max-w-24';

  // 合并所有样式
  const buttonClasses = computed(() => {
    const classes = [baseClasses, sizeClasses.value, focusClasses];

    // 颜色变体优先于状态样式
    if (props.variant !== 'default') {
      classes.push(variantClasses.value);
    } else {
      classes.push(variantClasses.value, stateClasses.value);
    }

    return classes.join(' ');
  });
</script>

<template>
  <button
    :class="buttonClasses"
    :title="props.title"
    :disabled="props.disabled || props.readonly"
    type="button"
  >
    <!-- 图标 -->
    <component :is="props.icon" v-if="props.icon" :size="iconSize" class="shrink-0" />

    <!-- 文本（非 icon-only 模式） -->
    <span v-if="props.text && !props.iconOnly" :class="textClasses"> {{ props.text }}</span>
  </button>
</template>

<style scoped>
  /*
 * 高对比度模式支持
 */
  @media (prefers-contrast: high) {
    button {
      border-width: 2px;
    }

    button:focus-visible {
      --tw-ring-width: 4px;
    }
  }

  /*
 * 减少动画模式支持
 */
  @media (prefers-reduced-motion: reduce) {
    button {
      transition: none;
    }
  }

  /*
 * 移动端响应式优化
 */
  @media (max-width: 768px) {
    button {
      min-width: 0;
    }
  }
</style>
