<script setup lang="ts">
/**
 * FormRow - 表单行组件
 *
 * 用于 Modal 表单的标准行布局
 * 100% Tailwind CSS 4 - 零自定义 CSS
 *
 * @example
 * <FormRow label="账户名称" required>
 *   <Input v-model="form.name" />
 * </FormRow>
 */

import { computed } from 'vue';

interface Props {
  /** 标签文本 */
  label?: string;
  /** 是否必填 */
  required?: boolean;
  /** 是否可选（显示"可选"标记） */
  optional?: boolean;
  /** 错误消息 */
  error?: string;
  /** 帮助文本 */
  helpText?: string;
  /** 标签宽度类名 */
  labelWidth?: string;
  /** 是否全宽（标签和输入框各占一行） */
  fullWidth?: boolean;
  /** 标签对齐方式 */
  labelAlign?: 'left' | 'right';
}

const props = withDefaults(defineProps<Props>(), {
  label: '',
  required: false,
  optional: false,
  labelWidth: 'w-24',
  fullWidth: false,
  labelAlign: 'left',
});

// 标签宽度类
const labelWidthClass = computed(() => {
  return props.fullWidth ? 'w-full' : props.labelWidth;
});

// 标签对齐类
const labelAlignClass = computed(() => {
  if (props.fullWidth) return 'text-left';
  return props.labelAlign === 'right' ? 'text-right' : 'text-left';
});
</script>

<template>
  <div
    class="flex gap-4 mb-3" :class="[
      fullWidth ? 'flex-col items-start' : 'items-center',
    ]"
  >
    <!-- 标签 -->
    <label
      v-if="label"
      class="text-sm font-medium text-gray-700 dark:text-gray-300 whitespace-nowrap shrink-0" :class="[
        labelWidthClass,
        labelAlignClass,
        fullWidth && 'mb-1.5',
      ]"
    >
      {{ label }}
      <!-- 必填标记 -->
      <span v-if="required" class="text-red-500 ml-1">*</span>
      <!-- 可选标记 -->
      <span v-if="optional" class="text-gray-400 font-normal text-xs ml-1">(可选)</span>
    </label>

    <!-- 输入框容器 -->
    <div class="flex-1" :class="[fullWidth ? 'w-full' : 'min-w-0']">
      <slot />

      <!-- 错误消息 -->
      <p
        v-if="error"
        class="mt-1.5 text-sm text-red-600 dark:text-red-400 text-right"
        role="alert"
      >
        {{ error }}
      </p>

      <!-- 帮助文本 -->
      <p
        v-if="helpText && !error"
        class="mt-1.5 text-xs text-gray-500 dark:text-gray-400"
      >
        {{ helpText }}
      </p>
    </div>
  </div>
</template>
