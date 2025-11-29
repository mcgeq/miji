<script setup lang="ts">
/**
 * EmptyState - 空状态组件
 *
 * 用于显示无数据时的友好提示
 * 100% Tailwind CSS 4
 */

interface Props {
  /** Emoji 图标 */
  icon?: string;
  /** 提示文本 */
  message?: string;
  /** 描述文本 */
  description?: string;
}

withDefaults(defineProps<Props>(), {
  icon: '📝',
  message: '暂无数据',
  description: '',
});
</script>

<template>
  <div class="flex flex-col items-center gap-4 py-16 text-center text-gray-500 dark:text-gray-400 bg-gradient-to-b from-white to-gray-50 dark:from-gray-800 dark:to-gray-900 rounded-lg border-2 border-dashed border-gray-300 dark:border-gray-700 my-4">
    <!-- Emoji 图标 -->
    <div class="text-6xl opacity-30">
      {{ icon }}
    </div>

    <!-- 主要提示文本 -->
    <div class="text-base font-medium">
      {{ message }}
    </div>

    <!-- 可选的描述文本 -->
    <p v-if="description" class="text-sm text-gray-400 dark:text-gray-500 max-w-md">
      {{ description }}
    </p>

    <!-- 可选的插槽，用于自定义内容（如操作按钮） -->
    <div v-if="$slots.default" class="mt-2">
      <slot />
    </div>
  </div>
</template>
