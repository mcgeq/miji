<script setup lang="ts">
  import type { Component } from 'vue';

  /**
   * Input - 输入框组件
   *
   * 支持多种类型、尺寸和状态
   * 支持前缀/后缀插槽
   * 完整的无障碍支持
   * 100% Tailwind CSS 4 设计令牌
   */

  /** 输入框类型 */
  type InputType =
    | 'text'
    | 'password'
    | 'email'
    | 'number'
    | 'tel'
    | 'url'
    | 'search'
    | 'date'
    | 'datetime-local'
    | 'time'
    | 'month'
    | 'week';

  /** 输入框尺寸 */
  type InputSize = 'sm' | 'md' | 'lg';

  interface Props {
    /** 输入值 */
    modelValue?: string | number;
    /** 输入类型 */
    type?: InputType;
    /** 占位符 */
    placeholder?: string;
    /** 标签 */
    label?: string;
    /** 尺寸 */
    size?: InputSize;
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
    /** 最大长度 */
    maxLength?: number;
    /** 前置图标 */
    prefixIcon?: Component;
    /** 后置图标 */
    suffixIcon?: Component;
    /** 是否全宽 */
    fullWidth?: boolean;
    /** 输入框 ID（用于无障碍关联） */
    id?: string;
    /** 自动完成 */
    autocomplete?: string;
    /** 输入框名称 */
    name?: string;
  }

  const props = withDefaults(defineProps<Props>(), {
    type: 'text',
    size: 'md',
    disabled: false,
    readonly: false,
    required: false,
    fullWidth: false,
  });

  const emit = defineEmits<{
    'update:modelValue': [value: string | number];
    blur: [event: FocusEvent];
    focus: [event: FocusEvent];
    change: [event: Event];
  }>();

  // 生成唯一 ID
  const inputId = computed(() => props.id || `input-${Math.random().toString(36).slice(2, 9)}`);
  const hintId = computed(() => `${inputId.value}-hint`);
  const errorId = computed(() => `${inputId.value}-error`);

  // 检测插槽
  const slots = useSlots();
  const hasPrefix = computed(() => !!slots.prefix || !!props.prefixIcon);
  const hasSuffix = computed(() => !!slots.suffix || !!props.suffixIcon);

  // 尺寸样式
  const sizeClasses: Record<InputSize, string> = {
    sm: 'px-3 py-1.5 text-sm',
    md: 'px-4 py-2 text-base',
    lg: 'px-5 py-3 text-lg',
  };

  // 图标尺寸
  const iconSizes: Record<InputSize, string> = {
    sm: 'w-4 h-4',
    md: 'w-5 h-5',
    lg: 'w-6 h-6',
  };

  // 计算 aria-describedby
  const ariaDescribedBy = computed(() => {
    const ids: string[] = [];
    if (props.error) ids.push(errorId.value);
    else if (props.hint) ids.push(hintId.value);
    return ids.length > 0 ? ids.join(' ') : undefined;
  });
</script>

<template>
  <div class="w-full">
    <!-- 标签 -->
    <label
      v-if="props.label"
      :for="inputId"
      class="block text-sm font-medium text-gray-900 dark:text-white mb-1.5"
    >
      {{ props.label }}
      <span v-if="props.required" class="text-red-600 dark:text-red-400 ml-0.5" aria-hidden="true"
        >*</span
      >
    </label>

    <!-- 输入框容器 -->
    <div class="relative flex items-stretch">
      <!-- 前缀插槽 -->
      <div
        v-if="$slots.prefix"
        class="flex items-center px-3 bg-gray-100 dark:bg-gray-700 border border-r-0 rounded-l-lg text-sm font-medium text-gray-900 dark:text-white"
        :class="[
          props.error
            ? 'border-red-300 dark:border-red-700'
            : 'border-gray-300 dark:border-gray-600',
        ]"
      >
        <slot name="prefix" />
      </div>

      <!-- 前置图标（向后兼容） -->
      <div
        v-else-if="props.prefixIcon"
        class="absolute left-3 top-1/2 -translate-y-1/2 text-gray-600 dark:text-gray-400 z-10"
        aria-hidden="true"
      >
        <component :is="props.prefixIcon" :class="iconSizes[props.size]" />
      </div>

      <!-- 输入框 -->
      <input
        :id="inputId"
        :type="props.type"
        :name="props.name"
        :value="props.modelValue"
        :placeholder="props.placeholder"
        :disabled="props.disabled"
        :readonly="props.readonly"
        :required="props.required"
        :maxlength="props.maxLength"
        :autocomplete="props.autocomplete"
        :aria-invalid="!!props.error"
        :aria-describedby="ariaDescribedBy"
        :aria-required="props.required"
        class="flex-1 transition-colors duration-200 focus:outline-none focus:ring-2 bg-white dark:bg-gray-800 text-gray-900 dark:text-white placeholder:text-gray-400 dark:placeholder:text-gray-500 border"
        :class="[
          sizeClasses[props.size],
          // 动态圆角
          $slots.prefix && !$slots.suffix ? 'rounded-r-lg border-l-0' : '',
          !$slots.prefix && $slots.suffix ? 'rounded-l-lg border-r-0' : '',
          $slots.prefix && $slots.suffix ? 'border-x-0' : '',
          !$slots.prefix && !$slots.suffix ? 'rounded-lg' : '',
          // 图标内边距
          hasPrefix && !$slots.prefix ? 'pl-10' : '',
          hasSuffix && !$slots.suffix ? 'pr-10' : '',
          // 边框颜色和焦点状态
          props.error
            ? 'border-red-300 dark:border-red-700 focus:ring-red-500 focus:border-red-500'
            : 'border-gray-300 dark:border-gray-600 focus:ring-blue-500 focus:border-blue-500',
          // 状态
          props.disabled && 'opacity-50 cursor-not-allowed bg-gray-50 dark:bg-gray-900',
          props.readonly && 'cursor-default bg-gray-50 dark:bg-gray-900 font-medium',
        ]"
        @input="emit('update:modelValue', ($event.target as HTMLInputElement).value)"
        @blur="emit('blur', $event)"
        @focus="emit('focus', $event)"
        @change="emit('change', $event)"
      />

      <!-- 后缀插槽 -->
      <div
        v-if="$slots.suffix"
        class="flex items-center px-3 bg-gray-100 dark:bg-gray-700 border border-l-0 rounded-r-lg text-sm font-medium text-gray-900 dark:text-white"
        :class="[
          props.error
            ? 'border-red-300 dark:border-red-700'
            : 'border-gray-300 dark:border-gray-600',
        ]"
      >
        <slot name="suffix" />
      </div>

      <!-- 后置图标（向后兼容） -->
      <div
        v-else-if="props.suffixIcon"
        class="absolute right-3 top-1/2 -translate-y-1/2 text-gray-600 dark:text-gray-400 z-10"
        aria-hidden="true"
      >
        <component :is="props.suffixIcon" :class="iconSizes[props.size]" />
      </div>
    </div>

    <!-- 帮助文本 -->
    <p
      v-if="props.hint && !props.error"
      :id="hintId"
      class="mt-1.5 text-sm text-gray-600 dark:text-gray-400"
    >
      {{ props.hint }}
    </p>

    <!-- 错误信息 -->
    <p
      v-if="props.error"
      :id="errorId"
      role="alert"
      aria-live="polite"
      class="mt-1.5 text-sm text-red-600 dark:text-red-400"
    >
      {{ props.error }}
    </p>
  </div>
</template>
