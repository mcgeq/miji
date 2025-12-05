<script setup lang="ts">
import type { Component } from 'vue';

/**
 * Tabs - 标签页组件
 *
 * 基于 Headless UI Tab 组件
 * 支持键盘导航（左右箭头）
 */

import { Tab, TabGroup, TabList, TabPanel, TabPanels } from '@headlessui/vue';

export interface TabItem {
  /** 标签名称 */
  name: string;
  /** 标签值（唯一标识） */
  value?: string;
  /** 图标组件 */
  icon?: Component;
  /** 是否禁用 */
  disabled?: boolean;
  /** 徽章数字 */
  badge?: number;
}

interface Props {
  /** 标签列表 */
  tabs: TabItem[];
  /** 当前选中的索引 */
  modelValue?: number;
  /** 默认选中索引 */
  defaultIndex?: number;
  /** 标签样式 */
  variant?: 'pills' | 'underline' | 'enclosed';
  /** 垂直排列 */
  vertical?: boolean;
}

const props = withDefaults(defineProps<Props>(), {
  defaultIndex: 0,
  variant: 'pills',
  vertical: false,
});

const emit = defineEmits<{
  'update:modelValue': [index: number];
  'change': [index: number, tab: TabItem];
}>();

function handleChange(index: number) {
  emit('update:modelValue', index);
  emit('change', index, props.tabs[index]);
}
</script>

<template>
  <TabGroup
    :default-index="defaultIndex"
    :selected-index="modelValue"
    :vertical="vertical"
    as="div"
    :class="[
      vertical ? 'flex gap-4' : '',
    ]"
    @change="handleChange"
  >
    <!-- 标签列表 -->
    <TabList
      class="flex gap-2" :class="[
        variant === 'pills' && 'p-1 bg-gray-100 dark:bg-gray-800 rounded-lg',
        variant === 'underline' && 'border-b border-gray-200 dark:border-gray-700',
        variant === 'enclosed' && 'border-b border-gray-200 dark:border-gray-700',
        vertical && 'flex-col',
      ]"
    >
      <Tab
        v-for="(tab, index) in tabs"
        :key="tab.value || index"
        v-slot="{ selected }"
        :disabled="tab.disabled"
        class="px-4 py-2 text-sm font-medium outline-none transition-colors whitespace-nowrap focus:ring-2 focus:ring-blue-500 focus:ring-offset-2" :class="[
          tab.disabled && 'opacity-50 cursor-not-allowed',
        ]"
      >
        <div
          class="flex items-center gap-2" :class="[
            variant === 'pills' && [
              'rounded-md',
              selected
                ? 'bg-white dark:bg-gray-700 text-blue-600 dark:text-blue-400 shadow'
                : 'text-gray-700 dark:text-gray-300 hover:bg-gray-200 dark:hover:bg-gray-700',
            ],

            // Underline 样式
            variant === 'underline' && [
              'border-b-2 -mb-px',
              selected
                ? 'border-blue-600 text-blue-600 dark:text-blue-400'
                : 'border-transparent text-gray-700 dark:text-gray-300 hover:text-gray-900 dark:hover:text-gray-100 hover:border-gray-300',
            ],

            // Enclosed 样式
            variant === 'enclosed' && [
              'rounded-t-lg border-x border-t -mb-px',
              selected
                ? 'border-gray-200 dark:border-gray-700 bg-white dark:bg-gray-800 text-blue-600 dark:text-blue-400'
                : 'border-transparent text-gray-700 dark:text-gray-300 hover:text-gray-900 dark:hover:text-gray-100',
            ],
          ]"
        >
          <!-- 图标 -->
          <component
            :is="tab.icon"
            v-if="tab.icon"
            class="w-4 h-4"
          />

          <!-- 标签名称 -->
          <span>{{ tab.name }}</span>

          <!-- 徽章 -->
          <span
            v-if="tab.badge !== undefined"
            class="px-1.5 py-0.5 text-xs rounded-full" :class="[
              selected
                ? 'bg-blue-100 dark:bg-blue-900 text-blue-600 dark:text-blue-300'
                : 'bg-gray-200 dark:bg-gray-700 text-gray-600 dark:text-gray-300',
            ]"
          >
            {{ tab.badge }}
          </span>
        </div>
      </Tab>
    </TabList>

    <!-- 面板内容 -->
    <TabPanels class="mt-4 flex-1">
      <TabPanel
        v-for="(tab, index) in tabs"
        :key="tab.value || index"
        class="rounded-lg bg-white dark:bg-gray-800 p-6 focus:outline-none focus:ring-2 focus:ring-blue-500"
      >
        <slot :name="`panel-${index}`" :tab="tab" :index="index">
          <!-- 默认插槽 -->
          <slot />
        </slot>
      </TabPanel>
    </TabPanels>
  </TabGroup>
</template>
