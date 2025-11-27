<script setup lang="ts">
import { LucideCheck, LucideLoader2, LucideTrash, LucideX } from 'lucide-vue-next';

defineOptions({
  inheritAttrs: false,
});

const props = withDefaults(defineProps<Props>(), {
  size: 'md',
  showFooter: true,
  closeOnOverlay: true,
  showCloseButton: true,
  confirmText: '确认',
  cancelText: '取消',
  showConfirm: true,
  showCancel: true,
  showDelete: false,
  confirmLoading: false,
  confirmDisabled: false,
});

const emit = defineEmits<{
  close: [];
  confirm: [];
  cancel: [];
  delete: [];
}>();

/**
 * 基础 Modal 组件
 * 提供统一的模态框结构和样式
 */
interface Props {
  /** 模态框标题 */
  title?: string;
  /** 模态框尺寸 */
  size?: 'sm' | 'md' | 'lg' | 'xl' | 'full';
  /** 是否显示底部操作栏 */
  showFooter?: boolean;
  /** 点击遮罩层是否关闭 */
  closeOnOverlay?: boolean;
  /** 是否显示关闭按钮 */
  showCloseButton?: boolean;
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
  /** 确认按钮加载状态 */
  confirmLoading?: boolean;
  /** 确认按钮禁用状态 */
  confirmDisabled?: boolean;
}

function handleOverlayClick() {
  if (props.closeOnOverlay) {
    emit('close');
  }
}

function handleClose() {
  emit('close');
}

function handleCancel() {
  emit('cancel');
  emit('close');
}

function handleConfirm() {
  emit('confirm');
}

function handleDelete() {
  emit('delete');
}
</script>

<template>
  <Teleport to="body">
    <div class="base-modal-mask" @click="handleOverlayClick">
      <div
        class="base-modal-container" :class="[
          `base-modal-${size}`,
        ]"
        @click.stop
      >
        <!-- Header -->
        <div class="base-modal-header">
          <slot name="header">
            <h2 class="base-modal-title">
              {{ title }}
            </h2>
          </slot>
          <button
            v-if="showCloseButton"
            class="base-modal-close-btn"
            type="button"
            @click="handleClose"
          >
            <LucideX class="base-modal-close-icon" />
          </button>
        </div>

        <!-- Content -->
        <div class="base-modal-content">
          <slot />
        </div>

        <!-- Footer -->
        <div v-if="props.showFooter" class="base-modal-footer">
          <slot name="footer">
            <button
              v-if="props.showDelete"
              type="button"
              class="base-modal-btn base-modal-btn-delete"
              @click="handleDelete"
            >
              <LucideTrash />
            </button>
            <button
              v-if="props.showCancel"
              type="button"
              class="base-modal-btn base-modal-btn-cancel"
              @click="handleCancel"
            >
              <LucideX />
            </button>
            <button
              v-if="props.showConfirm"
              type="button"
              class="base-modal-btn base-modal-btn-confirm"
              :disabled="props.confirmDisabled || props.confirmLoading"
              @click="handleConfirm"
            >
              <LucideLoader2
                v-if="props.confirmLoading"
                class="base-modal-loading-icon"
              />
              <LucideCheck v-else />
            </button>
          </slot>
        </div>
      </div>
    </div>
  </Teleport>
</template>

<style lang="postcss">
/* Modal Mask - 遮罩层 */
.base-modal-mask {
  position: fixed !important;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background-color: rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 999999 !important;
  padding: 1rem;
  backdrop-filter: blur(4px);
  animation: fadeIn 0.2s ease-out;
  isolation: isolate;
}

@keyframes fadeIn {
  from {
    opacity: 0;
  }
  to {
    opacity: 1;
  }
}

/* Modal Container - 模态框容器 */
.base-modal-container {
  background: rgb(255 255 255);
  border-radius: 1rem;
  box-shadow: 0 25px 50px -12px rgb(0 0 0 / 0.25);
  display: flex;
  flex-direction: column;
  max-height: calc(100vh - 2rem);
  overflow: hidden;
  animation: slideUp 0.3s ease-out;
  position: relative;
  z-index: 9999999 !important;
  isolation: isolate;
}

@media (prefers-color-scheme: dark) {
  .base-modal-container {
    background: rgb(31 41 55);
  }
}

@keyframes slideUp {
  from {
    opacity: 0;
    transform: translateY(20px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

/* Modal Sizes - 尺寸变体 */
.base-modal-sm {
  width: 100%;
  max-width: 400px;
}

.base-modal-md {
  width: 100%;
  max-width: 28rem; /* 448px - 匹配 TransactionModal */
}

.base-modal-lg {
  width: 100%;
  max-width: 800px;
}

.base-modal-xl {
  width: 100%;
  max-width: 1200px;
}

.base-modal-full {
  width: calc(100vw - 2rem);
  height: calc(100vh - 2rem);
  max-width: none;
}

/* Modal Header - 头部 */
.base-modal-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 1.5rem;
  border-bottom: 1px solid rgb(229 231 235);
  flex-shrink: 0;
}

@media (prefers-color-scheme: dark) {
  .base-modal-header {
    border-bottom-color: rgb(55 65 81);
  }
}

.base-modal-title {
  font-size: 1.25rem;
  font-weight: 600;
  color: rgb(17 24 39);
  margin: 0;
}

@media (prefers-color-scheme: dark) {
  .base-modal-title {
    color: rgb(243 244 246);
  }
}

.base-modal-close-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 2rem;
  height: 2rem;
  border-radius: 0.5rem;
  border: none;
  background: transparent;
  color: rgb(107 114 128);
  cursor: pointer;
  transition: all 0.2s ease;
}

.base-modal-close-btn:hover {
  background: rgb(243 244 246);
  color: rgb(55 65 81);
}

@media (prefers-color-scheme: dark) {
  .base-modal-close-btn {
    color: rgb(156 163 175);
  }
  .base-modal-close-btn:hover {
    background: rgb(55 65 81);
    color: rgb(229 231 235);
  }
}

.base-modal-close-icon {
  width: 1.25rem;
  height: 1.25rem;
}

/* Modal Content - 内容区 */
.base-modal-content {
  flex: 1;
  overflow-y: auto;
  padding: 1.5rem;
}

/* 隐藏滚动条但保持滚动功能 */
.base-modal-content::-webkit-scrollbar {
  display: none;
}

.base-modal-content {
  -ms-overflow-style: none;  /* IE and Edge */
  scrollbar-width: none;  /* Firefox */
}

/* Modal Footer - 底部操作栏 */
.base-modal-footer {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.75rem;
  padding: 1.5rem;
  border-top: 1px solid rgb(229 231 235);
  flex-shrink: 0;
}

@media (prefers-color-scheme: dark) {
  .base-modal-footer {
    border-top-color: rgb(55 65 81);
  }
}

/* Modal Buttons - 圆形按钮 */
.base-modal-btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 3rem;
  height: 3rem;
  font-size: 1.25rem;
  border-radius: 50%;
  border: 1px solid transparent;
  cursor: pointer;
  transition: all 0.2s ease;
}

.base-modal-btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.base-modal-btn-cancel {
  background-color: rgb(229 231 235);
  color: rgb(55 65 81);
  border: none;
}

.base-modal-btn-cancel:hover:not(:disabled) {
  background-color: rgb(209 213 219);
  color: rgb(31 41 55);
}

@media (prefers-color-scheme: dark) {
  .base-modal-btn-cancel {
    background-color: rgb(55 65 81);
    color: rgb(229 231 235);
  }
  .base-modal-btn-cancel:hover:not(:disabled) {
    background-color: rgb(75 85 99);
    color: rgb(243 244 246);
  }
}

.base-modal-btn-confirm {
  background-color: rgb(37 99 235);
  color: rgb(255 255 255);
  border: none;
}

.base-modal-btn-confirm:hover:not(:disabled) {
  background-color: rgb(29 78 216);
  color: rgb(255 255 255);
}

.base-modal-btn-delete {
  background-color: rgb(220 38 38);
  color: rgb(255 255 255);
  border: none;
}

.base-modal-btn-delete:hover:not(:disabled) {
  background-color: rgb(185 28 28);
  color: rgb(255 255 255);
}

/* 按钮图标 */
.base-modal-btn svg {
  width: 1.25rem;
  height: 1.25rem;
}

.base-modal-loading-icon {
  width: 1rem;
  height: 1rem;
  animation: spin 1s linear infinite;
}

@keyframes spin {
  from {
    transform: rotate(0deg);
  }
  to {
    transform: rotate(360deg);
  }
}

/* 移动端适配 */
@media (max-width: 768px) {
  .base-modal-mask {
    padding: 0;
  }

  .base-modal-container {
    width: 100%;
    max-width: 100%;
    height: 100%;
    max-height: 100%;
    border-radius: 0;
  }

  .base-modal-sm,
  .base-modal-md,
  .base-modal-lg,
  .base-modal-xl {
    width: 100%;
    max-width: 100%;
  }

  .base-modal-header,
  .base-modal-content,
  .base-modal-footer {
    padding: 1rem;
  }

  .base-modal-footer {
    flex-direction: column-reverse;
  }

  .base-modal-btn {
    width: 100%;
  }
}
</style>
