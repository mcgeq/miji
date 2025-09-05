<script setup lang="ts">
import { DEFAULT_BUDGET_CATEGORIES } from '@/constants/commonConstant';
import type { CategoryDefinition } from '@/constants/commonConstant';
import type { Category } from '@/schema/common';

// Props 默认值
const props = withDefaults(defineProps<CategorySelectorProps>(), {
  modelValue: () => ([]),
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
  showQuickSelect: true,
  quickSelectLabel: '常用分类',
  customQuickCategories: () => DEFAULT_BUDGET_CATEGORIES.slice(0, 6),
});
// 事件定义
const emit = defineEmits<{
  (e: 'update:modelValue', value: string[]): void;
  (e: 'change', value: string[]): void;
  (e: 'validate', isValid: boolean): void;
}>();
// Props 接口
export interface CategorySelectorProps {
  modelValue?: Category[];
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
  showQuickSelect?: boolean;
  quickSelectLabel?: string;
  customQuickCategories?: CategoryDefinition[];
}

// 响应式状态
const selectedCategories = ref<string[]>(props.modelValue);
const inputId = useId();

// 计算属性：快捷选择分类
const quickSelectCategories = computed<CategoryDefinition[]>(() => {
  return props.customQuickCategories.length > 0
    ? props.customQuickCategories
    : props.categories;
});

// 计算属性：验证状态
const isValid = computed(() => {
  if (!props.required) return true;
  return props.multiple
    ? selectedCategories.value.length > 0
    : selectedCategories.value.length > 0;
});

// 事件处理：选择/取消选择分类
function toggleCategory(categoryCode: string) {
  if (props.disabled) return;

  const index = selectedCategories.value.indexOf(categoryCode);

  if (index === -1) {
    // 添加分类
    if (props.multiple) {
      selectedCategories.value.push(categoryCode);
    } else {
      selectedCategories.value = [categoryCode];
    }
  } else {
    // 移除分类
    if (props.multiple) {
      selectedCategories.value.splice(index, 1);
    } else {
      selectedCategories.value = [];
    }
  }

  // 触发事件
  emit('update:modelValue', selectedCategories.value);
  emit('change', selectedCategories.value);
  emit('validate', isValid.value);
}

// 事件处理：选择快捷分类
function selectQuickCategory(categoryCode: string) {
  if (props.disabled) return;

  if (props.multiple) {
    // 多选模式：切换选择状态
    toggleCategory(categoryCode);
  } else {
    // 单选模式：直接选择
    selectedCategories.value = [categoryCode];
    emit('update:modelValue', selectedCategories.value);
    emit('change', selectedCategories.value);
    emit('validate', isValid.value);
  }
}

// 检查分类是否已选择
function isCategorySelected(categoryCode: string): boolean {
  return selectedCategories.value.includes(categoryCode);
}

// 监听器
watch(
  () => props.modelValue,
  newValue => {
    selectedCategories.value = newValue;
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
    selectedCategories.value = [];
    emit('update:modelValue', []);
    emit('change', []);
    emit('validate', isValid.value);
  },
});
</script>

<template>
  <div class="category-selector">
    <!-- 快捷选择区域 -->
    <div
      v-if="showQuickSelect && quickSelectCategories.length > 0"
      class="mb-3"
      role="group"
      :aria-label="quickSelectLabel"
    >
      <div class="flex flex-wrap gap-2">
        <button
          v-for="category in quickSelectCategories"
          :key="category.code"
          type="button"
          class="quick-select-btn"
          :class="{
            'quick-select-btn-active': isCategorySelected(category.code),
            'quick-select-btn-multiple': multiple && isCategorySelected(category.code),
          }"
          :disabled="disabled"
          :title="category.nameZh"
          @click="selectQuickCategory(category.code)"
        >
          {{ category.icon }}
        </button>
      </div>
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
.category-selector {
  @apply mb-4;
}

.category-selector select {
  @apply h-32;
}

/* 快捷选择按钮样式 */
.quick-select-btn {
  @apply text-xs px-3 py-2 rounded-md border border-gray-200 dark:border-gray-600
         bg-white dark:bg-gray-800 text-gray-700 dark:text-gray-300
         hover:bg-gray-50 dark:hover:bg-gray-700 hover:border-gray-300 dark:hover:border-gray-500
         focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent
         transition-all duration-200 cursor-pointer
         disabled:opacity-50 disabled:cursor-not-allowed;
}

.quick-select-btn-active {
  @apply bg-blue-50 dark:bg-blue-900/30 border-blue-200 dark:border-blue-600
         text-blue-700 dark:text-blue-300;
}

.quick-select-btn-multiple {
  @apply relative;
}

.quick-select-btn-multiple::after {
  content: "✓";
  @apply absolute -top-1 -right-1 bg-blue-500 text-white rounded-full w-4 h-4
         flex items-center justify-center text-xs;
}

/* 选择框样式优化 */
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

  .quick-select-btn {
    @apply text-xs px-2 py-1;
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
