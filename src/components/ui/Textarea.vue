<script setup lang="ts">
/**
 * Textarea - 多行文本框组件
 *
 * 支持自动高度、字数统计等功能
 * 100% Tailwind CSS 4
 */

import { computed } from 'vue';

interface Props {
  /** 输入值 */
  modelValue?: string;
  /** 占位符 */
  placeholder?: string;
  /** 标签 */
  label?: string;
  /** 行数 */
  rows?: number;
  /** 最大长度 */
  maxLength?: number;
  /** 错误信息 */
  error?: string;
  /** 帮助文本 */
  hint?: string;
  /** 是否禁用 */
  disabled?: boolean;
  /** 是否只读 */
  readonly?: boolean;
  /** 是否必填 */
  required?: boolean;
  /** 是否自动调整高度 */
  autoResize?: boolean;
  /** 是否显示字数统计 */
  showCount?: boolean;
  /** 是否全宽 */
  fullWidth?: boolean;
  /** 文本框 ID（用于无障碍关联） */
  id?: string;
  /** 文本框名称 */
  name?: string;
}

const props = withDefaults(defineProps<Props>(), {
  rows: 3,
  disabled: false,
  readonly: false,
  required: false,
  autoResize: false,
  showCount: true, // 默认显示字数统计
  fullWidth: false,
});

const emit = defineEmits<{
  'update:modelValue': [value: string];
  'blur': [event: FocusEvent];
  'focus': [event: FocusEvent];
}>();

// 字符数
const characterCount = computed(() => {
  return props.modelValue?.length || 0;
});

// 是否超出限制
const isOverLimit = computed(() => {
  return props.maxLength ? characterCount.value > props.maxLength : false;
});

// 是否显示字数统计 - 当有 maxLength 或显式设置 showCount 时显示
const shouldShowCount = computed(() => {
  return (props.showCount && props.maxLength) || (props.showCount && characterCount.value > 0);
});

// 生成唯一 ID
const textareaId = computed(() => props.id || `textarea-${Math.random().toString(36).slice(2, 9)}`);
const hintId = computed(() => `${textareaId.value}-hint`);
const errorId = computed(() => `${textareaId.value}-error`);

// 计算 aria-describedby
const ariaDescribedBy = computed(() => {
  const ids: string[] = [];
  if (props.error) ids.push(errorId.value);
  else if (props.hint) ids.push(hintId.value);
  return ids.length > 0 ? ids.join(' ') : undefined;
});
</script>

<template>
  <div class="relative w-full">
    <!-- 标签 -->
    <label
      v-if="label"
      :for="textareaId"
      class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1.5"
    >
      {{ label }}
      <span v-if="required" class="text-red-500 ml-0.5" aria-hidden="true">*</span>
    </label>

    <!-- 文本框 -->
    <textarea
      :id="textareaId"
      :name="name"
      :value="modelValue"
      :placeholder="placeholder"
      :rows="rows"
      :maxlength="maxLength"
      :disabled="disabled"
      :readonly="readonly"
      :required="required"
      :aria-invalid="!!error"
      :aria-describedby="ariaDescribedBy"
      :aria-required="required"
      class="w-full rounded-lg border transition-colors resize-y focus:outline-none focus:ring-2 px-4 py-2 text-base bg-white dark:bg-gray-800 text-gray-900 dark:text-white placeholder:text-gray-400 dark:placeholder:text-gray-500" :class="[
        error
          ? 'border-red-300 dark:border-red-700 focus:ring-red-500 focus:border-red-500'
          : 'border-gray-300 dark:border-gray-600 focus:ring-blue-500 focus:border-blue-500',
        disabled && 'opacity-50 cursor-not-allowed bg-gray-50 dark:bg-gray-900',
        props.readonly && 'cursor-default bg-gray-50 dark:bg-gray-900',
        autoResize && 'resize-none',
      ]"
      @input="emit('update:modelValue', ($event.target as HTMLTextAreaElement).value)"
      @blur="emit('blur', $event)"
      @focus="emit('focus', $event)"
    />

    <!-- 底部信息栏：错误/帮助文本 + 字数统计 -->
    <div v-if="hint || error || shouldShowCount" class="flex items-start justify-between mt-0.25 gap-2">
      <!-- 帮助文本或错误信息 -->
      <p
        v-if="hint && !error"
        :id="hintId"
        class="text-sm text-gray-500 dark:text-gray-400 flex-1"
      >
        {{ hint }}
      </p>
      <p
        v-else-if="error"
        :id="errorId"
        role="alert"
        aria-live="polite"
        class="text-sm text-red-600 dark:text-red-400 flex-1"
      >
        {{ error }}
      </p>
      <div v-else class="flex-1" />

      <!-- 字数统计（右下角） -->
      <span
        v-if="shouldShowCount"
        class="text-sm shrink-0" :class="[
          isOverLimit ? 'text-red-600 dark:text-red-400' : 'text-gray-500 dark:text-gray-400',
        ]"
      >
        {{ characterCount }}{{ maxLength ? `/${maxLength}` : '' }}
      </span>
    </div>
  </div>
</template>
