<script setup lang="ts" generic="T extends string | number">
  /**
   * PresetButtons 组件
   * 用于快速选择预设值的按钮组
   *
   * @example
   * <PresetButtons
   *   v-model="waterIntake"
   *   :presets="[500, 1000, 1500, 2000]"
   *   suffix="ml"
   * />
   */

  interface Props {
    /** v-model 绑定值 */
    modelValue: T | undefined;
    /** 预设值列表 */
    presets: T[];
    /** 后缀文本（如单位） */
    suffix?: string;
    /** 前缀文本 */
    prefix?: string;
    /** 按钮尺寸 */
    size?: 'small' | 'medium';
    /** 是否禁用 */
    disabled?: boolean;
  }

  const props = withDefaults(defineProps<Props>(), {
    suffix: '',
    prefix: '',
    size: 'small',
    disabled: false,
  });

  const emit = defineEmits<{
    'update:modelValue': [value: T];
  }>();

  function handleSelect(value: T) {
    if (!props.disabled) {
      emit('update:modelValue', value);
    }
  }

  function formatValue(value: T): string {
    let display = String(value);
    if (props.prefix) display = props.prefix + display;
    if (props.suffix) display = display + props.suffix;
    return display;
  }

  function getButtonClass(preset: T) {
    const isActive = props.modelValue === preset;
    const sizeClasses = {
      small: 'py-1 px-2 text-xs max-md:py-0.5 max-md:px-1.5 max-md:text-[0.7rem]',
      medium: 'py-2 px-4 text-sm max-md:py-1 max-md:px-2 max-md:text-xs',
    };

    return [
      // 基础样式
      'border rounded-lg font-medium whitespace-nowrap',
      'transition-all duration-200 ease-in-out',
      sizeClasses[props.size],
      // 禁用状态
      props.disabled ? 'opacity-50 cursor-not-allowed' : 'cursor-pointer',
      // 激活状态
      isActive
        ? 'border-[var(--color-primary)] bg-[var(--color-primary)] text-white font-semibold'
        : [
            'border-[light-dark(#e5e7eb,#374151)]',
            'bg-[light-dark(white,#1f2937)]',
            'text-[light-dark(#111827,#f9fafb)]',
            !props.disabled &&
              'hover:border-[var(--color-primary)] hover:bg-[light-dark(#f3f4f6,#374151)] hover:-translate-y-0.5',
            !props.disabled && 'active:translate-y-0',
          ]
            .filter(Boolean)
            .join(' '),
    ]
      .filter(Boolean)
      .join(' ');
  }
</script>

<template>
  <div class="flex flex-wrap gap-2 mt-2 max-md:gap-1.5">
    <button
      v-for="preset in presets"
      :key="String(preset)"
      type="button"
      :class="getButtonClass(preset)"
      :disabled="props.disabled"
      @click="handleSelect(preset)"
    >
      {{ formatValue(preset) }}
    </button>
  </div>
</template>
