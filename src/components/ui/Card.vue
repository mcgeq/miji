<script setup lang="ts">
/**
 * Card - 卡片组件
 *
 * 通用卡片容器，支持头部、底部和悬停效果
 * 100% Tailwind CSS 4
 */

interface Props {
  /** 标题 */
  title?: string;
  /** 是否可悬停 */
  hoverable?: boolean;
  /** 是否有边框 */
  bordered?: boolean;
  /** 是否有阴影 */
  shadow?: 'none' | 'sm' | 'md' | 'lg';
  /** 内边距 */
  padding?: 'none' | 'sm' | 'md' | 'lg';
}

const props = withDefaults(defineProps<Props>(), {
  hoverable: false,
  bordered: true,
  shadow: 'sm',
  padding: 'md',
});

// 阴影样式
const shadowClasses = {
  none: '',
  sm: 'shadow-sm',
  md: 'shadow-md',
  lg: 'shadow-lg',
};

// 内边距样式
const paddingClasses = {
  none: '',
  sm: 'p-3',
  md: 'p-4',
  lg: 'p-6',
};
</script>

<template>
  <div
    class="rounded-xl bg-white dark:bg-gray-800 transition-all" :class="[
      props.bordered && 'border border-gray-200 dark:border-gray-700',
      shadowClasses[props.shadow],
      props.hoverable && 'hover:shadow-lg hover:scale-[1.02] cursor-pointer',
    ]"
  >
    <!-- 头部 -->
    <div
      v-if="props.title || $slots.header"
      class="border-b border-gray-200 dark:border-gray-700" :class="[
        paddingClasses[props.padding],
      ]"
    >
      <slot name="header">
        <h3 class="text-lg font-semibold text-gray-900 dark:text-white">
          {{ props.title }}
        </h3>
      </slot>
    </div>

    <!-- 内容 -->
    <div :class="paddingClasses[props.padding]">
      <slot />
    </div>

    <!-- 底部 -->
    <div
      v-if="$slots.footer"
      class="border-t border-gray-200 dark:border-gray-700" :class="[
        paddingClasses[props.padding],
      ]"
    >
      <slot name="footer" />
    </div>
  </div>
</template>
