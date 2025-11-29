<script setup lang="ts">
/**
 * Alert - 警告提示组件
 *
 * 用于显示重要的提示信息
 * 100% Tailwind CSS 4
 */

import { AlertCircle, AlertTriangle, CheckCircle, Info, X } from 'lucide-vue-next';
import { computed } from 'vue';

interface Props {
  /** 类型 */
  type?: 'info' | 'success' | 'warning' | 'error';
  /** 标题 */
  title?: string;
  /** 描述 */
  description?: string;
  /** 是否可关闭 */
  closable?: boolean;
  /** 是否显示图标 */
  showIcon?: boolean;
}

const props = withDefaults(defineProps<Props>(), {
  type: 'info',
  closable: false,
  showIcon: true,
});

const emit = defineEmits<{
  close: [];
}>();

// 类型配置
const typeConfig = computed(() => {
  const configs = {
    info: {
      icon: Info,
      containerClass: 'bg-blue-50 dark:bg-blue-900/20 border-blue-200 dark:border-blue-800',
      iconClass: 'text-blue-600 dark:text-blue-400',
      titleClass: 'text-blue-900 dark:text-blue-200',
      descClass: 'text-blue-700 dark:text-blue-300',
    },
    success: {
      icon: CheckCircle,
      containerClass: 'bg-green-50 dark:bg-green-900/20 border-green-200 dark:border-green-800',
      iconClass: 'text-green-600 dark:text-green-400',
      titleClass: 'text-green-900 dark:text-green-200',
      descClass: 'text-green-700 dark:text-green-300',
    },
    warning: {
      icon: AlertTriangle,
      containerClass: 'bg-yellow-50 dark:bg-yellow-900/20 border-yellow-200 dark:border-yellow-800',
      iconClass: 'text-yellow-600 dark:text-yellow-400',
      titleClass: 'text-yellow-900 dark:text-yellow-200',
      descClass: 'text-yellow-700 dark:text-yellow-300',
    },
    error: {
      icon: AlertCircle,
      containerClass: 'bg-red-50 dark:bg-red-900/20 border-red-200 dark:border-red-800',
      iconClass: 'text-red-600 dark:text-red-400',
      titleClass: 'text-red-900 dark:text-red-200',
      descClass: 'text-red-700 dark:text-red-300',
    },
  };
  return configs[props.type];
});
</script>

<template>
  <div
    class="rounded-lg border p-4 flex gap-3" :class="[
      typeConfig.containerClass,
    ]"
  >
    <!-- 图标 -->
    <component
      :is="typeConfig.icon"
      v-if="showIcon"
      class="w-5 h-5 shrink-0 mt-0.5" :class="[typeConfig.iconClass]"
    />

    <!-- 内容 -->
    <div class="flex-1 min-w-0">
      <!-- 标题 -->
      <div
        v-if="title || $slots.title"
        class="font-semibold mb-1" :class="[typeConfig.titleClass]"
      >
        <slot name="title">
          {{ title }}
        </slot>
      </div>

      <!-- 描述 -->
      <div class="text-sm" :class="[typeConfig.descClass]">
        <slot>{{ description }}</slot>
      </div>
    </div>

    <!-- 关闭按钮 -->
    <button
      v-if="closable"
      type="button"
      class="shrink-0 p-1 rounded hover:bg-black/5 dark:hover:bg-white/5 transition-colors" :class="[
        typeConfig.iconClass,
      ]"
      aria-label="关闭"
      @click="emit('close')"
    >
      <X class="w-4 h-4" />
    </button>
  </div>
</template>
