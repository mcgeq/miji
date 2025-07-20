<script setup lang="ts">
import { AlertTriangle, CheckCircle, Info, X, XCircle } from 'lucide-vue-next';

interface Props {
  visible?: boolean;
  title?: string;
  message: string;
  type?: 'info' | 'warning' | 'error' | 'success' | 'danger'; // 兼容两种命名
  confirmText?: string;
  cancelText?: string;
  confirmButtonType?: 'primary' | 'danger' | 'warning' | 'success';
  showCancel?: boolean;
  loading?: boolean;
  // 新增属性 - 兼容 ConfirmDialog.vue 的功能
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
  // 新增默认值
  size: 'md',
  closable: true,
  confirmIcon: '',
  canConfirm: true,
  persistent: false,
  zIndex: 1000,
});

const emit = defineEmits<Emits>();

// 响应式状态
const dialogRef = ref<HTMLDivElement>();
const titleId = ref(`modal-title-${Date.now()}`);
const contentId = ref(`modal-content-${Date.now()}`);
const previousActiveElement = ref<Element | null>(null);

// 图标映射 - 兼容 danger 和 error
const iconMap = {
  info: Info,
  warning: AlertTriangle,
  error: XCircle,
  danger: XCircle, // danger 和 error 使用相同图标
  success: CheckCircle,
};

// 图标颜色映射 - 兼容 danger 和 error
const iconColorMap = {
  info: 'text-blue-500',
  warning: 'text-orange-500',
  error: 'text-red-500',
  danger: 'text-red-500', // danger 和 error 使用相同颜色
  success: 'text-green-500',
};

// 确认按钮样式映射
const confirmButtonStyleMap = {
  primary: 'bg-blue-600 hover:bg-blue-700 focus:ring-blue-500',
  danger: 'bg-red-600 hover:bg-red-700 focus:ring-red-500',
  warning: 'bg-orange-600 hover:bg-orange-700 focus:ring-orange-500',
  success: 'bg-green-600 hover:bg-green-700 focus:ring-green-500',
};

// 计算属性
const IconComponent = computed(() => iconMap[props.type]);
const iconColor = computed(() => iconColorMap[props.type]);
const confirmButtonStyle = computed(() => confirmButtonStyleMap[props.confirmButtonType]);

const modalClasses = computed(() => {
  const classes = ['relative transform rounded-lg bg-white dark:bg-gray-800 shadow-xl transition-all duration-300 ease-out'];

  // 尺寸样式
  switch (props.size) {
    case 'sm':
      classes.push('max-w-sm w-full');
      break;
    case 'lg':
      classes.push('max-w-lg w-full');
      break;
    case 'xl':
      classes.push('max-w-xl w-full');
      break;
    default:
      classes.push('max-w-md w-full');
  }

  // 加载状态
  if (props.loading) {
    classes.push('pointer-events-none select-none');
  }

  return classes;
});

const overlayClasses = computed(() => {
  return [
    'fixed inset-0 flex items-center justify-center bg-black bg-opacity-50 backdrop-blur-sm p-4',
    `z-${props.zIndex}`,
  ];
});

// 方法
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
  emit('update:visible', false);
  emit('close');
}

function handleOverlayClick(event: Event) {
  if (props.persistent || props.loading)
    return;
  if (event.target === event.currentTarget) {
    handleCancel();
  }
}

function handleEscape(event: KeyboardEvent) {
  if (props.persistent || props.loading)
    return;
  event.preventDefault();
  handleCancel();
}

async function focusModal() {
  await nextTick();
  if (dialogRef.value) {
    dialogRef.value.focus();
  }
}

// 键盘导航处理
function handleKeyDown(event: KeyboardEvent) {
  if (!props.visible)
    return;

  // ESC 键处理
  if (event.key === 'Escape') {
    handleEscape(event);
    return;
  }

  // Tab 键焦点陷阱
  if (event.key === 'Tab' && dialogRef.value) {
    const focusableElements = dialogRef.value.querySelectorAll(
      'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])',
    );

    const firstElement = focusableElements[0] as HTMLElement;
    const lastElement = focusableElements[focusableElements.length - 1] as HTMLElement;

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

// 进入动画处理
async function onEnter() {
  // 保存当前焦点元素
  previousActiveElement.value = document.activeElement;

  // 防止背景滚动
  const scrollY = window.scrollY;
  document.body.style.overflow = 'hidden';
  document.body.style.position = 'fixed';
  document.body.style.top = `-${scrollY}px`;
  document.body.style.width = '100%';

  // 设置焦点
  await focusModal();
}

// 离开动画处理
function onLeave() {
  // 恢复背景滚动
  const scrollY = document.body.style.top;
  document.body.style.overflow = '';
  document.body.style.position = '';
  document.body.style.top = '';
  document.body.style.width = '';
  if (scrollY) {
    window.scrollTo(0, Number.parseInt(scrollY || '0') * -1);
  }

  // 恢复焦点
  if (previousActiveElement.value) {
    (previousActiveElement.value as HTMLElement).focus?.();
  }
}

// 监听器
watch(
  () => props.visible,
  async newValue => {
    if (newValue) {
      await focusModal();
    }
  },
);

// 生命周期
onMounted(() => {
  document.addEventListener('keydown', handleKeyDown);
});

onUnmounted(() => {
  document.removeEventListener('keydown', handleKeyDown);
  // 清理样式
  document.body.style.overflow = '';
  document.body.style.position = '';
  document.body.style.top = '';
  document.body.style.width = '';
});

// 暴露方法给父组件
defineExpose({
  focus: focusModal,
  close: handleClose,
});
</script>

<template>
  <Teleport to="body">
    <Transition
      name="modal"
      appear
      enter-active-class="transition-all duration-300 ease-out"
      enter-from-class="opacity-0"
      enter-to-class="opacity-100"
      leave-active-class="transition-all duration-200 ease-in"
      leave-from-class="opacity-100"
      leave-to-class="opacity-0"
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
        <div
          ref="dialogRef"
          :class="modalClasses"
          class="focus:outline-none"
          tabindex="-1"
          @click.stop
          @keydown.esc="handleEscape"
        >
          <!-- 头部 -->
          <div class="flex items-start justify-between border-b border-gray-200 p-6 pb-4 dark:border-gray-700">
            <div class="flex flex-1 items-center gap-3">
              <component
                :is="IconComponent"
                :class="iconColor"
                class="h-6 w-6 flex-shrink-0"
              />
              <div class="flex-1">
                <h3
                  v-if="title"
                  :id="titleId"
                  class="text-lg text-gray-900 font-semibold dark:text-white"
                >
                  {{ title }}
                </h3>
                <div :id="contentId" class="max-h-96 overflow-y-auto">
                  <slot>
                    <p
                      class="text-gray-700 leading-relaxed dark:text-gray-300"
                      :class="{ 'mt-1': title }"
                    >
                      {{ message }}
                    </p>
                  </slot>
                </div>
              </div>
            </div>

            <!-- 关闭按钮 -->
            <button
              v-if="closable"
              type="button"
              class="flex-shrink-0 rounded-lg p-2 text-gray-400 transition-colors hover:bg-gray-100 dark:text-gray-500 hover:text-gray-600 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-gray-500 dark:hover:bg-gray-700 dark:hover:text-gray-300 dark:focus:ring-offset-gray-800"
              :disabled="loading"
              aria-label="关闭对话框"
              @click="handleCancel"
            >
              <X class="h-5 w-5" />
            </button>
          </div>

          <!-- 按钮区域 -->
          <div class="flex justify-end gap-3 bg-gray-50 px-6 pb-6 pt-4 dark:bg-gray-900/50">
            <button
              v-if="showCancel"
              type="button"
              class="border border-gray-300 rounded-md bg-white px-4 py-2 text-sm text-gray-700 font-medium transition-colors disabled:cursor-not-allowed dark:border-gray-600 dark:bg-gray-800 hover:bg-gray-50 dark:text-gray-300 disabled:opacity-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-gray-500 dark:hover:bg-gray-700 dark:focus:ring-offset-gray-800"
              :disabled="loading"
              @click="handleCancel"
            >
              {{ cancelText }}
            </button>
            <button
              type="button"
              :class="confirmButtonStyle"
              class="flex items-center gap-2 rounded-md px-4 py-2 text-sm text-white font-medium transition-colors disabled:cursor-not-allowed disabled:opacity-50 focus:outline-none focus:ring-2 focus:ring-offset-2 dark:focus:ring-offset-gray-800"
              :disabled="loading || !canConfirm"
              @click="handleConfirm"
            >
              <div
                v-if="loading"
                class="h-4 w-4 animate-spin border-2 border-white border-t-transparent rounded-full"
              />
              <component
                :is="confirmIcon"
                v-else-if="confirmIcon"
                class="h-4 w-4"
              />
              {{ confirmText }}
            </button>
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<style scoped lang="postcss">
/* 响应式设计 */
@media (max-width: 640px) {
  .fixed {
    @apply p-2;
  }

  .max-w-sm, .max-w-md, .max-w-lg, .max-w-xl {
    @apply max-w-full;
  }

  .flex.justify-end.gap-3 {
    @apply flex-col gap-2;
  }

  .flex.justify-end.gap-3 button {
    @apply w-full justify-center;
  }
}

/* 无障碍访问 */
@media (prefers-reduced-motion: reduce) {
  .transition-all {
    @apply transition-none;
  }
}

/* 高对比度模式 */
@media (prefers-contrast: high) {
  .rounded-lg {
    @apply border-2 border-gray-900 dark:border-gray-100;
  }
}

/* 打印样式 */
@media print {
  .fixed {
    @apply hidden;
  }
}

/* 动画增强 */
.modal-enter-from .rounded-lg {
  @apply transform scale-95 translate-y-4;
}

.modal-leave-to .rounded-lg {
  @apply transform scale-95 translate-y-4;
}
</style>
