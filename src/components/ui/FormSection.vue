<script setup lang="ts">
/**
 * FormSection - 表单区块组件
 *
 * 用于将相关的表单字段分组
 * 100% Tailwind CSS 4 - 零自定义 CSS
 *
 * @example
 * <FormSection title="基本信息">
 *   <FormRow label="姓名">
 *     <Input v-model="form.name" />
 *   </FormRow>
 *   <FormRow label="邮箱">
 *     <Input v-model="form.email" />
 *   </FormRow>
 * </FormSection>
 */

interface Props {
  /** 区块标题 */
  title?: string;
  /** 是否显示分隔线 */
  showDivider?: boolean;
}

withDefaults(defineProps<Props>(), {
  showDivider: true,
});
</script>

<template>
  <div class="flex flex-col gap-0 mb-6">
    <!-- 区块标题 -->
    <h3
      v-if="title"
      class="text-lg font-medium text-gray-900 dark:text-white pb-2 mb-3"
      :class="[
        showDivider && 'border-b border-gray-200 dark:border-gray-700',
      ]"
    >
      {{ title }}
    </h3>

    <!-- 表单内容 -->
    <slot />
  </div>
</template>
