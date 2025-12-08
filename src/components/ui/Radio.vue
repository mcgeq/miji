<script setup lang="ts">
  import { RadioGroup, RadioGroupOption } from '@headlessui/vue';
  import type { RadioOption } from './types';

  /**
   * Radio - 单选框组件
   *
   * 基于 Headless UI RadioGroup
   * 支持键盘导航和完整的可访问性
   */

  interface Props {
    /** 选中值 */
    modelValue: string | number;
    /** 选项列表 */
    options: RadioOption[];
    /** 标签 */
    label?: string;
    /** 尺寸 */
    size?: 'sm' | 'md' | 'lg';
    /** 布局方向 */
    orientation?: 'horizontal' | 'vertical';
  }

  withDefaults(defineProps<Props>(), {
    size: 'md',
    orientation: 'vertical',
  });

  const emit = defineEmits<{
    'update:modelValue': [value: string | number];
  }>();

  // 尺寸配置
  const sizeConfig = {
    sm: {
      radio: 'w-4 h-4',
      dot: 'w-2 h-2',
      text: 'text-sm',
    },
    md: {
      radio: 'w-5 h-5',
      dot: 'w-2.5 h-2.5',
      text: 'text-base',
    },
    lg: {
      radio: 'w-6 h-6',
      dot: 'w-3 h-3',
      text: 'text-lg',
    },
  };
</script>

<template>
  <RadioGroup :model-value="modelValue" @update:model-value="emit('update:modelValue', $event)">
    <!-- 标签 -->
    <label v-if="label" class="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-3">
      {{ label }}
    </label>

    <!-- 选项列表 -->
    <div
      class="flex gap-3"
      :class="[
        orientation === 'vertical' ? 'flex-col' : 'flex-row flex-wrap',
      ]"
    >
      <RadioGroupOption
        v-for="option in options"
        :key="option.value"
        v-slot="{ checked }"
        :value="option.value"
        :disabled="option.disabled"
        as="template"
      >
        <div
          class="relative flex cursor-pointer rounded-lg px-4 py-3 transition-all focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-offset-2"
          :class="[
            checked
              ? 'bg-blue-50 dark:bg-blue-900/30 border-2 border-blue-500'
              : 'bg-white dark:bg-gray-800 border-2 border-gray-200 dark:border-gray-700 hover:border-gray-300 dark:hover:border-gray-600',
            option.disabled && 'opacity-50 cursor-not-allowed',
          ]"
        >
          <div class="flex w-full items-center justify-between">
            <div class="flex items-center gap-3">
              <!-- 自定义单选框 -->
              <div
                class="rounded-full border-2 flex items-center justify-center transition-all"
                :class="[
                  sizeConfig[size].radio,
                  checked
                    ? 'border-blue-600 bg-blue-600'
                    : 'border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-800',
                ]"
              >
                <div v-if="checked" class="rounded-full bg-white" :class="[sizeConfig[size].dot]" />
              </div>

              <!-- 标签和描述 -->
              <div>
                <div
                  class="font-medium"
                  :class="[
                    sizeConfig[size].text,
                    checked ? 'text-blue-900 dark:text-blue-100' : 'text-gray-900 dark:text-white',
                  ]"
                >
                  {{ option.label }}
                </div>
                <p
                  v-if="option.description"
                  class="text-sm text-gray-500 dark:text-gray-400 mt-0.5"
                >
                  {{ option.description }}
                </p>
              </div>
            </div>

            <!-- 选中图标 -->
            <LucideCheck v-if="checked" class="w-5 h-5 text-blue-600 dark:text-blue-400 shrink-0" />
          </div>
        </div>
      </RadioGroupOption>
    </div>
  </RadioGroup>
</template>
