<script setup lang="ts" generic="T extends string | number | boolean | null | undefined">
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
    6: 'grid-cols-6',
  };
  return cols[props.gridCols];
});

const sizeClass = computed(() => {
  const sizes = {
    small: 'icon-btn-small',
    medium: 'icon-btn-medium',
    large: 'icon-btn-large',
  };
  return sizes[props.size];
});

const themeClass = computed(() => {
  const themes = {
    primary: 'icon-btn-theme-primary',
    error: 'icon-btn-theme-error',
    info: 'icon-btn-theme-info',
    success: 'icon-btn-theme-success',
    warning: 'icon-btn-theme-warning',
  };
  return themes[props.theme];
});
</script>

<template>
  <div class="icon-button-group" :class="gridClass">
    <button
      v-for="option in options"
      :key="String(option.value)"
      type="button"
      :title="option.label"
      class="icon-btn"
      :class="[
        sizeClass,
        {
          'icon-btn-active': modelValue === option.value,
          [themeClass]: modelValue === option.value,
          'icon-btn-disabled': disabled,
        },
      ]"
      :disabled="disabled"
      @click="handleSelect(option.value)"
    >
      <component :is="option.icon" class="icon-btn-icon" />
    </button>
  </div>
</template>

<style scoped>
/* 容器 - 网格布局 */
.icon-button-group {
  display: grid;
  gap: 0.5rem;
  width: 100%;
}

.grid-cols-2 {
  grid-template-columns: repeat(2, minmax(0, 1fr));
}

.grid-cols-3 {
  grid-template-columns: repeat(3, minmax(0, 1fr));
}

.grid-cols-4 {
  grid-template-columns: repeat(4, minmax(0, 1fr));
}

.grid-cols-5 {
  grid-template-columns: repeat(5, minmax(0, 1fr));
}

.grid-cols-6 {
  grid-template-columns: repeat(6, minmax(0, 1fr));
}

/* 按钮基础样式 */
.icon-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  border: 2px solid var(--color-base-300);
  border-radius: 0.875rem;
  background-color: var(--color-base-100);
  color: var(--color-base-content);
  cursor: pointer;
  transition: all 0.25s cubic-bezier(0.4, 0, 0.2, 1);
  aspect-ratio: 1 / 1; /* 保持正方形 */
  width: 100%;
  box-shadow: 0 1px 2px 0 rgba(0, 0, 0, 0.05);
}

.icon-btn:hover:not(:disabled):not(.icon-btn-active) {
  border-color: var(--color-primary-soft);
  background-color: var(--color-base-200);
  transform: translateY(-2px) scale(1.02);
  box-shadow: 0 4px 12px -2px rgba(0, 0, 0, 0.15);
}

.icon-btn:active:not(:disabled) {
  transform: translateY(0) scale(0.98);
}

/* 尺寸变体 */
.icon-btn-small {
  padding: 0.5rem;
  /* aspect-ratio 会自动计算高度 */
}

.icon-btn-medium {
  padding: 0.75rem;
  /* aspect-ratio 会自动计算高度 */
}

.icon-btn-large {
  padding: 1rem;
  /* aspect-ratio 会自动计算高度 */
}

/* 图标样式 */
.icon-btn-icon {
  stroke-width: 2;
  flex-shrink: 0;
}

/* 图标尺寸 */
.icon-btn-small .icon-btn-icon {
  width: 1.25rem;
  height: 1.25rem;
  stroke-width: 2.25;
}

.icon-btn-medium .icon-btn-icon {
  width: 1.5rem;
  height: 1.5rem;
  stroke-width: 2;
}

.icon-btn-large .icon-btn-icon {
  width: 2rem;
  height: 2rem;
  stroke-width: 1.75;
}

/* 激活状态 */
.icon-btn-active {
  border-width: 2px;
  font-weight: 600;
  box-shadow: 0 4px 8px -2px rgba(0, 0, 0, 0.2), 0 0 0 1px rgba(0, 0, 0, 0.05);
  transform: scale(1.05);
}

/* 主题色 */
.icon-btn-theme-primary.icon-btn-active {
  border-color: var(--color-primary);
  background-color: var(--color-primary);
  color: var(--color-primary-content);
}

.icon-btn-theme-error.icon-btn-active {
  border-color: var(--color-error);
  background-color: var(--color-error);
  color: var(--color-error-content);
}

.icon-btn-theme-info.icon-btn-active {
  border-color: var(--color-info);
  background-color: var(--color-info);
  color: var(--color-info-content);
}

.icon-btn-theme-success.icon-btn-active {
  border-color: var(--color-success);
  background-color: var(--color-success);
  color: var(--color-success-content);
}

.icon-btn-theme-warning.icon-btn-active {
  border-color: var(--color-warning);
  background-color: var(--color-warning);
  color: var(--color-warning-content);
}

/* 禁用状态 */
.icon-btn-disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.icon-btn-disabled:hover {
  transform: none;
  border-color: var(--color-base-300);
  background-color: var(--color-base-100);
  box-shadow: none;
}

/* 深色模式 */
.dark .icon-btn {
  border-color: var(--color-base-300);
  background-color: var(--color-base-200);
  color: var(--color-base-content);
}

.dark .icon-btn:hover:not(:disabled) {
  background-color: var(--color-base-300);
}

/* 移动端适配 */
@media (max-width: 768px) {
  .icon-button-group {
    gap: 0.375rem;
  }

  /* 5列布局时减小间距 */
  .grid-cols-5 {
    gap: 0.25rem;
  }

  .icon-btn {
    border-radius: 0.75rem;
    /* 移动端触摸目标至少44x44px */
    min-height: 2.75rem;
  }

  /* 5列布局时适当减小按钮尺寸 */
  .grid-cols-5 .icon-btn {
    min-height: 2.5rem;
  }

  .icon-btn-small {
    padding: 0.5rem;
    /* aspect-ratio 保持正方形 */
  }

  .icon-btn-small .icon-btn-icon {
    width: 1.125rem;
    height: 1.125rem;
    stroke-width: 2.5;
  }

  .icon-btn-medium {
    padding: 0.625rem;
    /* aspect-ratio 保持正方形 */
  }

  .icon-btn-medium .icon-btn-icon {
    width: 1.375rem;
    height: 1.375rem;
    stroke-width: 2.25;
  }

  .icon-btn-large {
    padding: 0.875rem;
    /* aspect-ratio 保持正方形 */
  }

  .icon-btn-large .icon-btn-icon {
    width: 1.75rem;
    height: 1.75rem;
    stroke-width: 2;
  }

  /* 移动端减少动画效果，避免过度占用性能 */
  .icon-btn:hover:not(:disabled):not(.icon-btn-active) {
    transform: none;
    box-shadow: 0 2px 6px -1px rgba(0, 0, 0, 0.1);
  }

  .icon-btn-active {
    transform: scale(1.02);
  }
}
</style>
