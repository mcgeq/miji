<template>
  <div class="mb-2 flex items-center justify-between">
    <label
      :for="inputId"
      class="text-sm font-medium text-gray-700 dark:text-gray-300 mb-2"
    >
      {{ label }}
      <span v-if="required" class="text-red-500 ml-1" aria-label="必填">*</span>
    </label>
    <div class="flex flex-col" :class="widthClass">
      <select
        :id="inputId"
        v-model="currentValue"
        :class="[
          'modal-input-select',
          {
            'border-red-500': hasError,
            'border-gray-300 dark:border-gray-600': !hasError
          }
        ]"
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
      <div
        v-if="hasError && errorMessage"
        class="text-sm text-red-600 dark:text-red-400 mt-1"
        role="alert"
      >
        {{ errorMessage }}
      </div>
      <div
        v-if="helpText && !hasError"
        class="text-xs text-gray-500 dark:text-gray-400 mt-1"
      >
        {{ helpText }}
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { PrioritySchema, type Priority } from '@/schema/common';
import { uuid } from '@/utils/uuid';

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
  change: [value: Priority];
  validate: [isValid: boolean];
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
  en: {
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
    full: 'w-full',
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
const validateValue = (value: Priority): boolean => {
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
};

// 事件处理
const handleChange = (event: Event) => {
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
};

const handleBlur = () => {
  const isValid = validateValue(currentValue.value);
  emit('validate', isValid);
};

// 监听器
watch(
  () => props.modelValue,
  (newValue) => {
    if (newValue !== currentValue.value) {
      currentValue.value = newValue;
    }
  },
  { immediate: true },
);

// 监听当前值变化，确保同步
watch(currentValue, (newValue) => {
  if (newValue !== props.modelValue) {
    emit('update:modelValue', newValue);
  }
});

// 公开方法
const focus = () => {
  const element = document.getElementById(inputId.value);
  if (element) {
    element.focus();
  }
};

const reset = () => {
  currentValue.value = 'Medium'; // 默认值
  emit('update:modelValue', 'Medium');
  emit('change', 'Medium');
  emit('validate', true);
};

// 获取当前选中的优先级信息
const getCurrentPriorityInfo = () => {
  return priorityOptions.value.find(
    (option) => option.value === currentValue.value,
  );
};

// 暴露给父组件的方法
defineExpose({
  focus,
  reset,
  getCurrentPriorityInfo,
  validate: () => validateValue(currentValue.value),
});
</script>

<style scoped lang="postcss">
/* 基础样式 */
.modal-input-select {
  @apply px-3 py-2 border rounded-md bg-white dark:bg-gray-800 text-gray-900 dark:text-gray-100 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-transparent transition-colors;
}

/* 错误状态 */
.border-red-500:focus {
  @apply ring-2 ring-red-400 ring-opacity-50 border-red-500;
}

/* 禁用状态 */
.modal-input-select:disabled {
  @apply bg-gray-100 dark:bg-gray-700 text-gray-500 dark:text-gray-400 cursor-not-allowed;
}

/* 选项样式 */
.modal-input-select option {
  @apply py-2 px-3;
}

.modal-input-select option:disabled {
  @apply text-gray-400 dark:text-gray-500;
}

/* 响应式优化 */
@media (max-width: 640px) {
  .mb-2 .flex {
    flex-direction: column;
    align-items: stretch;
  }
  .mb-2 label {
    margin-bottom: 0.25rem;
  }
}

/* 深色模式优化 */
@media (prefers-color-scheme: dark) {
  .modal-input-select {
    @apply border-gray-600;
  }
  
  .modal-input-select:focus {
    @apply ring-blue-400;
  }
}
</style>
