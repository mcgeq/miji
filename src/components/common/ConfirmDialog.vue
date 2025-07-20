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
    }
    else {
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
              <i class="i-tabler-x wh-5" />
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
                  class="i-tabler-loader-2 mr-2 wh-4 animate-spin"
                />
                <i
                  v-else-if="confirmIcon"
                  :class="confirmIcon"
                  class="mr-2 wh-4"
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
  @apply fixed inset-0 z-50 flex items-center justify-center p-4
         bg-black/50 backdrop-blur-sm;
}

.dialog-container {
  @apply relative w-full max-h-[90vh] overflow-hidden
         bg-white dark:bg-gray-800 rounded-lg shadow-xl
         focus:outline-none;
}

.dialog--sm {
  @apply max-w-sm;
}

.dialog--md {
  @apply max-w-md;
}

.dialog--lg {
  @apply max-w-lg;
}

.dialog--xl {
  @apply max-w-xl;
}

.dialog--loading {
  @apply pointer-events-none select-none;
}

.dialog-header {
  @apply flex items-start justify-between p-6 pb-4
         border-b border-gray-200 dark:border-gray-700;
}

.dialog-title-section {
  @apply flex items-center gap-3;
}

.dialog-icon-wrapper {
  @apply flex-shrink-0 w-10 h-10 rounded-full flex items-center justify-center;
}

.dialog-icon--info {
  @apply bg-blue-100 dark:bg-blue-900/30 text-blue-600 dark:text-blue-400;
}

.dialog-icon--warning {
  @apply bg-yellow-100 dark:bg-yellow-900/30 text-yellow-600 dark:text-yellow-400;
}

.dialog-icon--danger {
  @apply bg-red-100 dark:bg-red-900/30 text-red-600 dark:text-red-400;
}

.dialog-icon--success {
  @apply bg-green-100 dark:bg-green-900/30 text-green-600 dark:text-green-400;
}

.dialog-title {
  @apply text-lg font-semibold text-gray-900 dark:text-white;
}

.dialog-close {
  @apply flex-shrink-0 p-2 rounded-lg
         text-gray-400 hover:text-gray-600 dark:text-gray-500 dark:hover:text-gray-300
         hover:bg-gray-100 dark:hover:bg-gray-700
         focus:outline-none focus:ring-2 focus:ring-gray-500 focus:ring-offset-2
         dark:focus:ring-offset-gray-800
         transition-colors disabled:opacity-50;
}

.dialog-content {
  @apply px-6 py-4 max-h-96 overflow-y-auto;
}

.dialog-message {
  @apply text-gray-700 dark:text-gray-300 leading-relaxed;
}

.dialog-footer {
  @apply px-6 py-4 bg-gray-50 dark:bg-gray-900/50
         border-t border-gray-200 dark:border-gray-700;
}

.dialog-actions {
  @apply flex justify-end gap-3;
}

.btn-cancel {
  @apply px-4 py-2 text-sm font-medium rounded-lg border
         border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-800
         text-gray-700 dark:text-gray-300
         hover:bg-gray-50 dark:hover:bg-gray-700
         focus:outline-none focus:ring-2 focus:ring-gray-500 focus:ring-offset-2
         dark:focus:ring-offset-gray-800
         transition-colors disabled:opacity-50 disabled:cursor-not-allowed;
}

.btn-confirm {
  @apply px-4 py-2 text-sm font-medium rounded-lg border border-transparent
         focus:outline-none focus:ring-2 focus:ring-offset-2
         transition-colors disabled:opacity-50 disabled:cursor-not-allowed
         flex items-center;
}

.btn-confirm--primary {
  @apply bg-blue-600 text-white hover:bg-blue-700
         focus:ring-blue-500 dark:focus:ring-offset-gray-800;
}

.btn-confirm--danger {
  @apply bg-red-600 text-white hover:bg-red-700
         focus:ring-red-500 dark:focus:ring-offset-gray-800;
}

.btn-confirm--warning {
  @apply bg-yellow-600 text-white hover:bg-yellow-700
         focus:ring-yellow-500 dark:focus:ring-offset-gray-800;
}

.btn-confirm--success {
  @apply bg-green-600 text-white hover:bg-green-700
         focus:ring-green-500 dark:focus:ring-offset-gray-800;
}

/* 动画效果 */
.dialog-fade-enter-active {
  @apply transition-all duration-200 ease-out;
}

.dialog-fade-leave-active {
  @apply transition-all duration-150 ease-in;
}

.dialog-fade-enter-from {
  @apply opacity-0;
}

.dialog-fade-enter-from .dialog-container {
  @apply transform scale-95 translate-y-4;
}

.dialog-fade-leave-to {
  @apply opacity-0;
}

.dialog-fade-leave-to .dialog-container {
  @apply transform scale-95 translate-y-4;
}

/* 响应式设计 */
@media (max-width: 640px) {
  .dialog-overlay {
    @apply p-2;
  }

  .dialog-container {
    @apply max-w-full;
  }

  .dialog-header {
    @apply p-4 pb-3;
  }

  .dialog-content {
    @apply px-4 py-3;
  }

  .dialog-footer {
    @apply px-4 py-3;
  }

  .dialog-actions {
    @apply flex-col gap-2;
  }

  .btn-cancel,
  .btn-confirm {
    @apply w-full justify-center;
  }
}

/* 无障碍访问 */
@media (prefers-reduced-motion: reduce) {
  .dialog-fade-enter-active,
  .dialog-fade-leave-active {
    @apply transition-none;
  }
}

/* 高对比度模式 */
@media (prefers-contrast: high) {
  .dialog-container {
    @apply border-2 border-gray-900 dark:border-gray-100;
  }

  .dialog-header {
    @apply border-b-2;
  }

  .dialog-footer {
    @apply border-t-2;
  }
}

/* 打印样式 */
@media print {
  .dialog-overlay {
    @apply hidden;
  }
}
</style>
