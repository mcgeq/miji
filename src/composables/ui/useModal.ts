/**
 * useModal - Headless Modal Composable
 *
 * 提供模态框的核心逻辑，不包含任何样式
 * 可以与任何 UI 框架配合使用
 */

import { computed, onMounted, onUnmounted, ref } from 'vue';

export interface UseModalOptions {
  /** 初始打开状态 */
  initialOpen?: boolean;
  /** 点击遮罩层是否关闭 */
  closeOnOverlay?: boolean;
  /** 按 ESC 键是否关闭 */
  closeOnEsc?: boolean;
  /** 打开时的回调 */
  onOpen?: () => void;
  /** 关闭时的回调 */
  onClose?: () => void;
}

export function useModal(options: UseModalOptions = {}) {
  const {
    initialOpen = false,
    closeOnOverlay = true,
    closeOnEsc = true,
    onOpen,
    onClose,
  } = options;

  // ========================================
  // 状态管理
  // ========================================
  const isOpen = ref(initialOpen);
  const previousActiveElement = ref<HTMLElement | null>(null);

  // ========================================
  // 核心方法
  // ========================================

  /**
   * 打开模态框
   */
  function open() {
    if (isOpen.value) return;

    // 保存当前焦点元素
    previousActiveElement.value = document.activeElement as HTMLElement;

    // 禁用 body 滚动
    document.body.style.overflow = 'hidden';

    isOpen.value = true;
    onOpen?.();
  }

  /**
   * 关闭模态框
   */
  function close() {
    if (!isOpen.value) return;

    // 恢复 body 滚动
    document.body.style.overflow = '';

    // 恢复之前的焦点
    previousActiveElement.value?.focus();

    isOpen.value = false;
    onClose?.();
  }

  /**
   * 切换模态框状态
   */
  function toggle() {
    isOpen.value ? close() : open();
  }

  // ========================================
  // 键盘事件处理
  // ========================================

  function handleEscape(e: KeyboardEvent) {
    if (closeOnEsc && e.key === 'Escape' && isOpen.value) {
      e.preventDefault();
      close();
    }
  }

  // ========================================
  // 生命周期
  // ========================================

  onMounted(() => {
    document.addEventListener('keydown', handleEscape);
  });

  onUnmounted(() => {
    document.removeEventListener('keydown', handleEscape);
    // 清理：确保 body 滚动恢复
    document.body.style.overflow = '';
  });

  // ========================================
  // 返回 API
  // ========================================

  return {
    // 状态
    isOpen: computed(() => isOpen.value),

    // 方法
    open,
    close,
    toggle,

    // 属性绑定（用于遮罩层）
    overlayProps: computed(() => ({
      onClick: closeOnOverlay ? close : undefined,
    })),

    // 属性绑定（用于模态框容器）
    containerProps: computed(() => ({
      'role': 'dialog',
      'aria-modal': 'true',
      'onClick': (e: Event) => e.stopPropagation(),
    })),
  };
}
