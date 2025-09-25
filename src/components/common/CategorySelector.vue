<script setup lang="ts">
import { lowercaseFirstLetter } from '@/utils/common';
import type { CategoryDefinition } from '@/constants/commonConstant';

// Props 接口
export interface CategorySelectorProps {
  modelValue?: string[];
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

// Props 默认值
const props = withDefaults(defineProps<CategorySelectorProps>(), {
  modelValue: () => ([]),
  label: '分类',
  placeholder: '请选择分类',
  helpText: '',
  required: false,
  disabled: false,
  locale: 'zh-CN',
  categories: undefined,
  errorMessage: '',
  size: 'base',
  width: 'full',
  showIcons: true,
  multiple: true,
  showQuickSelect: true,
  quickSelectLabel: '常用分类',
  customQuickCategories: undefined,
});

// 事件定义
const emit = defineEmits<{
  (e: 'update:modelValue', value: string[]): void;
  (e: 'change', value: string[]): void;
  (e: 'validate', isValid: boolean): void;
}>();

const moneyStore = useMoneyStore();
const mergedCategories = computed(() => {
  return props.categories ?? moneyStore.uiCategories;
});
const mergedQuickCategories = computed(() => {
  return props.customQuickCategories?.length ? props.customQuickCategories : mergedCategories.value.slice(0, 6);
});

// 响应式状态
const selectedCategories = ref<string[]>(props.modelValue);
const inputId = useId();

const { t } = useI18n();
// 计算属性：快捷选择分类
const quickSelectCategories = computed<CategoryDefinition[]>(() => {
  return mergedQuickCategories.value;
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
      <div class="quick-select-container">
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
          :title="t(`common.categories.${lowercaseFirstLetter(category.code)}`)"
          @click="selectQuickCategory(category.code)"
        >
          {{ category.icon }}
        </button>
      </div>
    </div>

    <!-- 错误提示 -->
    <div
      v-if="errorMessage"
      :id="`${inputId}-error`"
      class="error-message"
      role="alert"
      aria-live="polite"
    >
      {{ errorMessage }}
    </div>

    <!-- 帮助文本 -->
    <div v-if="helpText" class="help-text">
      {{ helpText }}
    </div>
  </div>
</template>

<style scoped>
.category-selector {
  margin-bottom: 1rem;
}

.category-selector select {
  height: 8rem; /* 32 * 0.25rem */
  outline: none;
}

/* 快捷选择容器 */
.quick-select-container {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
}

/* 快捷选择按钮 */
.quick-select-btn {
  font-size: 0.75rem;
  padding: 0.5rem 0.75rem;
  border-radius: 0.375rem;
  border: 1px solid var(--color-neutral);
  background-color: var(--color-base-100);
  color: var(--color-base-content);
  cursor: pointer;
  transition: all 0.2s ease-in-out;
}

.quick-select-btn:hover {
  background-color: var(--color-base-200);
  border-color: var(--color-neutral);
}

.quick-select-btn:focus {
  outline: none;
  border-color: transparent;
  box-shadow: 0 0 0 2px var(--color-primary);
}

.quick-select-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

/* 激活状态 */
.quick-select-btn-active {
  background-color: var(--color-primary-soft);
  border-color: var(--color-primary);
  color: var(--color-primary-content);
}

/* 多选状态 */
.quick-select-btn-multiple {
  position: relative;
}

.quick-select-btn-multiple::after {
  content: "✓";
  position: absolute;
  top: -0.25rem;
  right: -0.25rem;
  background-color: var(--color-primary);
  color: var(--color-primary-content);
  border-radius: 9999px;
  width: 1rem;
  height: 1rem;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 0.75rem;
}

/* 错误提示 */
.error-message {
  font-size: 0.875rem;
  margin-top: 0.25rem;
  color: var(--color-error);
}

/* 帮助文本 */
.help-text {
  font-size: 0.75rem;
  margin-top: 0.5rem;
  color: var(--color-neutral);
}

/* 滚动条样式 */
.category-selector select::-webkit-scrollbar {
  width: 8px;
}

.category-selector select::-webkit-scrollbar-track {
  background-color: var(--color-base-200);
}

.category-selector select::-webkit-scrollbar-thumb {
  background-color: var(--color-neutral);
  border-radius: 0.375rem;
}

.category-selector select::-webkit-scrollbar-thumb:hover {
  background-color: var(--color-base-content);
}

/* 响应式：小屏幕 */
@media (max-width: 640px) {
  .category-selector select {
    width: 100% !important;
  }

  .quick-select-btn {
    font-size: 0.75rem;
    padding: 0.25rem 0.5rem;
  }
}
</style>
