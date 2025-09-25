<script setup lang="ts">
// Props
interface Props {
  show: boolean;
  title?: string;
  message?: string;
  type?: 'info' | 'warning' | 'danger' | 'success';
  size?: 'sm' | 'md' | 'lg' | 'xl';
  closable?: boolean;
  loading?: boolean;
  showCancel?: boolean;
  confirmText?: string;
  cancelText?: string;
  confirmIcon?: string;
  canConfirm?: boolean;
  persistent?: boolean;
  zIndex?: number;
}

const props = withDefaults(defineProps<Props>(), {
  title: '确认操作',
  message: '您确定要执行此操作吗？',
  type: 'info',
  size: 'md',
  closable: true,
  loading: false,
  showCancel: true,
  confirmText: '确认',
  cancelText: '取消',
  confirmIcon: '',
  canConfirm: true,
  persistent: false,
  zIndex: 1000,
});

// Emits
const emit = defineEmits<{
  'update:show': [show: boolean];
  'confirm': [];
  'cancel': [];
  'close': [];
}>();

// Reactive state
const dialogRef = ref<HTMLDivElement>();
const titleId = ref(`dialog-title-${Date.now()}`);
const contentId = ref(`dialog-content-${Date.now()}`);
const previousActiveElement = ref<Element | null>(null);

// Computed
const dialogClasses = computed(() => {
  const classes = ['dialog'];

  // 尺寸样式
  classes.push(`dialog--${props.size}`);

  // 类型样式
  classes.push(`dialog--${props.type}`);

  // 加载状态
  if (props.loading) {
    classes.push('dialog--loading');
  }

  return classes;
});

const iconClasses = computed(() => {
  const classes = ['dialog-icon-wrapper'];

  switch (props.type) {
    case 'warning':
      classes.push('dialog-icon--warning');
      break;
    case 'danger':
      classes.push('dialog-icon--danger');
      break;
    case 'success':
      classes.push('dialog-icon--success');
      break;
    default:
      classes.push('dialog-icon--info');
  }

  return classes;
});

const iconClass = computed(() => {
  switch (props.type) {
    case 'warning':
      return 'i-tabler-alert-triangle';
    case 'danger':
      return 'i-tabler-alert-circle';
    case 'success':
      return 'i-tabler-check-circle';
    default:
      return 'i-tabler-info-circle';
  }
});

const confirmButtonClasses = computed(() => {
  const classes = ['btn-confirm'];

  switch (props.type) {
    case 'danger':
      classes.push('btn-confirm--danger');
      break;
    case 'warning':
      classes.push('btn-confirm--warning');
      break;
    case 'success':
      classes.push('btn-confirm--success');
      break;
    default:
      classes.push('btn-confirm--primary');
  }

  return classes;
});

// Methods
function handleConfirm() {
  if (props.loading || !props.canConfirm)
    return;
  emit('confirm');
}

function handleCancel() {
  if (props.loading)
    return;
  emit('cancel');
  handleClose();
}

function handleClose() {
  emit('update:show', false);
  emit('close');
}

function handleOverlayClick() {
  if (props.persistent || props.loading)
    return;
  handleCancel();
}

function handleEscape(event: KeyboardEvent) {
  if (props.persistent || props.loading)
    return;
  event.preventDefault();
  handleCancel();
}

async function focusDialog() {
  await nextTick();
  if (dialogRef.value) {
    dialogRef.value.focus();
  }
}

async function onEnter() {
  // 保存当前焦点元素
  previousActiveElement.value = document.activeElement;

  // 禁用页面滚动
  document.body.style.overflow = 'hidden';

  // 设置焦点
  await focusDialog();
}

function onLeave() {
  // 恢复页面滚动
  document.body.style.overflow = '';

  // 恢复焦点
  if (previousActiveElement.value) {
    (previousActiveElement.value as HTMLElement).focus?.();
  }
}

// 键盘导航处理
function handleKeyDown(event: KeyboardEvent) {
  if (!props.show)
    return;

  // Tab 键焦点陷阱
  if (event.key === 'Tab' && dialogRef.value) {
    const focusableElements = dialogRef.value.querySelectorAll(
      'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])',
    );

    const firstElement = focusableElements[0] as HTMLElement;
    const lastElement = focusableElements[
      focusableElements.length - 1
    ] as HTMLElement;

    if (event.shiftKey) {
      if (document.activeElement === firstElement) {
        event.preventDefault();
        lastElement?.focus();
      }
    } else {
      if (document.activeElement === lastElement) {
        event.preventDefault();
        firstElement?.focus();
      }
    }
  }
}

// Watchers
watch(
  () => props.show,
  async newValue => {
    if (newValue) {
      await focusDialog();
    }
  },
);

// Lifecycle
onMounted(() => {
  document.addEventListener('keydown', handleKeyDown);
});

onUnmounted(() => {
  document.removeEventListener('keydown', handleKeyDown);
  // 清理样式
  document.body.style.overflow = '';
});

// Expose for parent component
defineExpose({
  focus: focusDialog,
  close: handleClose,
});
</script>

<template>
  <Teleport to="body">
    <Transition
      name="dialog-fade"
      appear
      @enter="onEnter"
      @leave="onLeave"
    >
      <div
        v-if="show"
        class="dialog-overlay"
        role="dialog"
        aria-modal="true"
        :aria-labelledby="titleId"
        :aria-describedby="contentId"
        @click="handleOverlayClick"
      >
        <div
          ref="dialogRef"
          class="dialog-container"
          :class="dialogClasses"
          tabindex="-1"
          @click.stop
          @keydown.esc="handleEscape"
        >
          <!-- 对话框头部 -->
          <div class="dialog-header">
            <div class="dialog-title-section">
              <div class="dialog-icon" :class="iconClasses">
                <i :class="iconClass" class="wh-6" />
              </div>
              <h3 :id="titleId" class="dialog-title">
                {{ title }}
              </h3>
            </div>
            <button
              v-if="closable"
              class="dialog-close"
              type="button"
              :disabled="loading"
              aria-label="关闭对话框"
              @click="handleCancel"
            >
              <i class="wh-5 i-tabler-x" />
            </button>
          </div>

          <!-- 对话框内容 -->
          <div :id="contentId" class="dialog-content">
            <slot>
              <p class="dialog-message">
                {{ message }}
              </p>
            </slot>
          </div>

          <!-- 对话框底部 -->
          <div class="dialog-footer">
            <div class="dialog-actions">
              <button
                v-if="showCancel"
                :disabled="loading"
                class="btn-cancel"
                type="button"
                @click="handleCancel"
              >
                {{ cancelText }}
              </button>
              <button
                :disabled="loading || !canConfirm"
                class="btn-confirm"
                :class="confirmButtonClasses"
                type="button"
                @click="handleConfirm"
              >
                <i
                  v-if="loading"
                  class="icon icon--loading"
                />
                <i
                  v-else-if="confirmIcon"
                  class="icon"
                  :class="[confirmIcon]"
                />
                {{ confirmText }}
              </button>
            </div>
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<style scoped lang="postcss">
.dialog-overlay {
  position: fixed;
  inset: 0;
  z-index: 50;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 1rem;
  background-color: rgba(0, 0, 0, 0.5);
  backdrop-filter: blur(4px);
}

.dialog-container {
  position: relative;
  width: 100%;
  max-height: 90vh;
  overflow: hidden;
  background-color: #ffffff;
  border-radius: 0.5rem;
  box-shadow: 0 10px 25px rgba(0, 0, 0, 0.2);
  outline: none;
}

.dialog-container.dark {
  background-color: #1f2937; /* gray-800 */
}

.dialog--sm { max-width: 24rem; }
.dialog--md { max-width: 28rem; }
.dialog--lg { max-width: 32rem; }
.dialog--xl { max-width: 36rem; }

.dialog--loading {
  pointer-events: none;
  user-select: none;
}

.dialog-header {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  padding: 1.5rem;
  padding-bottom: 1rem;
  border-bottom: 1px solid #e5e7eb;
}

.dark .dialog-header {
  border-color: #374151;
}

.dialog-title-section {
  display: flex;
  align-items: center;
  gap: 0.75rem;
}

.dialog-icon-wrapper {
  flex-shrink: 0;
  width: 2.5rem;
  height: 2.5rem;
  border-radius: 9999px;
  display: flex;
  align-items: center;
  justify-content: center;
}

.dialog-icon--info {
  background-color: #dbeafe;
  color: #2563eb;
}

.dark .dialog-icon--info {
  background-color: rgba(30, 58, 138, 0.3);
  color: #60a5fa;
}

.dialog-icon--warning {
  background-color: #fef9c3;
  color: #ca8a04;
}

.dark .dialog-icon--warning {
  background-color: rgba(113, 63, 18, 0.3);
  color: #facc15;
}

.dialog-icon--danger {
  background-color: #fee2e2;
  color: #dc2626;
}

.dark .dialog-icon--danger {
  background-color: rgba(127, 29, 29, 0.3);
  color: #f87171;
}

.dialog-icon--success {
  background-color: #dcfce7;
  color: #16a34a;
}

.dark .dialog-icon--success {
  background-color: rgba(20, 83, 45, 0.3);
  color: #4ade80;
}

.dialog-title {
  font-size: 1.125rem;
  font-weight: 600;
  color: #111827;
}

.dark .dialog-title {
  color: #ffffff;
}

.dialog-close {
  flex-shrink: 0;
  padding: 0.5rem;
  border-radius: 0.5rem;
  color: #9ca3af;
  background: transparent;
  transition: all 0.2s ease;
}

.dialog-close:hover {
  color: #4b5563;
  background-color: #f3f4f6;
}

.dark .dialog-close {
  color: #6b7280;
}

.dark .dialog-close:hover {
  color: #d1d5db;
  background-color: #374151;
}

.dialog-content {
  padding: 1rem 1.5rem;
  max-height: 24rem;
  overflow-y: auto;
}

.dialog-message {
  color: #374151;
  line-height: 1.625;
}

.dark .dialog-message {
  color: #d1d5db;
}

.dialog-footer {
  padding: 1rem 1.5rem;
  background-color: #f9fafb;
  border-top: 1px solid #e5e7eb;
}

.dark .dialog-footer {
  background-color: rgba(17, 24, 39, 0.5);
  border-color: #374151;
}

.dialog-actions {
  display: flex;
  justify-content: flex-end;
  gap: 0.75rem;
}

.btn-cancel {
  padding: 0.5rem 1rem;
  font-size: 0.875rem;
  font-weight: 500;
  border-radius: 0.5rem;
  border: 1px solid #d1d5db;
  background-color: #ffffff;
  color: #374151;
  transition: all 0.2s ease;
}

.btn-cancel:hover {
  background-color: #f9fafb;
}

.dark .btn-cancel {
  border-color: #4b5563;
  background-color: #1f2937;
  color: #d1d5db;
}

.dark .btn-cancel:hover {
  background-color: #374151;
}

.btn-confirm {
  display: flex;
  align-items: center;
  padding: 0.5rem 1rem;
  font-size: 0.875rem;
  font-weight: 500;
  border-radius: 0.5rem;
  border: 1px solid transparent;
  transition: all 0.2s ease;
}

.btn-confirm:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.btn-confirm--primary {
  background-color: #2563eb;
  color: #ffffff;
}

.btn-confirm--primary:hover {
  background-color: #1d4ed8;
}

.btn-confirm--danger {
  background-color: #dc2626;
  color: #ffffff;
}

.btn-confirm--danger:hover {
  background-color: #b91c1c;
}

.btn-confirm--warning {
  background-color: #ca8a04;
  color: #ffffff;
}

.btn-confirm--warning:hover {
  background-color: #a16207;
}

.btn-confirm--success {
  background-color: #16a34a;
  color: #ffffff;
}

.btn-confirm--success:hover {
  background-color: #15803d;
}

/* 动画效果 */
.dialog-fade-enter-active {
  transition: all 0.2s ease-out;
}

.dialog-fade-leave-active {
  transition: all 0.15s ease-in;
}

.dialog-fade-enter-from {
  opacity: 0;
}

.dialog-fade-enter-from .dialog-container {
  transform: scale(0.95) translateY(1rem);
}

.dialog-fade-leave-to {
  opacity: 0;
}

.dialog-fade-leave-to .dialog-container {
  transform: scale(0.95) translateY(1rem);
}

.icon {
  margin-right: 0.5rem; /* 替代 mr-2 */
  width: 1rem;         /* 替代 wh-4 */
  height: 1rem;
  display: inline-block;
}

/* 加载状态旋转动画 */
.icon--loading {
  animation: spin 1s linear infinite;
}

/* 旋转关键帧 */
@keyframes spin {
  from {
    transform: rotate(0deg);
  }
  to {
    transform: rotate(360deg);
  }
}

/* 响应式 */
@media (max-width: 640px) {
  .dialog-overlay {
    padding: 0.5rem;
  }

  .dialog-container {
    max-width: 100%;
  }

  .dialog-header {
    padding: 1rem;
    padding-bottom: 0.75rem;
  }

  .dialog-content {
    padding: 0.75rem 1rem;
  }

  .dialog-footer {
    padding: 0.75rem 1rem;
  }

  .dialog-actions {
    flex-direction: column;
    gap: 0.5rem;
  }

  .btn-cancel,
  .btn-confirm {
    width: 100%;
    justify-content: center;
  }
}

/* 无障碍：减少动效 */
@media (prefers-reduced-motion: reduce) {
  .dialog-fade-enter-active,
  .dialog-fade-leave-active {
    transition: none;
  }
}

/* 高对比度模式 */
@media (prefers-contrast: high) {
  .dialog-container {
    border: 2px solid #111827;
  }

  .dark .dialog-container {
    border-color: #f9fafb;
  }

  .dialog-header {
    border-bottom-width: 2px;
  }

  .dialog-footer {
    border-top-width: 2px;
  }
}

/* 打印隐藏对话框 */
@media print {
  .dialog-overlay {
    display: none;
  }
}
</style>
