<script setup lang="ts">
/**
 * Dropdown - 下拉菜单组件
 *
 * 基于 Headless UI Menu 组件
 * 支持键盘导航和完整的可访问性
 */

import { Menu, MenuButton, MenuItem, MenuItems } from '@headlessui/vue';

export interface DropdownOption {
  /** 选项值 */
  value: string;
  /** 显示文本 */
  label: string;
  /** 是否禁用 */
  disabled?: boolean;
  /** 图标组件 */
  icon?: any;
  /** 分隔线（在此选项后显示） */
  divider?: boolean;
}

interface Props {
  /** 选项列表 */
  options: DropdownOption[];
  /** 按钮文本 */
  label?: string;
  /** 当前选中值 */
  modelValue?: string;
  /** 是否显示选中状态 */
  showCheck?: boolean;
  /** 按钮变体 */
  variant?: 'default' | 'outline' | 'ghost';
  /** 尺寸 */
  size?: 'sm' | 'md' | 'lg';
}

withDefaults(defineProps<Props>(), {
  label: '选择选项',
  showCheck: false,
  variant: 'default',
  size: 'md',
});

const emit = defineEmits<{
  'update:modelValue': [value: string];
  'select': [value: string];
}>();

// 按钮样式
const buttonVariants = {
  default: 'bg-white dark:bg-gray-800 border border-gray-300 dark:border-gray-600 hover:bg-gray-50 dark:hover:bg-gray-700 text-gray-900 dark:text-white',
  outline: 'border border-gray-300 dark:border-gray-600 hover:bg-gray-50 dark:hover:bg-gray-700 text-gray-900 dark:text-white',
  ghost: 'hover:bg-gray-100 dark:hover:bg-gray-700 text-gray-900 dark:text-white',
};

const buttonSizes = {
  sm: 'px-3 py-1.5 text-sm',
  md: 'px-4 py-2 text-base',
  lg: 'px-5 py-2.5 text-lg',
};

function handleSelect(value: string) {
  emit('update:modelValue', value);
  emit('select', value);
}
</script>

<template>
  <Menu as="div" class="relative inline-block text-left">
    <MenuButton
      class="inline-flex items-center justify-center gap-2 rounded-lg font-medium transition-colors focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2" :class="[
        buttonVariants[variant],
        buttonSizes[size],
      ]"
    >
      <slot name="button">
        <span>{{ label }}</span>
        <LucideChevronDown class="w-4 h-4" />
      </slot>
    </MenuButton>

    <transition
      enter-active-class="transition duration-100 ease-out"
      enter-from-class="transform scale-95 opacity-0"
      leave-active-class="transition duration-75 ease-in"
      leave-to-class="transform scale-95 opacity-0"
    >
      <MenuItems
        class="absolute right-0 mt-2 w-56 origin-top-right rounded-lg bg-white dark:bg-gray-800 shadow-lg ring-1 ring-black/5 dark:ring-white/10 focus:outline-none z-50"
      >
        <div class="p-1">
          <template v-for="(option, index) in options" :key="option.value">
            <MenuItem
              v-slot="{ active }"
              :disabled="option.disabled"
            >
              <button
                class="group flex w-full items-center gap-2 rounded-md px-3 py-2 text-sm transition-colors" :class="[
                  active ? 'bg-blue-600 text-white' : 'text-gray-900 dark:text-gray-100',
                  option.disabled && 'opacity-50 cursor-not-allowed',
                ]"
                @click="handleSelect(option.value)"
              >
                <!-- 选中标记 -->
                <LucideCheck
                  v-if="showCheck && modelValue === option.value"
                  class="w-4 h-4"
                />
                <span v-else-if="showCheck" class="w-4" />

                <!-- 图标 -->
                <component
                  :is="option.icon"
                  v-if="option.icon"
                  class="w-4 h-4"
                />

                <!-- 文本 -->
                <span class="flex-1 text-left">{{ option.label }}</span>
              </button>
            </MenuItem>

            <!-- 分隔线 -->
            <div
              v-if="option.divider && index < options.length - 1"
              class="my-1 h-px bg-gray-200 dark:bg-gray-700"
            />
          </template>
        </div>
      </MenuItems>
    </transition>
  </Menu>
</template>
