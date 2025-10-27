<script setup lang="ts">
import { AlertTriangle, Check, CheckCircle, Info, X, XCircle } from 'lucide-vue-next';

interface Props {
  visible?: boolean;
  title?: string;
  message: string;
  type?: 'info' | 'warning' | 'error' | 'success' | 'danger';
  confirmText?: string;
  cancelText?: string;
  confirmButtonType?: 'primary' | 'danger' | 'warning' | 'success';
  showCancel?: boolean;
  loading?: boolean;
  size?: 'sm' | 'md' | 'lg' | 'xl';
  closable?: boolean;
  confirmIcon?: string;
  canConfirm?: boolean;
  persistent?: boolean;
  zIndex?: number;
}

interface Emits {
  'confirm': [];
  'cancel': [];
  'close': [];
  'update:visible': [visible: boolean];
}

const props = withDefaults(defineProps<Props>(), {
  visible: false,
  title: '',
  type: 'warning',
  confirmText: '确定',
  cancelText: '取消',
  confirmButtonType: 'primary',
  showCancel: true,
  loading: false,
  size: 'md',
  closable: true,
  confirmIcon: '',
  canConfirm: true,
  persistent: false,
  zIndex: 1000,
});

const emit = defineEmits<Emits>();
const dialogRef = ref<HTMLDivElement>();
const titleId = ref(`modal-title-${Date.now()}`);
const contentId = ref(`modal-content-${Date.now()}`);
const previousActiveElement = ref<Element | null>(null);

const iconMap = { info: Info, warning: AlertTriangle, error: XCircle, danger: XCircle, success: CheckCircle };
const iconColorMap = { info: 'modal-icon-info', warning: 'modal-icon-warning', error: 'modal-icon-error', danger: 'modal-icon-error', success: 'modal-icon-success' };
const confirmButtonStyleMap = { primary: 'btn-primary', danger: 'btn-danger', warning: 'btn-warning', success: 'btn-success' };

const IconComponent = computed(() => iconMap[props.type]);
const iconColor = computed(() => iconColorMap[props.type]);
const confirmButtonStyle = computed(() => confirmButtonStyleMap[props.confirmButtonType]);

const modalClasses = computed(() => {
  const classes = ['modal-dialog'];
  switch (props.size) {
    case 'sm': classes.push('modal-sm');
      break;
    case 'lg': classes.push('modal-lg');
      break;
    case 'xl': classes.push('modal-xl');
      break;
    default: classes.push('modal-md');
  }
  if (props.loading) classes.push('modal-loading');
  return classes;
});

const overlayClasses = computed(() => ['modal-overlay', `z-${props.zIndex}`]);

function handleConfirm() {
  if (!props.loading && props.canConfirm)
    emit('confirm');
}
function handleCancel() {
  if (!props.loading) {
    emit('cancel');
    handleClose();
  }
}
function handleClose() {
  emit('update:visible', false);
  emit('close');
}
function handleOverlayClick(event: Event) {
  if (!props.persistent && !props.loading && event.target === event.currentTarget)
    handleCancel();
}
function handleEscape(event: KeyboardEvent) {
  if (!props.persistent && !props.loading) {
    event.preventDefault();
    handleCancel();
  }
}
async function focusModal() {
  await nextTick();
  dialogRef.value?.focus();
}

function handleKeyDown(event: KeyboardEvent) {
  if (!props.visible) return;
  if (event.key === 'Escape') return handleEscape(event);
  if (event.key === 'Tab' && dialogRef.value) {
    const focusableElements = dialogRef.value.querySelectorAll('button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])');
    const first = focusableElements[0] as HTMLElement;
    const last = focusableElements[focusableElements.length - 1] as HTMLElement;
    if (event.shiftKey && document.activeElement === first) {
      event.preventDefault();
      last.focus();
    }
    if (!event.shiftKey && document.activeElement === last) {
      event.preventDefault();
      first.focus();
    }
  }
}

async function onEnter() {
  previousActiveElement.value = document.activeElement;
  const scrollY = window.scrollY;
  document.body.style.overflow = 'hidden';
  document.body.style.position = 'fixed';
  document.body.style.top = `-${scrollY}px`;
  document.body.style.width = '100%';
  await focusModal();
}

function onLeave() {
  const scrollY = document.body.style.top;
  document.body.style.overflow = '';
  document.body.style.position = '';
  document.body.style.top = '';
  document.body.style.width = '';
  if (scrollY) window.scrollTo(0, Number.parseInt(scrollY || '0') * -1);
  previousActiveElement.value && (previousActiveElement.value as HTMLElement).focus?.();
}

watch(() => props.visible, async newValue => {
  if (newValue) await focusModal();
});
onMounted(() => document.addEventListener('keydown', handleKeyDown));
onUnmounted(() => {
  document.removeEventListener('keydown', handleKeyDown);
  document.body.style.cssText = '';
});

defineExpose({ focus: focusModal, close: handleClose });
</script>

<template>
  <Teleport to="body">
    <Transition
      name="modal"
      appear
      @enter="onEnter"
      @leave="onLeave"
    >
      <div
        v-if="visible"
        :class="overlayClasses"
        role="dialog"
        aria-modal="true"
        :aria-labelledby="titleId"
        :aria-describedby="contentId"
        @click="handleOverlayClick"
      >
        <div ref="dialogRef" :class="modalClasses" tabindex="-1" @click.stop>
          <!-- 头部 -->
          <div class="modal-header">
            <div class="modal-title-container">
              <component :is="IconComponent" :class="iconColor" class="modal-icon" />
              <div class="modal-text">
                <h3 v-if="title" :id="titleId" class="modal-title">
                  {{ title }}
                </h3>
                <div :id="contentId" class="modal-content">
                  <slot>
                    <p>
                      {{ message }}
                    </p>
                  </slot>
                </div>
              </div>
            </div>
            <button v-if="closable" class="modal-close" :disabled="loading" aria-label="关闭对话框" @click="handleCancel">
              <X />
            </button>
          </div>
          <!-- 按钮区域 -->
          <div class="modal-footer">
            <button v-if="showCancel" class="btn-cancel btn-icon-only" :disabled="loading" :title="cancelText" @click="handleCancel">
              <X class="icon" />
            </button>
            <button
              type="button"
              class="btn-confirm btn-icon-only"
              :class="[confirmButtonStyle]"
              :disabled="loading || !canConfirm"
              :title="confirmText"
              @click="handleConfirm"
            >
              <div v-if="loading" class="btn-spinner" />
              <Check v-else class="icon" />
            </button>
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<style scoped lang="postcss">
/* Overlay */
.modal-overlay {
  position: fixed;
  inset: 0;
  display: flex;
  align-items: center;
  justify-content: center;
  background: rgba(0, 0, 0, 0.5);
  backdrop-filter: blur(4px);
  padding: 1rem;
}

/* Modal Dialog */
.modal-dialog {
  background: var(--color-base-100);
  border-radius: 0.75rem;
  box-shadow: 0 10px 25px rgba(0,0,0,0.2);
  transform: scale(1);
  transition: all 0.3s ease-out;
  max-width: 28rem;
  width: 100%;
  outline: none;
}

/* Sizes */
.modal-sm { max-width: 20rem; }
.modal-md { max-width: 28rem; }
.modal-lg { max-width: 36rem; }
.modal-xl { max-width: 48rem; }

/* Header */
.modal-header {
  padding: 1.5rem 1.5rem 1rem;
  border-bottom: 1px solid var(--color-base-300);
  display: flex;
  justify-content: space-between;
  align-items: start;
}
.modal-title-container {
  display: flex;
  gap: 0.75rem;
  align-items: center;
}
.modal-icon {
  flex-shrink: 0;
  width: 1.5rem;
  height: 1.5rem;
}
.modal-text {
  flex: 1;
}
.modal-title {
  font-size: 1.125rem;
  font-weight: 600;
  color: var(--color-base-content);
  margin: 0;
}

/* Footer */
.btn-cancel {
  background: var(--color-base-100);
  border: 1px solid var(--color-base-300);
  padding: 0.5rem 1rem;
  border-radius: 0.375rem;
  cursor: pointer;
  color: var(--color-base-content);
  transition: all 0.2s ease;
}
.btn-cancel:hover {
  background: var(--color-base-200);
  border-color: var(--color-base-400);
}

/* 圆形图标按钮 */
.btn-icon-only {
  width: 3rem !important;
  height: 3rem !important;
  padding: 0 !important;
  border-radius: 50% !important;
  display: flex !important;
  align-items: center !important;
  justify-content: center !important;
  border: 1px solid transparent;
  min-width: 3rem;
  min-height: 3rem;
}

.btn-icon-only .icon {
  width: 1.25rem;
  height: 1.25rem;
}

/* 取消按钮圆形样式 */
.btn-cancel.btn-icon-only {
  background: var(--color-base-100);
  border-color: var(--color-base-300);
  color: var(--color-base-content);
}

.btn-cancel.btn-icon-only:hover:not(:disabled) {
  background: var(--color-base-200);
  border-color: var(--color-base-400);
  transform: scale(1.05);
}

/* 确认按钮圆形样式 */
.btn-confirm.btn-icon-only {
  color: var(--color-primary-content);
  min-width: 3rem !important;
  min-height: 3rem !important;
}

.btn-confirm.btn-icon-only:hover:not(:disabled) {
  transform: scale(1.05);
}

/* 圆形按钮禁用状态 */
.btn-icon-only:disabled {
  opacity: 0.5;
  cursor: not-allowed;
  transform: none !important;
}

.btn-confirm {
  padding: 0.5rem 1rem;
  border-radius: 0.375rem;
  display: flex;
  align-items: center;
  gap: 0.25rem;
  color: var(--color-base-content);
  cursor: pointer;
  transition: all 0.2s ease;
}

.btn-primary {
  background: var(--color-primary);
  color: var(--color-primary-content);
}
.btn-primary:hover {
  background: var(--color-primary-hover);
}
.btn-danger {
  background: var(--color-error);
  color: var(--color-error-content);
}
.btn-danger:hover {
  background: var(--color-error-hover);
}
.btn-warning {
  background: var(--color-warning);
  color: var(--color-warning-content);
}
.btn-warning:hover {
  background: var(--color-warning-hover);
}
.btn-success {
  background: var(--color-success);
  color: var(--color-success-content);
}
.btn-success:hover {
  background: var(--color-success-hover);
}

/* Icon colors */
.modal-icon-info { color: var(--color-info); }
.modal-icon-warning { color: var(--color-warning); }
.modal-icon-error { color: var(--color-error); }
.modal-icon-success { color: var(--color-success); }

/* Close button */
.modal-close {
  background: none;
  border: none;
  cursor: pointer;
  padding: 0.5rem;
  color: var(--color-base-content);
  transition: color 0.2s ease;
}
.modal-close:hover {
  color: var(--color-base-content-soft);
}

/* Loading spinner */
.btn-spinner {
  border: 2px solid currentColor;
  border-top-color: transparent;
  border-radius: 50%;
  width: 1rem;
  height: 1rem;
  animation: spin 1s linear infinite;
}
@keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }

/* Responsive */
@media (max-width: 640px) {
  .modal-overlay { padding: 0.5rem; }
  .modal-sm, .modal-md, .modal-lg, .modal-xl { max-width: 100%; }
  .modal-footer {
    flex-direction: row;
    gap: 0.5rem;
    justify-content: flex-end;
  }
  /* 圆形按钮在移动端保持圆形 */
  .modal-footer button.btn-icon-only {
    width: 2.75rem !important;
    height: 2.75rem !important;
    min-width: 2.75rem !important;
    min-height: 2.75rem !important;
  }
  .modal-footer button.btn-icon-only .icon {
    width: 1.125rem;
    height: 1.125rem;
  }
}

/* Animations */
.modal-enter-from { opacity: 0; transform: scale(0.95) translateY(1rem); }
.modal-leave-to { opacity: 0; transform: scale(0.95) translateY(1rem); }
</style>
