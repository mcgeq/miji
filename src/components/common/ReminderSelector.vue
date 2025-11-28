<script setup lang="ts">
import Select from '@/components/ui/Select.vue';
import {
  DEFAULT_REMINDER_TYPES,
  POPULAR_REMINDER_TYPES,
} from '@/constants/commonConstant';
import type { SelectOption } from '@/components/ui/Select.vue';
import type { ReminderTypeI18 } from '@/constants/commonConstant';

// 组件 Props 接口
export interface ReminderSelectorProps {
  modelValue?: string;
  label?: string;
  placeholder?: string;
  helpText?: string;
  required?: boolean;
  disabled?: boolean;
  locale?: 'zh-CN' | 'en';
  reminderTypes?: ReminderTypeI18[];
  errorMessage?: string;
  size?: 'sm' | 'base' | 'lg';
  width?: 'full' | 'auto' | '2/3' | '1/2' | '1/3';
  showGrouped?: boolean;
  showQuickSelect?: boolean;
  showIcons?: boolean;
  quickSelectLabel?: string;
  popularOnly?: boolean;
  customQuickTypes?: ReminderTypeI18[];
  loading?: boolean;
}

// 组件 Emits 接口
export interface ReminderSelectorEmits {
  (e: 'update:modelValue', value: string): void;
  (e: 'change', value: string, type?: ReminderTypeI18): void;
  (e: 'blur', event: FocusEvent): void;
  (e: 'focus', event: FocusEvent): void;
  (e: 'validate', isValid: boolean): void;
}

// Props 默认值
const props = withDefaults(defineProps<ReminderSelectorProps>(), {
  modelValue: '',
  label: '提醒类型',
  placeholder: '请选择类型',
  helpText: '',
  required: false,
  disabled: false,
  locale: 'zh-CN',
  reminderTypes: () => DEFAULT_REMINDER_TYPES,
  errorMessage: '',
  size: 'base',
  width: '2/3',
  showGrouped: false,
  showQuickSelect: false,
  showIcons: false,
  quickSelectLabel: '快捷选择',
  popularOnly: false,
  customQuickTypes: () => [],
  loading: false,
});

// 事件定义
const emit = defineEmits<ReminderSelectorEmits>();

// 响应式状态
const selectedValue = ref<string>(props.modelValue);

// 显示的提醒类型列表
const displayTypes = computed(() => {
  if (props.popularOnly) {
    return POPULAR_REMINDER_TYPES.filter(type =>
      props.reminderTypes.some(rt => rt.code === type.code),
    );
  }
  return props.reminderTypes;
});

// 分组功能已由 Select 组件内部处理，这里不再需要

// 快捷选择类型
const quickSelectTypes = computed(() => {
  if (props.customQuickTypes.length > 0) {
    return props.customQuickTypes;
  }

  return POPULAR_REMINDER_TYPES.filter(type =>
    props.reminderTypes.some(rt => rt.code === type.code),
  ).slice(0, 6); // 限制显示数量
});

// 当前选中的类型对象
const selectedType = computed(() => {
  return props.reminderTypes.find(type => type.code === selectedValue.value);
});

// 验证状态
const isValid = computed(() => {
  if (!props.required)
    return true;
  return !!selectedValue.value;
});

// 工具方法
function getCurrentDisplayName(type: ReminderTypeI18): string {
  const name = props.locale === 'zh-CN' ? type.nameZh : type.nameEn;
  return props.showIcons && type.icon ? `${type.icon} ${name}` : name;
}

// 专门为快捷选择按钮准备的显示名称方法
function getQuickSelectDisplayName(type: ReminderTypeI18): string {
  const name = props.locale === 'zh-CN' ? type.nameZh : type.nameEn;
  // 快捷选择按钮中总是显示图标
  return type.icon ? `${type.icon} ${name}` : name;
}

// 事件处理
function handleChange(event: Event) {
  const target = event.target as HTMLSelectElement;
  const value = target.value;

  selectedValue.value = value;
  const typeObj = selectedType.value;

  emit('update:modelValue', value);
  emit('change', value, typeObj);

  // 触发验证
  nextTick(() => {
    emit('validate', isValid.value);
  });
}

// blur 和 focus 事件由 Select 组件内部处理

function selectQuickType(type: ReminderTypeI18) {
  if (props.disabled || props.loading)
    return;

  selectedValue.value = type.code;
  emit('update:modelValue', type.code);
  emit('change', type.code, type);

  // 触发验证
  nextTick(() => {
    emit('validate', isValid.value);
  });
}

// 公共方法 - Select 组件内部管理 focus/blur
function focus() {
  // TODO: 如果需要，可以通过 ref 访问 Select 组件
}

function blur() {
  // TODO: 如果需要，可以通过 ref 访问 Select 组件
}

function validate(): boolean {
  return isValid.value;
}

function reset() {
  selectedValue.value = '';
  emit('update:modelValue', '');
  emit('change', '', undefined);
  emit('validate', false);
}

// 监听器
watch(
  () => props.modelValue,
  newValue => {
    selectedValue.value = newValue;
  },
  { immediate: true },
);

// 监听验证状态变化
watch(
  isValid,
  valid => {
    emit('validate', valid);
  },
  { immediate: true },
);

// 转换为 Select 组件的选项格式
const selectOptions = computed<SelectOption[]>(() => {
  return displayTypes.value.map(type => ({
    value: type.code,
    label: getCurrentDisplayName(type),
    icon: props.showIcons ? type.icon : undefined,
  }));
});

// Select 尺寸映射
const selectSize = computed(() => {
  const sizeMap = {
    sm: 'sm' as const,
    base: 'md' as const,
    lg: 'lg' as const,
  };
  return sizeMap[props.size];
});

// 宽度类
const widthClass = computed(() => {
  const widthMap = {
    'full': 'w-full',
    'auto': 'w-auto',
    '2/3': 'w-2/3',
    '1/2': 'w-1/2',
    '1/3': 'w-1/3',
  };
  return widthMap[props.width];
});

// 暴露组件方法
defineExpose({
  focus,
  blur,
  validate,
  reset,
  selectedType,
  isValid,
});
</script>

<template>
  <div>
    <div class="mb-2 flex items-center justify-between max-sm:flex-wrap">
      <label class="text-sm font-medium text-[light-dark(#111827,#f9fafb)] max-sm:shrink-0">
        {{ label }}
        <span v-if="required" class="text-[var(--color-error)] ml-1" aria-label="必填">*</span>
      </label>

      <div class="max-sm:flex-1 max-sm:w-full" :class="[widthClass]">
        <Select
          :model-value="selectedValue"
          :options="selectOptions"
          :placeholder="placeholder"
          :size="selectSize"
          :disabled="disabled"
          :required="required"
          :error="errorMessage"
          :searchable="displayTypes.length > 10"
          full-width
          @update:model-value="(val) => { selectedValue = val as string; handleChange({ target: { value: val } } as any); }"
        />
      </div>
    </div>

    <!-- 快捷选择按钮 -->
    <div
      v-if="showQuickSelect && quickSelectTypes.length > 0"
      class="mb-2"
      role="group"
      :aria-label="quickSelectLabel"
    >
      <div class="text-xs text-[light-dark(#6b7280,#9ca3af)] mb-1">
        {{ quickSelectLabel }}：
      </div>
      <div class="flex flex-wrap gap-1">
        <button
          v-for="type in quickSelectTypes"
          :key="type.code"
          type="button"
          class="text-xs py-1 px-2 rounded-md border cursor-pointer transition-all duration-200 ease-in-out max-sm:py-0.5 max-sm:px-1.5 max-sm:text-[0.6875rem]" :class="[
            selectedValue === type.code
              ? 'bg-[light-dark(#dbeafe,rgba(59,130,246,0.1))] border-[var(--color-primary)] text-[var(--color-primary)]'
              : 'bg-[light-dark(white,#1f2937)] border-[light-dark(#d1d5db,#4b5563)] text-[light-dark(#111827,#f9fafb)] hover:bg-[light-dark(#f3f4f6,#374151)]',
            disabled && 'opacity-50 cursor-not-allowed',
          ]"
          :disabled="disabled"
          @click="selectQuickType(type)"
        >
          {{ getQuickSelectDisplayName(type) }}
        </button>
      </div>
    </div>

    <!-- 错误提示 -->
    <div
      v-if="errorMessage"
      class="mt-1 text-sm text-[var(--color-error)]"
      role="alert"
      aria-live="polite"
    >
      {{ errorMessage }}
    </div>

    <!-- 帮助文本 -->
    <div
      v-if="helpText"
      class="mt-2 text-xs text-[light-dark(#6b7280,#9ca3af)] text-right"
    >
      {{ helpText }}
    </div>
  </div>
</template>
