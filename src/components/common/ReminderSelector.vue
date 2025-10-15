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
  selectedType,
  isValid,
});
</script>

<template>
  <div class="reminder-selector">
    <div class="reminder-selector-row">
      <label :for="inputId" class="label-text">
        {{ label }}
        <span v-if="required" class="required-asterisk" aria-label="必填">*</span>
      </label>

      <!-- 基础选择器 -->
      <select
        v-if="!showGrouped"
        :id="inputId"
        v-model="selectedValue"
        :required="required"
        :disabled="disabled"
        class="modal-input-select"
        :data-size="size"
        :data-width="width"
        :data-error="!!errorMessage"
        :data-disabled="disabled"
        :data-loading="loading"
        @change="handleChange"
        @blur="handleBlur"
        @focus="handleFocus"
      >
        <option value="" disabled>
          {{ placeholder }}
        </option>
        <option v-for="type in displayTypes" :key="type.code" :value="type.code">
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
        class="modal-input-select"
        :data-size="size"
        :data-width="width"
        :data-error="!!errorMessage"
        :data-disabled="disabled"
        :data-loading="loading"
        @change="handleChange"
        @blur="handleBlur"
        @focus="handleFocus"
      >
        <option value="" disabled>
          {{ placeholder }}
        </option>
        <optgroup v-for="(types, category) in groupedTypes" :key="category" :label="getCategoryName(category)">
          <option v-for="type in types" :key="type.code" :value="type.code">
            {{ getCurrentDisplayName(type) }}
          </option>
        </optgroup>
      </select>
    </div>

    <!-- 快捷选择按钮 -->
    <div v-if="showQuickSelect && quickSelectTypes.length > 0" class="quick-select-group" role="group" :aria-label="quickSelectLabel">
      <div class="quick-select-label">
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
    <div v-if="errorMessage" :id="`${inputId}-error`" class="error-text" role="alert" aria-live="polite">
      {{ errorMessage }}
    </div>

    <!-- 帮助文本 -->
    <div v-if="helpText" class="help-text">
      {{ helpText }}
    </div>
  </div>
</template>

<style scoped lang="postcss">
/* 基础选择器 */
.modal-input-select {
  border: 1px solid #ccc;
  border-radius: 0.375rem;
  background-color: #fff;
  color: #111;
  transition: all 0.2s ease-in-out;
  font-family: inherit;
}

/* 尺寸 */
.modal-input-select[data-size="sm"] { padding: 0.25rem 0.5rem; font-size: 0.875rem; }
.modal-input-select[data-size="base"] { padding: 0.5rem 0.75rem; font-size: 1rem; }
.modal-input-select[data-size="lg"] { padding: 0.75rem 1rem; font-size: 1.125rem; }

/* 宽度 */
.modal-input-select[data-width="full"] { width: 100%; }
.modal-input-select[data-width="auto"] { width: auto; }
.modal-input-select[data-width="2/3"] { width: 66.666%; }
.modal-input-select[data-width="1/2"] { width: 50%; }
.modal-input-select[data-width="1/3"] { width: 33.333%; }

/* 错误状态 */
.modal-input-select[data-error="true"] { border-color: #f56565; }
.modal-input-select[data-error="true"]:focus { outline: 2px solid #f56565; outline-offset: 2px; }

/* 禁用状态 */
.modal-input-select[data-disabled="true"] {
  opacity: 0.5;
  cursor: not-allowed;
  background-color: #f5f5f5;
}

/* 加载状态 */
.modal-input-select[data-loading="true"] { opacity: 0.75; cursor: wait; }

/* focus 样式 */
.modal-input-select:focus { outline: 2px solid #3b82f6; outline-offset: 2px; }

/* optgroup 样式 */
.modal-input-select optgroup { font-weight: 600; color: #4b5563; }
.modal-input-select optgroup option { font-weight: 400; padding-left: 1rem; }

/* 禁用 option */
.modal-input-select option:disabled { color: #9ca3af; }

/* 快捷选择按钮 */
.quick-select-btn {
  font-size: 0.75rem;
  padding: 0.25rem 0.5rem;
  border-radius: 0.375rem;
  border: 1px solid #e5e7eb;
  background-color: #fff;
  color: #374151;
  cursor: pointer;
  transition: all 0.2s ease-in-out;
}
.quick-select-btn:hover { background-color: #f9fafb; border-color: #d1d5db; }
.quick-select-btn:disabled { opacity: 0.5; cursor: not-allowed; }

/* 激活状态 */
.quick-select-btn-active {
  background-color: #eff6ff;
  border-color: #bfdbfe;
  color: #1d4ed8;
}

/* label */
.label-text { font-size: 0.875rem; color: #374151; font-weight: 500; }
.required-asterisk { color: #f56565; margin-left: 0.25rem; }

/* 错误文本 */
.error-text { font-size: 0.875rem; color: #f56565; margin-top: 0.25rem; }

/* 帮助文本 */
.help-text { font-size: 0.75rem; color: #6b7280; margin-top: 0.5rem; text-align: right; }

/* 快捷选择组 */
.quick-select-group { margin-bottom: 0.5rem; }
.quick-select-label { font-size: 0.75rem; color: #6b7280; margin-bottom: 0.25rem; }

/* 容器基础布局 */
.reminder-selector-row {
  display: flex;
  align-items: center;        /* items-center */
  justify-content: space-between; /* justify-between */
  margin-bottom: 0.5rem;      /* mb-2 -> 0.5rem = 8px */
}

/* 响应式：小屏幕竖直排列 */
@media (max-width: 640px) {
  .reminder-selector-row {
    flex-direction: column;
    align-items: flex-start;  /* 左对齐 */
    margin-bottom: 0.5rem;
  }
}

/* 响应式 */
@media (max-width: 640px) {
  .reminder-selector .flex { flex-direction: column; align-items: flex-start; }
  .modal-input-select { width: 100% !important; margin-top: 0.5rem; }
  .quick-select-btn { padding: 0.125rem 0.375rem; font-size: 0.6875rem; }
}
</style>
