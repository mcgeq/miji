<script setup lang="ts">
import { PrioritySchema } from '@/schema/common';
import { uuid } from '@/utils/uuid';
import type { Priority } from '@/schema/common';

interface PriorityOption {
  value: Priority;
  label: string;
  icon: string;
  color: string;
  disabled?: boolean;
}

interface Props {
  modelValue: Priority;
  label?: string;
  required?: boolean;
  disabled?: boolean;
  errorMessage?: string;
  helpText?: string;
  width?: string;
  locale?: 'zh-CN' | 'en';
  showIcons?: boolean;
  customOptions?: PriorityOption[];
}

const props = withDefaults(defineProps<Props>(), {
  label: '优先级',
  required: false,
  disabled: false,
  errorMessage: '',
  helpText: '',
  width: '2/3',
  locale: 'zh-CN',
  showIcons: true,
  customOptions: undefined,
});

const emit = defineEmits<{
  'update:modelValue': [value: Priority];
  'change': [value: Priority];
  'validate': [isValid: boolean];
}>();

// 生成唯一ID
const inputId = ref(`priority-selector-${uuid(38)}`);

// 当前值
const currentValue = ref<Priority>(props.modelValue);

// 国际化配置
const i18nConfig = {
  'zh-CN': {
    Low: '低',
    Medium: '中',
    High: '高',
    Urgent: '紧急',
  },
  'en': {
    Low: 'Low',
    Medium: 'Medium',
    High: 'High',
    Urgent: 'Urgent',
  },
};

// 优先级选项配置
const defaultPriorityOptions = computed<PriorityOption[]>(() => {
  const baseOptions: PriorityOption[] = [
    {
      value: 'Low',
      label: props.showIcons
        ? `🟢 ${i18nConfig[props.locale].Low}`
        : i18nConfig[props.locale].Low,
      icon: '🟢',
      color: 'text-green-600',
    },
    {
      value: 'Medium',
      label: props.showIcons
        ? `🟡 ${i18nConfig[props.locale].Medium}`
        : i18nConfig[props.locale].Medium,
      icon: '🟡',
      color: 'text-yellow-600',
    },
    {
      value: 'High',
      label: props.showIcons
        ? `🟠 ${i18nConfig[props.locale].High}`
        : i18nConfig[props.locale].High,
      icon: '🟠',
      color: 'text-orange-600',
    },
    {
      value: 'Urgent',
      label: props.showIcons
        ? `🔴 ${i18nConfig[props.locale].Urgent}`
        : i18nConfig[props.locale].Urgent,
      icon: '🔴',
      color: 'text-red-600',
    },
  ];

  return baseOptions;
});

// 优先级选项（支持自定义）
const priorityOptions = computed(() => {
  return props.customOptions || defaultPriorityOptions.value;
});

// 样式类
const widthClass = computed(() => {
  const widthMap: Record<string, string> = {
    'full': 'w-full',
    '1/2': 'w-1/2',
    '1/3': 'w-1/3',
    '2/3': 'w-2/3',
    '1/4': 'w-1/4',
    '3/4': 'w-3/4',
  };
  return widthMap[props.width] || 'w-2/3';
});

// 错误状态
const hasError = computed(() => {
  return !!(props.errorMessage && props.errorMessage.trim());
});

// 验证函数
function validateValue(value: Priority): boolean {
  if (props.required && !value) {
    return false;
  }

  // 验证是否是有效的优先级值
  try {
    PrioritySchema.parse(value);
    return true;
  } catch {
    return false;
  }
}

// 事件处理
function handleChange(event: Event) {
  const target = event.target as HTMLSelectElement;
  const value = target.value as Priority;

  if (validateValue(value)) {
    currentValue.value = value;
    emit('update:modelValue', value);
    emit('change', value);
    emit('validate', true);
  } else {
    emit('validate', false);
  }
}

function handleBlur() {
  const isValid = validateValue(currentValue.value);
  emit('validate', isValid);
}

// 监听器
watch(
  () => props.modelValue,
  newValue => {
    if (newValue !== currentValue.value) {
      currentValue.value = newValue;
    }
  },
  { immediate: true },
);

// 监听当前值变化，确保同步
watch(currentValue, newValue => {
  if (newValue !== props.modelValue) {
    emit('update:modelValue', newValue);
  }
});

// 公开方法
function focus() {
  const element = document.getElementById(inputId.value);
  if (element) {
    element.focus();
  }
}

function reset() {
  currentValue.value = 'Medium'; // 默认值
  emit('update:modelValue', 'Medium');
  emit('change', 'Medium');
  emit('validate', true);
}

// 获取当前选中的优先级信息
function getCurrentPriorityInfo() {
  return priorityOptions.value.find(
    option => option.value === currentValue.value,
  );
}

// 暴露给父组件的方法
defineExpose({
  focus,
  reset,
  getCurrentPriorityInfo,
  validate: () => validateValue(currentValue.value),
});
</script>

<template>
  <div class="form-group">
    <label
      :for="inputId"
      class="form-label"
    >
      {{ label }}
      <span v-if="required" class="form-required" aria-label="必填">*</span>
    </label>

    <div class="form-field" :class="widthClass">
      <select
        :id="inputId"
        v-model="currentValue"
        class="modal-input-select"
        :class="{ 'is-error': hasError }"
        :required="required"
        :disabled="disabled"
        @blur="handleBlur"
        @change="handleChange"
      >
        <option
          v-for="option in priorityOptions"
          :key="option.value"
          :value="option.value"
          :disabled="option.disabled"
        >
          {{ option.label }}
        </option>
      </select>

      <!-- 错误提示 -->
      <div
        v-if="hasError && errorMessage"
        class="form-error"
        role="alert"
      >
        {{ errorMessage }}
      </div>

      <!-- 帮助文本 -->
      <div
        v-if="helpText && !hasError"
        class="form-help"
      >
        {{ helpText }}
      </div>
    </div>
  </div>
</template>

<style scoped lang="postcss">
/* 容器 */
.form-group {
  margin-bottom: 0.5rem; /* mb-2 */
  display: flex;
  align-items: center;
  justify-content: space-between;
}

/* 标签 */
.form-label {
  font-size: 0.875rem; /* text-sm */
  font-weight: 500; /* font-medium */
  color: var(--color-gray-700);
  margin-bottom: 0.5rem;
}
.form-required {
  color: var(--color-error);
  margin-left: 0.25rem;
}

/* 字段容器 */
.form-field {
  display: flex;
  flex-direction: column;
}

/* 下拉框 */
.modal-input-select {
  padding: 0.5rem 0.75rem; /* px-3 py-2 */
  border: 1px solid var(--color-base-300);
  border-radius: 0.375rem; /* rounded-md */
  background: var(--color-base-100);
  color: var(--color-base-content);
  font-size: 0.875rem;
  line-height: 1.25rem;
  transition: border-color 0.2s ease, box-shadow 0.2s ease;
}
.modal-input-select:focus {
  outline: none;
  border-color: transparent;
  box-shadow: 0 0 0 2px var(--color-primary);
}
.modal-input-select.is-error {
  border-color: var(--color-error);
}
.modal-input-select.is-error:focus {
  box-shadow: 0 0 0 2px var(--color-error-soft);
}

/* 禁用状态 */
.modal-input-select:disabled {
  background: var(--color-base-200);
  color: var(--color-gray-500);
  cursor: not-allowed;
}

/* 下拉选项 */
.modal-input-select option {
  padding: 0.5rem 0.75rem;
}
.modal-input-select option:disabled {
  color: var(--color-gray-400);
}

/* 错误提示 */
.form-error {
  margin-top: 0.25rem;
  font-size: 0.875rem;
  color: var(--color-error);
}

/* 帮助文本 */
.form-help {
  margin-top: 0.5rem;
  font-size: 0.75rem;
  color: var(--color-gray-500);
  text-align: right;
}

/* 响应式 */
@media (max-width: 640px) {
  .form-group {
    flex-direction: column;
    align-items: stretch;
  }
  .form-label {
    margin-bottom: 0.25rem;
  }
}

/* 暗黑模式 */
@media (prefers-color-scheme: dark) {
  .form-label {
    color: var(--color-gray-300);
  }
  .modal-input-select {
    background: var(--color-gray-800);
    color: var(--color-gray-100);
    border-color: var(--color-gray-600);
  }
  .modal-input-select:focus {
    box-shadow: 0 0 0 2px var(--color-info);
  }
  .modal-input-select:disabled {
    background: var(--color-gray-700);
    color: var(--color-gray-400);
  }
  .form-error {
    color: var(--color-error);
  }
  .form-help {
    color: var(--color-gray-400);
  }
}
</style>
