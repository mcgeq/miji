<script setup lang="ts">
/**
 * Input - 输入框组件
 *
 * 支持多种类型、尺寸和状态
 * 支持前缀/后缀插槽
 * 100% Tailwind CSS 4
 */

interface Props {
  /** 输入值 */
  modelValue?: string | number;
  /** 输入类型 */
  type?: 'text' | 'password' | 'email' | 'number' | 'tel' | 'url' | 'search' | 'date' | 'datetime-local' | 'time' | 'month' | 'week';
  /** 占位符 */
  placeholder?: string;
  /** 标签 */
  label?: string;
  /** 尺寸 */
  size?: 'sm' | 'md' | 'lg';
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
  prefixIcon?: any;
  /** 后置图标 */
  suffixIcon?: any;
  /** 是否全宽 */
  fullWidth?: boolean;
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
  'blur': [event: FocusEvent];
  'focus': [event: FocusEvent];
}>();

// 检测插槽
const slots = useSlots();
const hasPrefix = computed(() => !!slots.prefix || !!props.prefixIcon);
const hasSuffix = computed(() => !!slots.suffix || !!props.suffixIcon);

// 尺寸样式
const sizeClasses = {
  sm: 'px-3 py-1.5 text-sm',
  md: 'px-4 py-2 text-base',
  lg: 'px-5 py-3 text-lg',
};

// 图标尺寸
const iconSizes = {
  sm: 'w-4 h-4',
  md: 'w-5 h-5',
  lg: 'w-6 h-6',
};
</script>

<template>
  <div class="w-full">
    <!-- 标签 -->
    <label
      v-if="props.label"
      class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1.5"
    >
      {{ props.label }}
      <span v-if="props.required" class="text-red-500 ml-0.5">*</span>
    </label>

    <!-- 输入框容器 -->
    <div class="relative flex items-stretch">
      <!-- 前缀插槽 -->
      <div
        v-if="$slots.prefix"
        class="flex items-center px-3 bg-gray-100 dark:bg-gray-700 border border-r-0 rounded-l-lg text-sm font-medium text-gray-700 dark:text-gray-300"
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
        class="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400 z-10"
      >
        <component :is="props.prefixIcon" :class="iconSizes[props.size]" />
      </div>

      <!-- 输入框 -->
      <input
        :type="props.type"
        :value="props.modelValue"
        :placeholder="props.placeholder"
        :disabled="props.disabled"
        :readonly="props.readonly"
        :required="props.required"
        :maxlength="props.maxLength"
        class="flex-1 transition-colors focus:outline-none focus:ring-2 bg-white dark:bg-gray-800 placeholder:text-gray-400 dark:placeholder:text-gray-500 border" :class="[
          sizeClasses[props.size],
          // 动态圆角
          $slots.prefix && !$slots.suffix ? 'rounded-r-lg border-l-0' : '',
          !$slots.prefix && $slots.suffix ? 'rounded-l-lg border-r-0' : '',
          $slots.prefix && $slots.suffix ? 'border-x-0' : '',
          !$slots.prefix && !$slots.suffix ? 'rounded-lg' : '',
          // 图标内边距
          hasPrefix && !$slots.prefix ? 'pl-10' : '',
          hasSuffix && !$slots.suffix ? 'pr-10' : '',
          // 边框颜色
          props.error
            ? 'border-red-300 dark:border-red-700 focus:ring-red-500 focus:border-red-500'
            : 'border-gray-300 dark:border-gray-600 focus:ring-blue-500 focus:border-blue-500',
          // 状态
          props.disabled && 'opacity-50 cursor-not-allowed bg-gray-50 dark:bg-gray-900 text-gray-500 dark:text-gray-500',
          props.readonly && 'cursor-default bg-gray-50 dark:bg-gray-900 text-gray-900 dark:text-white font-medium',
          !props.disabled && !props.readonly && 'text-gray-900 dark:text-white',
        ]"
        @input="emit('update:modelValue', ($event.target as HTMLInputElement).value)"
        @blur="emit('blur', $event)"
        @focus="emit('focus', $event)"
      >

      <!-- 后缀插槽 -->
      <div
        v-if="$slots.suffix"
        class="flex items-center px-3 bg-gray-100 dark:bg-gray-700 border border-l-0 rounded-r-lg text-sm font-medium text-gray-700 dark:text-gray-300"
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
        class="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 z-10"
      >
        <component :is="props.suffixIcon" :class="iconSizes[props.size]" />
      </div>
    </div>

    <!-- 帮助文本 -->
    <p
      v-if="props.hint && !props.error"
      class="mt-1.5 text-sm text-gray-500 dark:text-gray-400"
    >
      {{ props.hint }}
    </p>

    <!-- 错误信息 -->
    <p
      v-if="props.error"
      class="mt-1.5 text-sm text-red-600 dark:text-red-400"
    >
      {{ props.error }}
    </p>
  </div>
</template>
