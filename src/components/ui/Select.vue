<script setup lang="ts">
/**
 * Select - 选择器组件
 *
 * 基于 Headless UI Listbox
 * 支持搜索、多选、分组等功能
 */

import { Listbox, ListboxButton, ListboxOption, ListboxOptions } from '@headlessui/vue';
import { Check, ChevronDown, Search, X } from 'lucide-vue-next';
import { computed, ref } from 'vue';

export interface SelectOption {
  /** 选项值 */
  value: string | number;
  /** 显示文本 */
  label: string;
  /** 是否禁用 */
  disabled?: boolean;
  /** 图标 */
  icon?: any;
}

interface Props {
  /** 当前值 */
  modelValue: string | number | (string | number)[];
  /** 选项列表 */
  options: SelectOption[];
  /** 占位符 */
  placeholder?: string;
  /** 标签 */
  label?: string;
  /** 错误信息 */
  error?: string;
  /** 尺寸 */
  size?: 'sm' | 'md' | 'lg';
  /** 是否多选 */
  multiple?: boolean;
  /** 是否可搜索 */
  searchable?: boolean;
  /** 是否禁用 */
  disabled?: boolean;
  /** 是否必填 */
  required?: boolean;
  /** 是否全宽 */
  fullWidth?: boolean;
}

const props = withDefaults(defineProps<Props>(), {
  placeholder: '请选择',
  size: 'md',
  multiple: false,
  searchable: false,
  disabled: false,
  required: false,
  fullWidth: false,
});

const emit = defineEmits<{
  'update:modelValue': [value: string | number | (string | number)[]];
}>();

const searchQuery = ref('');

// 过滤选项
const filteredOptions = computed(() => {
  if (!props.searchable || !searchQuery.value) {
    return props.options;
  }
  return props.options.filter(option =>
    option.label.toLowerCase().includes(searchQuery.value.toLowerCase()),
  );
});

// 显示文本
const displayValue = computed(() => {
  if (Array.isArray(props.modelValue)) {
    if (props.modelValue.length === 0) return props.placeholder;
    const selected = props.options.filter(opt =>
      (props.modelValue as (string | number)[]).includes(opt.value),
    );
    return selected.map(opt => opt.label).join(', ');
  }
  const selected = props.options.find(opt => opt.value === props.modelValue);
  return selected?.label || props.placeholder;
});

// 尺寸样式
const sizeClasses = {
  sm: 'px-3 py-1.5 text-sm',
  md: 'px-4 py-2 text-base',
  lg: 'px-5 py-3 text-lg',
};
</script>

<template>
  <div class="relative" :class="[fullWidth && 'w-full']">
    <!-- 标签 -->
    <label
      v-if="label"
      class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-1.5"
    >
      {{ label }}
      <span v-if="required" class="text-red-500 ml-0.5">*</span>
    </label>

    <Listbox
      :model-value="modelValue"
      :multiple="multiple"
      :disabled="disabled"
      @update:model-value="emit('update:modelValue', $event)"
    >
      <div class="relative">
        <!-- 按钮 -->
        <ListboxButton
          class="relative w-full text-left rounded-lg border transition-colors focus:outline-none focus:ring-2 bg-white dark:bg-gray-800 text-gray-900 dark:text-white" :class="[
            sizeClasses[size],
            error
              ? 'border-red-300 dark:border-red-700 focus:ring-red-500'
              : 'border-gray-300 dark:border-gray-600 focus:ring-blue-500',
            disabled && 'opacity-50 cursor-not-allowed bg-gray-50 dark:bg-gray-900',
          ]"
        >
          <span class="block truncate">{{ displayValue }}</span>
          <span class="absolute inset-y-0 right-0 flex items-center pr-3 pointer-events-none">
            <ChevronDown class="w-5 h-5 text-gray-400" />
          </span>
        </ListboxButton>

        <!-- 下拉选项 -->
        <transition
          leave-active-class="transition duration-100 ease-in"
          leave-from-class="opacity-100"
          leave-to-class="opacity-0"
        >
          <ListboxOptions
            class="absolute z-50 mt-1 w-full max-h-60 overflow-auto rounded-xl bg-white dark:bg-gray-800 py-2 shadow-xl border border-gray-200 dark:border-gray-700 focus:outline-none [scrollbar-width:none] [-ms-overflow-style:none] [&::-webkit-scrollbar]:hidden"
          >
            <!-- 搜索框 -->
            <div v-if="searchable" class="px-3 py-2 mb-1">
              <div class="relative">
                <Search class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-400" />
                <input
                  v-model="searchQuery"
                  type="text"
                  placeholder="搜索..."
                  class="w-full pl-10 pr-8 py-2 text-sm border border-gray-200 dark:border-gray-700 rounded-lg bg-gray-50 dark:bg-gray-900/50 text-gray-900 dark:text-white placeholder:text-gray-400 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition-all"
                  @click.stop
                >
                <button
                  v-if="searchQuery"
                  class="absolute right-2 top-1/2 -translate-y-1/2 p-1 hover:bg-gray-200 dark:hover:bg-gray-700 rounded transition-colors"
                  @click="searchQuery = ''"
                >
                  <X class="w-3 h-3 text-gray-400 hover:text-gray-600 dark:hover:text-gray-300" />
                </button>
              </div>
            </div>

            <!-- 选项列表 -->
            <ListboxOption
              v-for="(option, index) in filteredOptions"
              :key="option.value"
              v-slot="{ active, selected }"
              :value="option.value"
              :disabled="option.disabled"
              as="template"
            >
              <li class="px-2">
                <!-- 分隔线 - 第一项除外 -->
                <div v-if="index > 0" class="flex items-center justify-center py-1">
                  <div class="w-[80%] h-px bg-gray-200 dark:bg-gray-700/50" />
                </div>

                <!-- 选项内容 -->
                <div
                  class="relative cursor-pointer select-none py-3 pl-10 pr-4 rounded-lg transition-all duration-150" :class="[
                    active ? 'bg-blue-500 text-white shadow-sm' : 'text-gray-700 dark:text-gray-200',
                    !active && selected ? 'bg-blue-50 dark:bg-blue-900/20 text-blue-700 dark:text-blue-300' : '',
                    !active && !selected ? 'hover:bg-gray-100 dark:hover:bg-gray-700/60' : '',
                    option.disabled && 'opacity-50 cursor-not-allowed',
                  ]"
                >
                  <!-- 图标 -->
                  <component
                    :is="option.icon"
                    v-if="option.icon"
                    class="inline-block w-4 h-4 mr-2"
                  />

                  <!-- 文本 -->
                  <span class="block truncate" :class="[selected ? 'font-medium' : 'font-normal']">
                    {{ option.label }}
                  </span>

                  <!-- 选中标记 -->
                  <span
                    v-if="selected"
                    class="absolute inset-y-0 left-0 flex items-center pl-3"
                    :class="active ? 'text-white' : 'text-blue-600 dark:text-blue-400'"
                  >
                    <Check class="w-5 h-5" />
                  </span>
                </div>
              </li>
            </ListboxOption>

            <!-- 空状态 -->
            <div
              v-if="filteredOptions.length === 0"
              class="px-4 py-8 text-center text-sm text-gray-400 dark:text-gray-500"
            >
              <div class="text-4xl mb-2 opacity-30">
                🔍
              </div>
              <div>没有找到匹配的选项</div>
            </div>
          </ListboxOptions>
        </transition>
      </div>
    </Listbox>

    <!-- 错误信息 -->
    <p
      v-if="error"
      class="mt-1.5 text-sm text-red-600 dark:text-red-400"
    >
      {{ error }}
    </p>
  </div>
</template>
