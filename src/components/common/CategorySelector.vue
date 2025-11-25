<script setup lang="ts">
import { useCategoryStore } from '@/stores/money';
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

const categoryStore = useCategoryStore();
const mergedCategories = computed(() => {
  return props.categories ?? categoryStore.uiCategories;
});
const mergedQuickCategories = computed(() => {
  return props.customQuickCategories?.length ? props.customQuickCategories : mergedCategories.value.slice(0, 6);
});

// 响应式状态
const selectedCategories = ref<string[]>(props.modelValue);
const inputId = useId();
const showAllCategories = ref(false);

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
      <div class="quick-select-label">
        {{ quickSelectLabel }}
      </div>
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

    <!-- 全部分类列表 -->
    <div v-if="mergedCategories.length > 0" class="mb-3">
      <div class="all-categories-header">
        <div class="all-categories-label">
          全部分类
        </div>
        <button
          type="button"
          class="toggle-btn"
          @click="showAllCategories = !showAllCategories"
        >
          {{ showAllCategories ? '收起' : '展开' }}
          <span class="toggle-icon">{{ showAllCategories ? '▲' : '▼' }}</span>
        </button>
      </div>
      <div v-show="showAllCategories" class="all-categories-container">
        <button
          v-for="category in mergedCategories"
          :key="category.code"
          type="button"
          class="category-item"
          :class="{
            'category-item-active': isCategorySelected(category.code),
          }"
          :disabled="disabled"
          :title="t(`common.categories.${lowercaseFirstLetter(category.code)}`)"
          @click="toggleCategory(category.code)"
        >
          <span v-if="showIcons" class="category-icon">{{ category.icon }}</span>
          <span class="category-name">{{ t(`common.categories.${lowercaseFirstLetter(category.code)}`) }}</span>
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
  margin-bottom: 0;
}

.category-selector select {
  height: 8rem; /* 32 * 0.25rem */
  outline: none;
}

/* 标签样式 */
.quick-select-label,
.all-categories-label {
  font-size: 0.8125rem;
  font-weight: 500;
  color: var(--color-base-content);
  opacity: 0.8;
}

/* 全部分类头部 */
.all-categories-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 0.5rem;
}

/* 展开/折叠按钮 */
.toggle-btn {
  display: flex;
  align-items: center;
  gap: 0.25rem;
  padding: 0.25rem 0.5rem;
  font-size: 0.75rem;
  color: var(--color-primary);
  background: transparent;
  border: none;
  cursor: pointer;
  transition: all 0.2s;
}

.toggle-btn:hover {
  opacity: 0.7;
}

.toggle-icon {
  font-size: 0.625rem;
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

/* 全部分类容器 */
.all-categories-container {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(75px, 1fr));
  gap: 0.25rem;
  max-height: none;
  overflow-y: visible;
  padding: 0.375rem;
  background: var(--color-base-200);
  border-radius: 0.375rem;
}

/* 分类项按钮 */
.category-item {
  display: flex;
  align-items: center;
  gap: 0.25rem;
  padding: 0.375rem 0.5rem;
  border-radius: 0.25rem;
  border: 1px solid var(--color-base-300);
  background-color: var(--color-base-100);
  color: var(--color-base-content);
  cursor: pointer;
  transition: all 0.2s;
  font-size: 0.75rem;
}

.category-item:hover {
  border-color: var(--color-primary);
  background-color: var(--color-primary-soft);
  transform: translateY(-1px);
}

.category-item-active {
  background-color: var(--color-primary);
  border-color: var(--color-primary);
  color: var(--color-primary-content);
}

.category-icon {
  font-size: 0.875rem;
  flex-shrink: 0;
}

.category-name {
  flex: 1;
  text-align: left;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
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

  .all-categories-container {
    grid-template-columns: repeat(auto-fill, minmax(70px, 1fr));
  }

  .category-item {
    padding: 0.25rem 0.375rem;
    font-size: 0.6875rem;
  }

  .category-icon {
    font-size: 0.75rem;
  }
}
</style>
