<script setup lang="ts" generic="T extends string | number | boolean | null | undefined">
import { computed } from 'vue';
import type { Component } from 'vue';

/**
 * IconButtonGroup 组件
 * 用于显示图标按钮组，常用于单选场景
 *
 * @example
 * <IconButtonGroup
 *   v-model="selectedMood"
 *   :options="moodOptions"
 *   grid-cols="3"
 *   theme="info"
 * />
 */

interface IconOption<T> {
  value: T;
  label: string;
  icon: Component;
}

interface Props {
  /** v-model 绑定值 */
  modelValue: T;
  /** 选项列表 */
  options: IconOption<T>[];
  /** 网格列数 */
  gridCols?: '2' | '3' | '4' | '5' | '6';
  /** 主题色 */
  theme?: 'primary' | 'error' | 'info' | 'success' | 'warning';
  /** 按钮尺寸 */
  size?: 'small' | 'medium' | 'large';
  /** 是否禁用 */
  disabled?: boolean;
  /** 是否必填（显示标记） */
  required?: boolean;
}

const props = withDefaults(defineProps<Props>(), {
  gridCols: '3',
  theme: 'primary',
  size: 'medium',
  disabled: false,
  required: false,
});

const emit = defineEmits<{
  'update:modelValue': [value: T];
}>();

function handleSelect(value: T) {
  if (!props.disabled) {
    emit('update:modelValue', value);
  }
}

const gridClass = computed(() => {
  const cols = {
    2: 'grid-cols-2',
    3: 'grid-cols-3',
    4: 'grid-cols-4',
    5: 'grid-cols-5',
    6: 'grid-cols-6 max-md:gap-1',
  };
  return cols[props.gridCols];
});

const buttonBaseClass = computed(() => {
  const sizeClasses = {
    small: 'p-2 max-md:p-2',
    medium: 'p-3 max-md:p-2.5',
    large: 'p-4 max-md:p-3.5',
  };

  return [
    // 基础布局
    'flex items-center justify-center',
    'w-full aspect-square',
    // 边框和背景
    'border-2 rounded-[0.875rem] max-md:rounded-xl',
    'border-[light-dark(#e5e7eb,#374151)]',
    'bg-[light-dark(white,#1f2937)]',
    'text-[light-dark(#374151,#f9fafb)]',
    // 过渡和阴影
    'transition-all duration-250 ease-[cubic-bezier(0.4,0,0.2,1)]',
    'shadow-sm',
    // 尺寸
    sizeClasses[props.size],
    // 触摸目标（移动端）
    'max-md:min-h-[2.75rem]',
    // 禁用状态
    props.disabled ? 'opacity-50 cursor-not-allowed' : 'cursor-pointer',
  ].join(' ');
});

const buttonHoverClass = computed(() => {
  if (props.disabled) return '';
  return [
    'hover:border-[light-dark(#93c5fd,#3b82f6)]',
    'hover:bg-[light-dark(#f3f4f6,#374151)]',
    'hover:-translate-y-0.5 hover:scale-[1.02]',
    'hover:shadow-[0_4px_12px_-2px_rgba(0,0,0,0.15)]',
    'max-md:hover:translate-y-0 max-md:hover:scale-100',
    'max-md:hover:shadow-[0_2px_6px_-1px_rgba(0,0,0,0.1)]',
    'active:translate-y-0 active:scale-[0.98]',
  ].join(' ');
});

const buttonActiveClass = computed(() => {
  const themeColors = {
    primary: 'border-[var(--color-primary)] bg-[var(--color-primary)] text-white',
    error: 'border-[var(--color-error)] bg-[var(--color-error)] text-white',
    info: 'border-[#0ea5e9] bg-[#0ea5e9] text-white',
    success: 'border-[var(--color-success)] bg-[var(--color-success)] text-white',
    warning: 'border-[var(--color-warning)] bg-[var(--color-warning)] text-white',
  };

  return [
    themeColors[props.theme],
    'font-semibold',
    'shadow-[0_4px_8px_-2px_rgba(0,0,0,0.2),0_0_0_1px_rgba(0,0,0,0.05)]',
    'scale-105 max-md:scale-[1.02]',
  ].join(' ');
});

const iconSizeClass = computed(() => {
  const sizes = {
    small: 'w-5 h-5 max-md:w-[1.125rem] max-md:h-[1.125rem]',
    medium: 'w-6 h-6 max-md:w-[1.375rem] max-md:h-[1.375rem]',
    large: 'w-8 h-8 max-md:w-7 max-md:h-7',
  };
  return sizes[props.size];
});

const iconStrokeClass = computed(() => {
  const strokes = {
    small: 'stroke-[2.25] max-md:stroke-[2.5]',
    medium: 'stroke-2 max-md:stroke-[2.25]',
    large: 'stroke-[1.75] max-md:stroke-2',
  };
  return strokes[props.size];
});

function getButtonClass(isActive: boolean) {
  return [
    buttonBaseClass.value,
    !isActive && buttonHoverClass.value,
    isActive && buttonActiveClass.value,
  ].filter(Boolean).join(' ');
}
</script>

<template>
  <div class="grid gap-2 w-full max-md:gap-1.5" :class="gridClass">
    <button
      v-for="option in options"
      :key="String(option.value)"
      type="button"
      :title="option.label"
      :class="getButtonClass(modelValue === option.value)"
      :disabled="props.disabled"
      @click="handleSelect(option.value)"
    >
      <component
        :is="option.icon"
        class="shrink-0" :class="[iconSizeClass, iconStrokeClass]"
      />
    </button>
  </div>
</template>
