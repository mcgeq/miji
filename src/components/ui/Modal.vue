<script setup lang="ts">
/**
 * Modal - 基于 Headless UI 的模态框组件
 *
 * 使用 @headlessui/vue 提供逻辑，Tailwind CSS 4 提供样式
 * 100% 可定制，无自定义 CSS
 */

import { Dialog, DialogPanel, DialogTitle, TransitionChild, TransitionRoot } from '@headlessui/vue';
import { Check, X } from 'lucide-vue-next';

interface Props {
  /** 是否显示 */
  open: boolean;
  /** 标题 */
  title?: string;
  /** 尺寸 */
  size?: 'sm' | 'md' | 'lg' | 'xl' | 'full';
  /** 点击遮罩层是否关闭 */
  closeOnOverlay?: boolean;
  /** 是否显示头部 */
  showHeader?: boolean;
  /** 是否显示底部 */
  showFooter?: boolean;
  /** 确认按钮文本 */
  confirmText?: string;
  /** 取消按钮文本 */
  cancelText?: string;
  /** 是否显示确认按钮 */
  showConfirm?: boolean;
  /** 是否显示取消按钮 */
  showCancel?: boolean;
  /** 是否显示删除按钮 */
  showDelete?: boolean;
  /** 删除按钮文本 */
  deleteText?: string;
  /** 确认按钮禁用状态 */
  confirmDisabled?: boolean;
  /** 确认按钮加载状态 */
  confirmLoading?: boolean;
}

const props = withDefaults(defineProps<Props>(), {
  size: 'md',
  closeOnOverlay: true,
  showHeader: true,
  showFooter: true,
  confirmText: '确认',
  cancelText: '取消',
  showConfirm: true,
  showCancel: true,
  showDelete: false,
  deleteText: '删除',
  confirmDisabled: false,
  confirmLoading: false,
});

const emit = defineEmits<{
  close: [];
  confirm: [];
  cancel: [];
  delete: [];
}>();

// 尺寸映射
const sizeClasses = {
  sm: 'max-w-sm',
  md: 'max-w-md',
  lg: 'max-w-lg',
  xl: 'max-w-xl',
  full: 'max-w-[90vw]',
};
</script>

<template>
  <TransitionRoot :show="open" as="template">
    <Dialog
      :open="open"
      class="relative z-[999999]"
      @close="props.closeOnOverlay && emit('close')"
    >
      <!-- 遮罩层 -->
      <TransitionChild
        as="template"
        enter="duration-200 ease-out"
        enter-from="opacity-0"
        leave="duration-150 ease-in"
        leave-to="opacity-0"
      >
        <div class="fixed inset-0 bg-black/50 backdrop-blur-sm" aria-hidden="true" />
      </TransitionChild>

      <!-- 模态框容器 -->
      <div class="fixed inset-0 flex items-center justify-center p-4">
        <TransitionChild
          as="template"
          enter="duration-200 ease-out"
          enter-from="opacity-0 scale-95 translate-y-4"
          leave="duration-150 ease-in"
          leave-to="opacity-0 scale-95 translate-y-4"
        >
          <DialogPanel
            class="w-full rounded-xl shadow-2xl bg-white dark:bg-gray-800 max-h-[90vh] overflow-hidden flex flex-col" :class="[
              sizeClasses[props.size],
            ]"
          >
            <!-- 头部 -->
            <div
              v-if="props.showHeader"
              class="flex items-center justify-between px-6 py-4 border-b border-gray-200 dark:border-gray-700 shrink-0"
            >
              <DialogTitle class="text-xl font-semibold text-gray-900 dark:text-white">
                <slot name="header">
                  {{ props.title }}
                </slot>
              </DialogTitle>

              <button
                type="button"
                class="p-2 rounded-lg text-gray-500 hover:bg-gray-100 dark:hover:bg-gray-700 transition-colors"
                aria-label="关闭"
                @click="emit('close')"
              >
                <X class="w-5 h-5" />
              </button>
            </div>

            <!-- 内容区 -->
            <div class="flex-1 overflow-y-auto px-6 py-4">
              <slot />
            </div>

            <!-- 底部操作栏 -->
            <div
              v-if="props.showFooter"
              class="border-t border-gray-200 dark:border-gray-700 px-6 py-4 shrink-0"
            >
              <slot name="footer">
                <div class="flex justify-center gap-3">
                  <!-- 删除按钮 -->
                  <button
                    v-if="props.showDelete"
                    type="button"
                    class="flex items-center justify-center w-12 h-12 rounded-full bg-red-600 text-white hover:bg-red-700 disabled:opacity-50 transition-colors"
                    :disabled="props.confirmLoading"
                    @click="emit('delete')"
                  >
                    {{ props.deleteText }}
                  </button>

                  <!-- 取消按钮 -->
                  <button
                    v-if="props.showCancel"
                    type="button"
                    class="flex items-center justify-center w-12 h-12 rounded-full border border-gray-300 dark:border-gray-600 hover:bg-gray-50 dark:hover:bg-gray-700 transition-colors"
                    :disabled="props.confirmLoading"
                    @click="emit('cancel'); emit('close')"
                  >
                    {{ props.cancelText }}
                  </button>

                  <!-- 确认按钮 -->
                  <button
                    v-if="props.showConfirm"
                    type="button"
                    :disabled="props.confirmDisabled || props.confirmLoading"
                    class="flex items-center justify-center w-12 h-12 rounded-full bg-blue-600 text-white hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed transition-colors"
                    @click="emit('confirm')"
                  >
                    <!-- 加载状态 -->
                    <svg
                      v-if="props.confirmLoading"
                      class="animate-spin w-5 h-5"
                      xmlns="http://www.w3.org/2000/svg"
                      fill="none"
                      viewBox="0 0 24 24"
                    >
                      <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4" />
                      <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z" />
                    </svg>
                    <!-- 确认图标 -->
                    <Check v-else class="w-5 h-5" />
                  </button>
                </div>
              </slot>
            </div>
          </DialogPanel>
        </TransitionChild>
      </div>
    </Dialog>
  </TransitionRoot>
</template>
