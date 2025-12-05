<script setup lang="ts">
/**
 * Checkbox - 复选框组件
 *
 * 支持单个和组模式
 * 完整的无障碍支持：ARIA 属性、键盘导航
 * 100% Tailwind CSS 4
 */

interface Props {
  /** 选中状态 */
  modelValue?: boolean | (string | number)[];
  /** 复选框值（用于数组模式） */
  value?: string | number;
  /** 标签 */
  label?: string;
  /** 描述 */
  description?: string;
  /** 错误信息 */
  error?: string;
  /** 尺寸 */
  size?: 'sm' | 'md' | 'lg';
  /** 是否禁用 */
  disabled?: boolean;
  /** 是否为不确定状态 */
  indeterminate?: boolean;
  /** 是否必填 */
  required?: boolean;
  /** 复选框 ID（用于无障碍关联） */
  id?: string;
}

const props = withDefaults(defineProps<Props>(), {
  size: 'md',
  disabled: false,
  indeterminate: false,
  required: false,
});

const emit = defineEmits<{
  'update:modelValue': [value: boolean | (string | number)[]];
}>();

// 生成唯一 ID
const checkboxId = computed(() => props.id || `checkbox-${Math.random().toString(36).slice(2, 9)}`);
const descriptionId = computed(() => `${checkboxId.value}-description`);
const errorId = computed(() => `${checkboxId.value}-error`);

// 计算 aria-describedby
const ariaDescribedBy = computed(() => {
  const ids: string[] = [];
  if (props.error) ids.push(errorId.value);
  else if (props.description) ids.push(descriptionId.value);
  return ids.length > 0 ? ids.join(' ') : undefined;
});

// 判断是否选中
const isChecked = computed((): boolean => {
  if (Array.isArray(props.modelValue)) {
    return props.value !== undefined && props.modelValue.includes(props.value);
  }
  return Boolean(props.modelValue);
});

// 处理变化
function handleChange(event: Event) {
  const checked = (event.target as HTMLInputElement).checked;

  if (Array.isArray(props.modelValue) && props.value !== undefined) {
    const newValue = checked
      ? [...props.modelValue, props.value]
      : props.modelValue.filter(v => v !== props.value);
    emit('update:modelValue', newValue);
  } else {
    emit('update:modelValue', checked);
  }
}

// 计算 aria-checked 值
const ariaCheckedValue = computed(() => {
  if (props.indeterminate) return 'mixed';
  return isChecked.value;
});

// 尺寸配置
const sizeConfig = {
  sm: {
    box: 'w-4 h-4',
    icon: 'w-3 h-3',
    text: 'text-sm',
  },
  md: {
    box: 'w-5 h-5',
    icon: 'w-4 h-4',
    text: 'text-base',
  },
  lg: {
    box: 'w-6 h-6',
    icon: 'w-5 h-5',
    text: 'text-lg',
  },
};
</script>

<template>
  <div>
    <label
      :for="checkboxId"
      class="inline-flex items-start gap-2 cursor-pointer" :class="[
        disabled && 'opacity-50 cursor-not-allowed',
      ]"
    >
      <!-- 复选框 -->
      <div class="relative shrink-0">
        <input
          :id="checkboxId"
          type="checkbox"
          :checked="isChecked"
          :value="value"
          :disabled="disabled"
          :required="required"
          :aria-checked="ariaCheckedValue"
          :aria-invalid="!!error"
          :aria-describedby="ariaDescribedBy"
          :aria-required="required"
          class="sr-only peer"
          @change="handleChange"
        >

        <!-- 自定义复选框 -->
        <div
          class="rounded border-2 transition-all flex items-center justify-center peer-focus:ring-2 peer-focus:ring-blue-500 peer-focus:ring-offset-2" :class="[
            sizeConfig[size].box,
            isChecked || indeterminate
              ? 'bg-blue-600 border-blue-600'
              : 'bg-white dark:bg-gray-800 border-gray-300 dark:border-gray-600',
            error && !isChecked && !indeterminate && 'border-red-500',
            disabled && 'cursor-not-allowed',
          ]"
          aria-hidden="true"
        >
          <!-- 选中图标 -->
          <LucideCheck
            v-if="isChecked && !indeterminate"
            class="text-white" :class="[sizeConfig[size].icon]"
          />
          <!-- 不确定状态图标 -->
          <LucideMinus
            v-else-if="indeterminate"
            class="text-white" :class="[sizeConfig[size].icon]"
          />
        </div>
      </div>

      <!-- 标签和描述 -->
      <div v-if="label || description || $slots.default" class="flex-1">
        <div class="font-medium text-gray-900 dark:text-white" :class="[sizeConfig[size].text]">
          <slot>{{ label }}</slot>
          <span v-if="required" class="text-red-500 ml-0.5" aria-hidden="true">*</span>
        </div>
        <p
          v-if="description && !error"
          :id="descriptionId"
          class="text-sm text-gray-500 dark:text-gray-400 mt-0.5"
        >
          {{ description }}
        </p>
      </div>
    </label>

    <!-- 错误信息 -->
    <p
      v-if="error"
      :id="errorId"
      role="alert"
      aria-live="polite"
      class="mt-1 text-sm text-red-600 dark:text-red-400"
    >
      {{ error }}
    </p>
  </div>
</template>
