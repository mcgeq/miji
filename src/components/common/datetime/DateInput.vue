<script setup lang="ts">
/**
 * DateInput - 日期时间输入框
 *
 * 功能：
 * - 显示选中的日期时间
 * - 清除按钮
 * - 点击打开选择面板
 */

import { X } from 'lucide-vue-next';

interface Props {
  /** 显示的值 */
  modelValue?: Date | string | null;
  /** 占位符 */
  placeholder?: string;
  /** 日期格式 */
  format?: string;
  /** 是否禁用 */
  disabled?: boolean;
  /** 是否聚焦 */
  isFocused?: boolean;
}

const props = withDefaults(defineProps<Props>(), {
  placeholder: '选择日期时间',
  format: 'yyyy-MM-dd HH:mm:ss',
  disabled: false,
  isFocused: false,
});

const emit = defineEmits<{
  click: [];
  clear: [];
}>();

function handleClick() {
  if (!props.disabled) {
    emit('click');
  }
}

// 格式化日期
function formatDate(date: Date, format: string): string {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  const hour = String(date.getHours()).padStart(2, '0');
  const minute = String(date.getMinutes()).padStart(2, '0');
  const second = String(date.getSeconds()).padStart(2, '0');

  return format
    .replace('yyyy', String(year))
    .replace('MM', month)
    .replace('dd', day)
    .replace('HH', hour)
    .replace('mm', minute)
    .replace('ss', second);
}

// 显示值
const displayValue = computed(() => {
  if (!props.modelValue) return props.placeholder;

  const date = typeof props.modelValue === 'string'
    ? new Date(props.modelValue)
    : props.modelValue;

  if (Number.isNaN(date.getTime())) return props.placeholder;

  return formatDate(date, props.format);
});

function handleClear(event: Event) {
  event.stopPropagation();
  emit('clear');
}
</script>

<template>
  <div
    class="datetime-input bg-gray-50 dark:bg-gray-800 border rounded-lg px-3 py-2.5 cursor-pointer transition-all min-h-[42px] flex items-center"
    :class="{
      'border-gray-300 dark:border-gray-600 hover:border-gray-400 dark:hover:border-gray-500': !isFocused && !disabled,
      'border-blue-500 ring-2 ring-blue-500/20': isFocused && !disabled,
      'border-gray-200 dark:border-gray-700 bg-gray-100 dark:bg-gray-900 cursor-not-allowed opacity-60': disabled,
    }"
    @click="handleClick"
  >
    <div class="flex items-center justify-between w-full">
      <span
        class="text-sm flex-1"
        :class="{
          'text-gray-500 dark:text-gray-400': !modelValue,
          'text-gray-900 dark:text-white': modelValue,
        }"
      >
        {{ displayValue }}
      </span>

      <div class="flex items-center gap-2 ml-2">
        <!-- 清除按钮 -->
        <button
          v-if="modelValue && !disabled"
          type="button"
          class="w-5 h-5 flex items-center justify-center rounded-full hover:bg-gray-200 dark:hover:bg-gray-700 text-gray-400 hover:text-gray-600 dark:hover:text-gray-300 transition-colors"
          @click="handleClear"
        >
          <X :size="14" />
        </button>

        <!-- 日历图标 -->
        <span class="text-base text-gray-400">📅</span>
      </div>
    </div>
  </div>
</template>
