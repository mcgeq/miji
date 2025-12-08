<script setup lang="ts">
  /**
   * Divider - 分割线组件
   *
   * 支持横向、纵向、文字分割线
   * 100% Tailwind CSS 4
   */

  interface Props {
    /** 方向 */
    orientation?: 'horizontal' | 'vertical';
    /** 文本位置 */
    textAlign?: 'left' | 'center' | 'right';
    /** 分割线样式 */
    variant?: 'solid' | 'dashed' | 'dotted';
    /** 间距 */
    spacing?: 'none' | 'sm' | 'md' | 'lg';
  }

  withDefaults(defineProps<Props>(), {
    orientation: 'horizontal',
    textAlign: 'center',
    variant: 'solid',
    spacing: 'md',
  });

  // 间距样式
  const spacingClasses = {
    none: '',
    sm: 'my-2',
    md: 'my-4',
    lg: 'my-8',
  };

  // 样式映射
  const variantClasses = {
    solid: 'border-solid',
    dashed: 'border-dashed',
    dotted: 'border-dotted',
  };
</script>

<template>
  <!-- 横向分割线 -->
  <div
    v-if="orientation === 'horizontal'"
    class="flex items-center"
    :class="[
      spacingClasses[spacing],
    ]"
  >
    <!-- 左侧线条 -->
    <div
      v-if="$slots.default && textAlign !== 'left'"
      class="flex-1 border-t border-gray-200 dark:border-gray-700"
      :class="[
        variantClasses[variant],
      ]"
    />

    <!-- 文本内容 -->
    <div
      v-if="$slots.default"
      class="text-sm text-gray-500 dark:text-gray-400"
      :class="[
        textAlign === 'left' ? 'mr-3' : textAlign === 'right' ? 'ml-3' : 'mx-3',
      ]"
    >
      <slot />
    </div>

    <!-- 右侧线条 -->
    <div
      class="border-t border-gray-200 dark:border-gray-700"
      :class="[
        variantClasses[variant],
        $slots.default && textAlign !== 'right' ? 'flex-1' : 'w-full',
      ]"
    />
  </div>

  <!-- 纵向分割线 -->
  <div
    v-else
    class="inline-block h-full border-l border-gray-200 dark:border-gray-700"
    :class="[
      variantClasses[variant],
      spacing === 'sm' && 'mx-2',
      spacing === 'md' && 'mx-4',
      spacing === 'lg' && 'mx-8',
    ]"
  />
</template>
