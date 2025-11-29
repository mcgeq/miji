<script setup lang="ts">
/**
 * Tooltip - 工具提示组件
 *
 * 基于 Headless UI Popover
 * 支持多个位置和自动定位
 */

import { Popover, PopoverButton, PopoverPanel } from '@headlessui/vue';

interface Props {
  /** 提示内容 */
  content?: string;
  /** 位置 */
  placement?: 'top' | 'bottom' | 'left' | 'right';
  /** 是否禁用 */
  disabled?: boolean;
}

withDefaults(defineProps<Props>(), {
  placement: 'top',
  disabled: false,
});
</script>

<template>
  <Popover v-if="!disabled" class="relative inline-block">
    <PopoverButton as="div" class="inline-block">
      <slot name="trigger">
        <slot />
      </slot>
    </PopoverButton>

    <transition
      enter-active-class="transition duration-100 ease-out"
      enter-from-class="opacity-0 scale-95"
      leave-active-class="transition duration-75 ease-in"
      leave-to-class="opacity-0 scale-95"
    >
      <PopoverPanel
        class="absolute z-50 px-3 py-2 text-sm text-white bg-gray-900 dark:bg-gray-700 rounded-lg shadow-lg whitespace-nowrap" :class="[
          placement === 'top' && 'bottom-full left-1/2 -translate-x-1/2 mb-2',
          placement === 'bottom' && 'top-full left-1/2 -translate-x-1/2 mt-2',
          placement === 'left' && 'right-full top-1/2 -translate-y-1/2 mr-2',
          placement === 'right' && 'left-full top-1/2 -translate-y-1/2 ml-2',
        ]"
      >
        <!-- 箭头 -->
        <div
          class="absolute w-2 h-2 bg-gray-900 dark:bg-gray-700 transform rotate-45" :class="[
            placement === 'top' && 'bottom-[-4px] left-1/2 -translate-x-1/2',
            placement === 'bottom' && 'top-[-4px] left-1/2 -translate-x-1/2',
            placement === 'left' && 'right-[-4px] top-1/2 -translate-y-1/2',
            placement === 'right' && 'left-[-4px] top-1/2 -translate-y-1/2',
          ]"
        />

        <!-- 内容 -->
        <div class="relative z-10">
          <slot name="content">
            {{ content }}
          </slot>
        </div>
      </PopoverPanel>
    </transition>
  </Popover>

  <!-- 禁用时只显示触发器 -->
  <div v-else class="inline-block">
    <slot />
  </div>
</template>
