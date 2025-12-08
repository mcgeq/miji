<script setup lang="ts">
  import { Listbox, ListboxButton, ListboxOption, ListboxOptions } from '@headlessui/vue';
  import type { SelectOption } from './types';

  /**
   * Select - 选择器组件
   *
   * 基于 Headless UI Listbox
   * 支持搜索、多选、分组等功能
   * 完整的无障碍支持：键盘导航、ARIA 属性
   * 100% Tailwind CSS 4 设计令牌
   */

  /** 选择器尺寸 */
  type SelectSize = 'sm' | 'md' | 'lg';

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
    /** 帮助文本 */
    hint?: string;
    /** 尺寸 */
    size?: SelectSize;
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
    /** 选择器 ID（用于无障碍关联） */
    id?: string;
    /** 选择器名称 */
    name?: string;
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
    change: [value: string | number | (string | number)[]];
  }>();

  // 生成唯一 ID
  const selectId = computed(() => props.id || `select-${Math.random().toString(36).slice(2, 9)}`);
  const hintId = computed(() => `${selectId.value}-hint`);
  const errorId = computed(() => `${selectId.value}-error`);

  const searchQuery = ref('');
  const searchInputRef = ref<HTMLInputElement | null>(null);

  // 过滤选项
  const filteredOptions = computed(() => {
    if (!(props.searchable && searchQuery.value)) {
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

  // 是否显示占位符
  const isPlaceholder = computed(() => {
    if (Array.isArray(props.modelValue)) {
      return props.modelValue.length === 0;
    }
    return !props.options.find(opt => opt.value === props.modelValue);
  });

  // 尺寸样式
  const sizeClasses: Record<SelectSize, string> = {
    sm: 'px-3 py-1.5 text-sm',
    md: 'px-4 py-2 text-base',
    lg: 'px-5 py-3 text-lg',
  };

  // 计算 aria-describedby
  const ariaDescribedBy = computed(() => {
    const ids: string[] = [];
    if (props.error) ids.push(errorId.value);
    else if (props.hint) ids.push(hintId.value);
    return ids.length > 0 ? ids.join(' ') : undefined;
  });

  // 处理值变化
  function handleChange(value: string | number | (string | number)[]) {
    emit('update:modelValue', value);
    emit('change', value);
  }

  // 清除搜索
  function clearSearch() {
    searchQuery.value = '';
    searchInputRef.value?.focus();
  }
</script>

<template>
  <div class="relative" :class="[fullWidth && 'w-full']">
    <!-- 标签 -->
    <label
      v-if="label"
      :for="selectId"
      class="block text-sm font-medium text-gray-900 dark:text-white mb-1.5"
    >
      {{ label }}
      <span v-if="required" class="text-red-600 dark:text-red-400 ml-0.5" aria-hidden="true"
        >*</span
      >
    </label>

    <Listbox
      :model-value="modelValue"
      :multiple="multiple"
      :disabled="disabled"
      :name="name"
      @update:model-value="handleChange"
    >
      <div class="relative">
        <!-- 按钮 -->
        <ListboxButton
          :id="selectId"
          :aria-invalid="!!error"
          :aria-describedby="ariaDescribedBy"
          :aria-required="required"
          class="relative w-full text-left rounded-lg border transition-colors duration-200 focus:outline-none focus:ring-2 bg-white dark:bg-gray-800"
          :class="[
            sizeClasses[size],
            error
              ? 'border-red-300 dark:border-red-700 focus:ring-red-500'
              : 'border-gray-300 dark:border-gray-600 focus:ring-blue-500',
            disabled && 'opacity-50 cursor-not-allowed bg-gray-50 dark:bg-gray-900',
            isPlaceholder ? 'text-gray-400 dark:text-gray-500' : 'text-gray-900 dark:text-white',
          ]"
        >
          <span class="block truncate pr-8">{{ displayValue }}</span>
          <span class="absolute inset-y-0 right-0 flex items-center pr-3 pointer-events-none">
            <LucideChevronDown
              class="w-5 h-5 text-gray-600 dark:text-gray-400"
              aria-hidden="true"
            />
          </span>
        </ListboxButton>

        <!-- 下拉选项 -->
        <transition
          leave-active-class="transition duration-100 ease-in"
          leave-from-class="opacity-100"
          leave-to-class="opacity-0"
        >
          <ListboxOptions
            class="absolute z-50 mt-1 w-full max-h-60 overflow-auto rounded-xl bg-white dark:bg-gray-800 py-2 shadow-lg border border-gray-200 dark:border-gray-700 focus:outline-none [scrollbar-width:none] [-ms-overflow-style:none] [&::-webkit-scrollbar]:hidden"
          >
            <!-- 搜索框 -->
            <div v-if="searchable" class="px-3 py-2 mb-1">
              <div class="relative">
                <LucideSearch
                  class="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-gray-600 dark:text-gray-400"
                  aria-hidden="true"
                />
                <input
                  ref="searchInputRef"
                  v-model="searchQuery"
                  type="text"
                  placeholder="搜索..."
                  aria-label="搜索选项"
                  class="w-full pl-10 pr-8 py-2 text-sm border border-gray-200 dark:border-gray-700 rounded-lg bg-gray-100 dark:bg-gray-700 text-gray-900 dark:text-white placeholder:text-gray-400 dark:placeholder:text-gray-500 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:border-blue-500 transition-all"
                  @click.stop
                  @keydown.stop
                />
                <button
                  v-if="searchQuery"
                  type="button"
                  class="absolute right-2 top-1/2 -translate-y-1/2 p-1 hover:bg-gray-200 dark:hover:bg-gray-600 rounded transition-colors"
                  aria-label="清除搜索"
                  @click.stop="clearSearch"
                >
                  <LucideX
                    class="w-3 h-3 text-gray-600 dark:text-gray-400 hover:text-gray-900 dark:hover:text-white"
                    aria-hidden="true"
                  />
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
                  <div class="w-[80%] h-px bg-gray-200 dark:bg-gray-700" />
                </div>

                <!-- 选项内容 -->
                <div
                  class="relative cursor-pointer select-none py-3 pl-10 pr-4 rounded-lg transition-all duration-150"
                  :class="[
                    active ? 'bg-blue-600 text-white shadow-sm' : 'text-gray-900 dark:text-white',
                    !active && selected ? 'bg-blue-50 dark:bg-blue-900/30 text-blue-600 dark:text-blue-400' : '',
                    !active && !selected ? 'hover:bg-gray-100 dark:hover:bg-gray-700' : '',
                    option.disabled && 'opacity-50 cursor-not-allowed',
                  ]"
                >
                  <!-- 图标 -->
                  <component
                    :is="option.icon"
                    v-if="option.icon"
                    class="inline-block w-4 h-4 mr-2"
                    aria-hidden="true"
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
                    <LucideCheck class="w-5 h-5" aria-hidden="true" />
                  </span>
                </div>
              </li>
            </ListboxOption>

            <!-- 空状态 -->
            <div
              v-if="filteredOptions.length === 0"
              class="px-4 py-8 text-center text-sm text-gray-600 dark:text-gray-400"
              role="status"
            >
              <div class="text-4xl mb-2 opacity-30" aria-hidden="true">🔍</div>
              <div>没有找到匹配的选项</div>
            </div>
          </ListboxOptions>
        </transition>
      </div>
    </Listbox>

    <!-- 帮助文本 -->
    <p v-if="hint && !error" :id="hintId" class="mt-1.5 text-sm text-gray-600 dark:text-gray-400">
      {{ hint }}
    </p>

    <!-- 错误信息 -->
    <p
      v-if="error"
      :id="errorId"
      role="alert"
      aria-live="polite"
      class="mt-1.5 text-sm text-red-600 dark:text-red-400"
    >
      {{ error }}
    </p>
  </div>
</template>
