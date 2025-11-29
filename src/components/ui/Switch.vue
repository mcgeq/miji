<script setup lang="ts">
/**
 * Switch - 开关组件
 *
 * 基于 Headless UI Switch
 * 支持键盘导航和完整的可访问性
 */

import { Switch as HSwitch } from '@headlessui/vue';

interface Props {
  /** 开关状态 */
  modelValue: boolean;
  /** 标签 */
  label?: string;
  /** 描述 */
  description?: string;
  /** 尺寸 */
  size?: 'sm' | 'md' | 'lg';
  /** 是否禁用 */
  disabled?: boolean;
}

withDefaults(defineProps<Props>(), {
  size: 'md',
  disabled: false,
});

const emit = defineEmits<{
  'update:modelValue': [value: boolean];
}>();

// 尺寸配置
const sizeConfig = {
  sm: {
    container: 'h-5 w-9',
    thumb: 'h-4 w-4',
    translate: 'translate-x-4',
  },
  md: {
    container: 'h-6 w-11',
    thumb: 'h-5 w-5',
    translate: 'translate-x-5',
  },
  lg: {
    container: 'h-7 w-14',
    thumb: 'h-6 w-6',
    translate: 'translate-x-7',
  },
};
</script>

<template>
  <HSwitch
    :model-value="modelValue"
    :disabled="disabled"
    class="relative inline-flex shrink-0 cursor-pointer rounded-full border-2 border-transparent transition-colors duration-200 ease-in-out focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2" :class="[
      modelValue ? 'bg-blue-600' : 'bg-gray-200 dark:bg-gray-700',
      disabled && 'opacity-50 cursor-not-allowed',
      sizeConfig[size].container,
    ]"
    @update:model-value="emit('update:modelValue', $event)"
  >
    <span class="sr-only">{{ label || 'Toggle' }}</span>
    <span
      class="pointer-events-none inline-block transform rounded-full bg-white shadow-lg ring-0 transition duration-200 ease-in-out" :class="[
        modelValue ? sizeConfig[size].translate : 'translate-x-0',
        sizeConfig[size].thumb,
      ]"
    />
  </HSwitch>

  <!-- 标签和描述 -->
  <div v-if="label || description" class="ml-3 inline-block align-middle">
    <p v-if="label" class="text-sm font-medium text-gray-900 dark:text-white">
      {{ label }}
    </p>
    <p v-if="description" class="text-sm text-gray-500 dark:text-gray-400">
      {{ description }}
    </p>
  </div>
</template>
