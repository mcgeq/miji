<script setup lang="ts">
import Select from '@/components/ui/Select.vue';
import { PrioritySchema } from '@/schema/common';
import type { SelectOption } from '@/components/ui/Select.vue';
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

// 转换为 Select 组件的选项格式
const selectOptions = computed<SelectOption[]>(() => {
  return priorityOptions.value.map(option => ({
    value: option.value,
    label: option.label,
    disabled: option.disabled,
  }));
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
function handleChange(value: string | number | (string | number)[]) {
  // Select 组件在单选模式下只返回单个值
  const priorityValue = value as Priority;

  if (validateValue(priorityValue)) {
    currentValue.value = priorityValue;
    emit('update:modelValue', priorityValue);
    emit('change', priorityValue);
    emit('validate', true);
  } else {
    emit('validate', false);
  }
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

// 公开方法 - Select 组件内部管理 focus
function focus() {
  // TODO: 如果需要，可以通过 ref 访问 Select 组件
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
  <div class="mb-2 flex items-center justify-between max-sm:flex-wrap">
    <label class="text-sm font-medium text-[light-dark(#374151,#d1d5db)] mb-0 max-sm:shrink-0">
      {{ label }}
      <span v-if="required" class="text-[var(--color-error)] ml-1" aria-label="必填">*</span>
    </label>

    <div class="max-sm:flex-1 max-sm:min-w-0" :class="[widthClass]">
      <Select
        :model-value="currentValue"
        :options="selectOptions"
        :placeholder="label"
        size="sm"
        :disabled="disabled"
        :required="required"
        :error="hasError ? errorMessage : undefined"
        full-width
        @update:model-value="handleChange"
      />

      <!-- 帮助文本 -->
      <div
        v-if="helpText && !hasError"
        class="mt-2 text-xs text-[light-dark(#6b7280,#9ca3af)] text-right"
      >
        {{ helpText }}
      </div>
    </div>
  </div>
</template>
