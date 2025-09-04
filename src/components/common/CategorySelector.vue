<script setup lang="ts">
import { computed, ref, watch, useId } from 'vue';
import { DEFAULT_BUDGET_CATEGORIES } from '@/schema/common';
import type { CategoryDefinition } from '@/schema/common';

const { t } = useI18n();
// Props 接口
export interface CategorySelectorProps {
  modelValue: {
    includedCategories: string[];
    excludedCategories: string[];
  };
  label?: string;
  placeholder?: string;
  helpText?: string;
  required?: boolean;
  disabled?: boolean;
  locale?: 'zh-CN' | 'en';
  categories?: CategoryDefinition[];
  errorMessage?: string;
  size?: 'sm' | 'base' | 'lg';
  width?: 'full' | 'auto' | '2/3' | '1/2' | '1/3';
  showIcons?: boolean;
  multiple?: boolean;
}

// Emits 接口
export interface CategorySelectorEmits {
  (e: 'update:modelValue', value: { includedCategories: string[]; excludedCategories: string[] }): void;
  (e: 'change', value: { includedCategories: string[]; excludedCategories: string[] }): void;
  (e: 'validate', isValid: boolean): void;
}

// Props 默认值
const props = withDefaults(defineProps<CategorySelectorProps>(), {
  modelValue: () => ({ includedCategories: [], excludedCategories: [] }),
  label: '分类',
  placeholder: '请选择分类',
  helpText: '',
  required: false,
  disabled: false,
  locale: 'zh-CN',
  categories: () => DEFAULT_BUDGET_CATEGORIES,
  errorMessage: '',
  size: 'base',
  width: 'full',
  showIcons: true,
  multiple: true,
});

// 事件定义
const emit = defineEmits<CategorySelectorEmits>();

// 响应式状态
const includedCategories = ref<string[]>(props.modelValue.includedCategories);
const excludedCategories = ref<string[]>(props.modelValue.excludedCategories);
const inputId = useId();

// 计算属性：选择框样式
const selectClasses = computed(() => {
  const baseClasses = ['modal-input-select', 'transition-normal'];
  const sizeClasses = {
    sm: 'input-sm',
    base: '',
    lg: 'input-lg',
  };
  const widthClasses = {
    'full': 'w-full',
    'auto': 'w-auto',
    '2/3': 'w-2/3',
    '1/2': 'w-1/2',
    '1/3': 'w-1/3',
  };

  const classes = [...baseClasses, sizeClasses[props.size], widthClasses[props.width]];

  if (props.errorMessage) classes.push('border-red-500', 'focus:ring-red-500');
  if (props.disabled) classes.push('opacity-50', 'cursor-not-allowed');

  return classes.filter(Boolean).join(' ');
});

// 计算属性：显示的分类选项
const displayCategories = computed(() => {
  return props.categories.map(category => ({
    code: category.code,
    name: props.locale === 'zh-CN' ? category.nameZh : category.nameEn,
    icon: category.icon,
  }));
});

// 计算属性：验证状态
const isValid = computed(() => {
  if (!props.required) return true;
  return props.multiple
    ? includedCategories.value.length > 0 || excludedCategories.value.length > 0
    : includedCategories.value.length > 0;
});

// 工具方法：获取显示名称
function getDisplayName(category: { code: string; name: string; icon?: string }): string {
  return props.showIcons && category.icon ? `${category.icon} ${category.name}` : category.name;
}

// 事件处理
function handleIncludedChange(event: Event) {
  const target = event.target as HTMLSelectElement;
  const values = props.multiple ? Array.from(target.selectedOptions).map(option => option.value) : [target.value];

  includedCategories.value = values;
  // 确保包含和排除分类互斥
  excludedCategories.value = excludedCategories.value.filter(c => !values.includes(c));

  const newValue = { includedCategories: includedCategories.value, excludedCategories: excludedCategories.value };
  emit('update:modelValue', newValue);
  emit('change', newValue);
  emit('validate', isValid.value);
}

function handleExcludedChange(event: Event) {
  const target = event.target as HTMLSelectElement;
  const values = props.multiple ? Array.from(target.selectedOptions).map(option => option.value) : [target.value];

  excludedCategories.value = values;
  // 确保包含和排除分类互斥
  includedCategories.value = includedCategories.value.filter(c => !values.includes(c));

  const newValue = { includedCategories: includedCategories.value, excludedCategories: excludedCategories.value };
  emit('update:modelValue', newValue);
  emit('change', newValue);
  emit('validate', isValid.value);
}

// 监听器
watch(
  () => props.modelValue,
  newValue => {
    includedCategories.value = newValue.includedCategories;
    excludedCategories.value = newValue.excludedCategories;
  },
  { immediate: true, deep: true },
);

// 验证状态变化
watch(
  isValid,
  valid => {
    emit('validate', valid);
  },
  { immediate: true },
);

// 暴露组件方法
defineExpose({
  validate: () => isValid.value,
  reset: () => {
    includedCategories.value = [];
    excludedCategories.value = [];
    emit('update:modelValue', { includedCategories: [], excludedCategories: [] });
    emit('change', { includedCategories: [], excludedCategories: [] });
    emit('validate', isValid.value);
  },
});
</script>

<template>
  <div class="category-selector">
    <!-- 包含的分类 -->
    <div class="mb-4">
      <label :for="`${inputId}-included`" class="mb-2 text-sm text-gray-700 font-medium dark:text-gray-300">
        {{ t('financial.budget.includedCategories') }}
        <span v-if="required" class="ml-1 text-red-500" aria-label="必填">*</span>
      </label>
      <select
        :id="`${inputId}-included`"
        v-model="includedCategories"
        :multiple="multiple"
        :required="required"
        :disabled="disabled"
        :class="selectClasses"
        :aria-invalid="!!errorMessage"
        :aria-describedby="errorMessage ? `${inputId}-error` : undefined"
        @change="handleIncludedChange"
      >
        <option value="" disabled>
          {{ placeholder }}
        </option>
        <option v-for="category in displayCategories" :key="category.code" :value="category.code">
          {{ getDisplayName(category) }}
        </option>
      </select>
    </div>

    <!-- 排除的分类 -->
    <div class="mb-4">
      <label :for="`${inputId}-excluded`" class="mb-2 text-sm text-gray-700 font-medium dark:text-gray-300">
        {{ t('financial.budget.excludedCategories') }}
        <span v-if="required" class="ml-1 text-red-500" aria-label="必填">*</span>
      </label>
      <select
        :id="`${inputId}-excluded`"
        v-model="excludedCategories"
        :multiple="multiple"
        :required="required"
        :disabled="disabled"
        :class="selectClasses"
        :aria-invalid="!!errorMessage"
        :aria-describedby="errorMessage ? `${inputId}-error` : undefined"
        @change="handleExcludedChange"
      >
        <option value="" disabled>
          {{ placeholder }}
        </option>
        <option v-for="category in displayCategories" :key="category.code" :value="category.code">
          {{ getDisplayName(category) }}
        </option>
      </select>
    </div>

    <!-- 错误提示 -->
    <div v-if="errorMessage" :id="`${inputId}-error`" class="mt-1 text-sm text-red-600 dark:text-red-400" role="alert" aria-live="polite">
      {{ errorMessage }}
    </div>

    <!-- 帮助文本 -->
    <div v-if="helpText" class="mt-2 text-xs text-gray-500 dark:text-gray-400">
      {{ helpText }}
    </div>
  </div>
</template>

<style scoped lang="postcss">
.category-selector select {
  @apply h-32;
}

.category-selector select:focus {
  outline: none;
}

.dark .category-selector select option {
  background-color: theme('colors.gray.800');
  color: theme('colors.white');
}

.category-selector select:focus-visible {
  outline: 2px solid theme('colors.blue.500');
  outline-offset: 2px;
}

@media (max-width: 640px) {
  .category-selector select {
    width: 100% !important;
  }
}

.category-selector select::-webkit-scrollbar {
  width: 8px;
}

.category-selector select::-webkit-scrollbar-track {
  @apply bg-gray-100 dark:bg-gray-700;
}

.category-selector select::-webkit-scrollbar-thumb {
  @apply bg-gray-300 dark:bg-gray-500 rounded-md;
}

.category-selector select::-webkit-scrollbar-thumb:hover {
  @apply bg-gray-400 dark:bg-gray-400;
}
</style>
