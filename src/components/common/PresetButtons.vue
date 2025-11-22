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
</script>

<template>
  <div class="preset-buttons">
    <button
      v-for="preset in presets"
      :key="String(preset)"
      type="button"
      class="preset-btn"
      :class="[
        `preset-btn-${size}`,
        {
          'preset-btn-active': modelValue === preset,
          'preset-btn-disabled': disabled,
        },
      ]"
      :disabled="disabled"
      @click="handleSelect(preset)"
    >
      {{ formatValue(preset) }}
    </button>
  </div>
</template>

<style scoped>
/* 容器 */
.preset-buttons {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
  margin-top: 0.5rem;
}

/* 按钮基础样式 */
.preset-btn {
  padding: 0.375rem 0.75rem;
  border: 1px solid var(--color-base-300);
  border-radius: 0.5rem;
  background-color: var(--color-base-100);
  color: var(--color-base-content);
  font-size: 0.875rem;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.2s ease-in-out;
  white-space: nowrap;
}

.preset-btn:hover:not(:disabled) {
  border-color: var(--color-primary);
  background-color: var(--color-base-200);
  transform: translateY(-1px);
}

.preset-btn:active:not(:disabled) {
  transform: translateY(0);
}

/* 尺寸变体 */
.preset-btn-small {
  padding: 0.25rem 0.5rem;
  font-size: 0.75rem;
}

.preset-btn-medium {
  padding: 0.5rem 1rem;
  font-size: 0.875rem;
}

/* 激活状态 */
.preset-btn-active {
  border-color: var(--color-primary);
  background-color: var(--color-primary);
  color: var(--color-primary-content);
  font-weight: 600;
}

.preset-btn-active:hover:not(:disabled) {
  border-color: var(--color-primary);
  background-color: var(--color-primary);
  transform: translateY(-1px);
}

/* 禁用状态 */
.preset-btn-disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.preset-btn-disabled:hover {
  transform: none;
  border-color: var(--color-base-300);
  background-color: var(--color-base-100);
}

/* 深色模式 */
.dark .preset-btn {
  border-color: var(--color-base-300);
  background-color: var(--color-base-200);
  color: var(--color-base-content);
}

.dark .preset-btn:hover:not(:disabled) {
  background-color: var(--color-base-300);
}

.dark .preset-btn-active {
  border-color: var(--color-primary);
  background-color: var(--color-primary);
  color: var(--color-primary-content);
}

/* 移动端适配 */
@media (max-width: 768px) {
  .preset-buttons {
    gap: 0.375rem;
  }

  .preset-btn {
    padding: 0.25rem 0.5rem;
    font-size: 0.75rem;
  }

  .preset-btn-small {
    padding: 0.2rem 0.4rem;
    font-size: 0.7rem;
  }
}
</style>
