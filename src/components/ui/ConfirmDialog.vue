<script setup lang="ts">
/**
 * ConfirmDialog - 确认对话框组件
 *
 * 用于快速确认操作，支持不同类型和状态
 * 基于 Headless UI + Tailwind CSS 4
 */

import { Dialog, DialogPanel, DialogTitle, TransitionChild, TransitionRoot } from '@headlessui/vue';
import { AlertCircle, AlertTriangle, CheckCircle, Info, X } from 'lucide-vue-next';
import { computed } from 'vue';

interface Props {
  /** 是否显示 */
  open: boolean;
  /** 类型 */
  type?: 'info' | 'success' | 'warning' | 'error';
  /** 标题 */
  title: string;
  /** 消息内容 */
  message?: string;
  /** 确认按钮文本 */
  confirmText?: string;
  /** 取消按钮文本 */
  cancelText?: string;
  /** 是否显示取消按钮 */
  showCancel?: boolean;
  /** 加载状态 */
  loading?: boolean;
  /** 确认按钮禁用 */
  confirmDisabled?: boolean;
}

const props = withDefaults(defineProps<Props>(), {
  type: 'info',
  confirmText: '确认',
  cancelText: '取消',
  showCancel: true,
  loading: false,
  confirmDisabled: false,
});

const emit = defineEmits<{
  close: [];
  confirm: [];
  cancel: [];
}>();

// 类型配置
const typeConfig = computed(() => {
  const configs = {
    info: {
      icon: Info,
      iconClass: 'bg-blue-50 dark:bg-blue-900/30 text-blue-600 dark:text-blue-400',
      btnClass: 'bg-blue-600 hover:bg-blue-700 text-white',
    },
    success: {
      icon: CheckCircle,
      iconClass: 'bg-green-50 dark:bg-green-900/30 text-green-600 dark:text-green-400',
      btnClass: 'bg-green-600 hover:bg-green-700 text-white',
    },
    warning: {
      icon: AlertTriangle,
      iconClass: 'bg-yellow-50 dark:bg-yellow-900/30 text-yellow-600 dark:text-yellow-400',
      btnClass: 'bg-yellow-600 hover:bg-yellow-700 text-white',
    },
    error: {
      icon: AlertCircle,
      iconClass: 'bg-red-50 dark:bg-red-900/30 text-red-600 dark:text-red-400',
      btnClass: 'bg-red-600 hover:bg-red-700 text-white',
    },
  };
  return configs[props.type];
});

function handleCancel() {
  emit('cancel');
  emit('close');
}
</script>

<template>
  <TransitionRoot :show="open" as="template">
    <Dialog class="relative z-[999999]" @close="emit('close')">
      <!-- 遮罩层 -->
      <TransitionChild
        as="template"
        enter="duration-200 ease-out"
        enter-from="opacity-0"
        leave="duration-150 ease-in"
        leave-to="opacity-0"
      >
        <div class="fixed inset-0 bg-black/50 backdrop-blur-sm" />
      </TransitionChild>

      <!-- 对话框容器 -->
      <div class="fixed inset-0 flex items-center justify-center p-4">
        <TransitionChild
          as="template"
          enter="duration-200 ease-out"
          enter-from="opacity-0 scale-95"
          leave="duration-150 ease-in"
          leave-to="opacity-0 scale-95"
        >
          <DialogPanel class="bg-white dark:bg-gray-800 rounded-xl shadow-2xl max-w-md w-full overflow-hidden">
            <!-- 内容区 -->
            <div class="p-6 flex items-start gap-4">
              <!-- 图标 -->
              <div class="p-3 rounded-full shrink-0" :class="[typeConfig.iconClass]">
                <component :is="typeConfig.icon" class="w-6 h-6" />
              </div>

              <!-- 文本内容 -->
              <div class="flex-1 min-w-0">
                <DialogTitle class="text-lg font-semibold text-gray-900 dark:text-white mb-2">
                  {{ title }}
                </DialogTitle>
                <p v-if="message" class="text-sm text-gray-600 dark:text-gray-300">
                  {{ message }}
                </p>
                <!-- 自定义内容插槽 -->
                <div v-if="$slots.default" class="mt-2">
                  <slot />
                </div>
              </div>

              <!-- 关闭按钮（右上角） -->
              <button
                type="button"
                class="p-1 rounded-lg text-gray-400 hover:text-gray-600 hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors shrink-0"
                aria-label="关闭"
                @click="emit('close')"
              >
                <X class="w-5 h-5" />
              </button>
            </div>

            <!-- 底部按钮 -->
            <div class="bg-gray-50 dark:bg-gray-900/50 px-6 py-4 flex justify-end gap-3">
              <button
                v-if="showCancel"
                type="button"
                :disabled="loading"
                class="px-4 py-2 rounded-lg border border-gray-300 dark:border-gray-600 text-gray-700 dark:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700 disabled:opacity-50 transition-colors"
                @click="handleCancel"
              >
                {{ cancelText }}
              </button>
              <button
                type="button"
                :disabled="loading || confirmDisabled"
                class="px-4 py-2 rounded-lg transition-colors disabled:opacity-50 disabled:cursor-not-allowed"
                :class="[
                  typeConfig.btnClass,
                ]" @click="emit('confirm')"
              >
                <span v-if="loading" class="flex items-center gap-2">
                  <svg class="animate-spin w-4 h-4" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                    <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" />
                    <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z" />
                  </svg>
                  处理中...
                </span>
                <span v-else>{{ confirmText }}</span>
              </button>
            </div>
          </DialogPanel>
        </TransitionChild>
      </div>
    </Dialog>
  </TransitionRoot>
</template>
