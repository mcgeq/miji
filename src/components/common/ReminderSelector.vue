<script setup lang="ts">
import {
  CATEGORY_NAMES,
  DEFAULT_REMINDER_TYPES,
  POPULAR_REMINDER_TYPES,

} from '@/constants/commonConstant';
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
const inputId = useId();
const isFirstFocus = ref(true);

// 计算属性
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

  const classes = [
    ...baseClasses,
    sizeClasses[props.size],
    widthClasses[props.width],
  ];

  // 错误状态
  if (props.errorMessage) {
    classes.push('border-red-500', 'focus:ring-red-500');
  }

  // 禁用状态
  if (props.disabled) {
    classes.push('opacity-50', 'cursor-not-allowed');
  }

  // 加载状态
  if (props.loading) {
    classes.push('opacity-75', 'cursor-wait');
  }

  return classes.filter(Boolean).join(' ');
});

// 显示的提醒类型列表
const displayTypes = computed(() => {
  if (props.popularOnly) {
    return POPULAR_REMINDER_TYPES.filter(type =>
      props.reminderTypes.some(rt => rt.code === type.code),
    );
  }
  return props.reminderTypes;
});

// 分组的提醒类型
const groupedTypes = computed(() => {
  if (!props.showGrouped)
    return {};

  const grouped: Record<string, ReminderTypeI18[]> = {};

  displayTypes.value.forEach(type => {
    const category = type.category || 'general';
    if (!grouped[category]) {
      grouped[category] = [];
    }
    grouped[category].push(type);
  });

  // 按分类排序
  const sortedGrouped: Record<string, ReminderTypeI18[]> = {};
  const categoryOrder = [
    'finance',
    'work',
    'health',
    'lifestyle',
    'social',
    'general',
  ];

  categoryOrder.forEach(category => {
    if (grouped[category]) {
      sortedGrouped[category] = grouped[category];
    }
  });

  // 添加其他未排序的分类
  Object.keys(grouped).forEach(category => {
    if (!categoryOrder.includes(category)) {
      sortedGrouped[category] = grouped[category];
    }
  });

  return sortedGrouped;
});

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

function getCategoryName(category: string): string {
  const categoryInfo = CATEGORY_NAMES[category as keyof typeof CATEGORY_NAMES];
  if (!categoryInfo)
    return category;
  return props.locale === 'zh-CN' ? categoryInfo.zh : categoryInfo.en;
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

function handleBlur(event: FocusEvent) {
  emit('blur', event);

  // 失焦时触发验证
  nextTick(() => {
    emit('validate', isValid.value);
  });
}

function handleFocus(event: FocusEvent) {
  emit('focus', event);

  // 首次聚焦时的特殊处理
  if (isFirstFocus.value) {
    isFirstFocus.value = false;
    // 可以在这里添加首次聚焦的逻辑
  }
}

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

// 公共方法
function focus() {
  const selectElement = document.getElementById(inputId);
  if (selectElement) {
    selectElement.focus();
  }
}

function blur() {
  const selectElement = document.getElementById(inputId);
  if (selectElement) {
    selectElement.blur();
  }
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

// 暴露组件方法
defineExpose({
  focus,
  blur,
  validate,
  reset,
  selectedType: readonly(selectedType),
  isValid: readonly(isValid),
});
</script>

<template>
  <div class="reminder-selector">
    <div class="mb-2 flex items-center justify-between">
      <label
        :for="inputId"
        class="text-sm text-gray-700 font-medium mb-2 dark:text-gray-300"
      >
        {{ label }}
        <span v-if="required" class="text-red-500 ml-1" aria-label="必填">*</span>
      </label>
      <!-- 基础选择器 -->
      <select
        v-if="!showGrouped"
        :id="inputId"
        v-model="selectedValue"
        :required="required"
        :disabled="disabled"
        :class="selectClasses"
        :aria-invalid="!!errorMessage"
        :aria-describedby="errorMessage ? `${inputId}-error` : undefined"
        @change="handleChange"
        @blur="handleBlur"
        @focus="handleFocus"
      >
        <option value="" disabled>
          {{ placeholder }}
        </option>
        <option
          v-for="type in displayTypes"
          :key="type.code"
          :value="type.code"
        >
          {{ getCurrentDisplayName(type) }}
        </option>
      </select>

      <!-- 分组选择器 -->
      <select
        v-else
        :id="inputId"
        v-model="selectedValue"
        :required="required"
        :disabled="disabled"
        :class="selectClasses"
        :aria-invalid="!!errorMessage"
        :aria-describedby="errorMessage ? `${inputId}-error` : undefined"
        @change="handleChange"
        @blur="handleBlur"
        @focus="handleFocus"
      >
        <option value="" disabled>
          {{ placeholder }}
        </option>
        <optgroup
          v-for="(types, category) in groupedTypes"
          :key="category"
          :label="getCategoryName(category)"
        >
          <option
            v-for="type in types"
            :key="type.code"
            :value="type.code"
          >
            {{ getCurrentDisplayName(type) }}
          </option>
        </optgroup>
      </select>
    </div>
    <!-- 快捷选择按钮 -->
    <div
      v-if="showQuickSelect && quickSelectTypes.length > 0"
      class="mb-2"
      role="group"
      :aria-label="quickSelectLabel"
    >
      <div class="text-xs text-gray-500 mb-1 dark:text-gray-400">
        {{ quickSelectLabel }}：
      </div>
      <div class="flex flex-wrap gap-1">
        <button
          v-for="type in quickSelectTypes"
          :key="type.code"
          type="button"
          class="quick-select-btn"
          :class="{ 'quick-select-btn-active': selectedValue === type.code }"
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
      :id="`${inputId}-error`"
      class="text-sm text-red-600 mt-1 dark:text-red-400"
      role="alert"
      aria-live="polite"
    >
      {{ errorMessage }}
    </div>
    <!-- 帮助文本 -->
    <div
      v-if="helpText"
      class="text-xs text-gray-500 mt-2 flex justify-end dark:text-gray-400"
    >
      {{ helpText }}
    </div>
  </div>
</template>

<style scoped lang="postcss">
/* 快捷选择按钮样式 */
.quick-select-btn {
  @apply text-xs px-2 py-1 rounded-md border border-gray-200 dark:border-gray-600
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

/* 选择框样式优化 */
select:focus {
  outline: none;
}

/* 深色主题适配 */
.dark select option {
  background-color: theme('colors.gray.800');
  color: theme('colors.white');
}

/* 可访问性增强 */
select:focus-visible {
  outline: 2px solid theme('colors.blue.500');
  outline-offset: 2px;
}

/* 响应式设计 */
@media (max-width: 640px) {
  .reminder-selector .flex {
    flex-direction: column;
    align-items: flex-start;
  }

  .reminder-selector select {
    width: 100% !important;
    margin-top: 0.5rem;
  }

  .quick-select-btn {
    @apply text-xs px-1.5 py-0.5;
  }
}

/* 加载状态动画 */
@keyframes pulse {
  0%, 100% { opacity: 1; }
  50% { opacity: 0.5; }
}

.reminder-selector select:disabled {
  animation: pulse 2s infinite;
}

/* 优化选项组样式 */
optgroup {
  @apply font-semibold text-gray-600 dark:text-gray-400;
}

optgroup option {
  @apply font-normal pl-4;
}

/* 错误状态动画 */
@keyframes shake {
  0%, 100% { transform: translateX(0); }
  25% { transform: translateX(-4px); }
  75% { transform: translateX(4px); }
}

.reminder-selector select.border-red-500 {
  animation: shake 0.3s ease-in-out;
}

/* 优化滚动条样式 */
select::-webkit-scrollbar {
  width: 8px;
}

select::-webkit-scrollbar-track {
  @apply bg-gray-100 dark:bg-gray-700;
}

select::-webkit-scrollbar-thumb {
  @apply bg-gray-300 dark:bg-gray-500 rounded-md;
}

select::-webkit-scrollbar-thumb:hover {
  @apply bg-gray-400 dark:bg-gray-400;
}
</style>
