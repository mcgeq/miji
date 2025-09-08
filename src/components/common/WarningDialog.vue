<script setup lang="ts">
// Props
interface Props {
  show: boolean;
  title?: string;
  subtitle?: string;
  message?: string;
  details?: string;
  warnings?: string[];
  severity?: 'low' | 'medium' | 'high' | 'critical';
  size?: 'sm' | 'md' | 'lg' | 'xl';
  closable?: boolean;
  loading?: boolean;
  showCancel?: boolean;
  confirmText?: string;
  cancelText?: string;
  confirmIcon?: string;
  cancelIcon?: string;
  canConfirm?: boolean;
  persistent?: boolean;
  countdown?: number;
  countdownText?: string;
  zIndex?: number;
}

const props = withDefaults(defineProps<Props>(), {
  title: '警告',
  subtitle: '',
  message: '请注意以下警告信息',
  details: '',
  warnings: () => [],
  severity: 'medium',
  size: 'md',
  closable: true,
  loading: false,
  showCancel: true,
  confirmText: '继续',
  cancelText: '取消',
  confirmIcon: '',
  cancelIcon: '',
  canConfirm: true,
  persistent: false,
  countdown: 0,
  countdownText: '',
  zIndex: 1000,
});

// Emits
const emit = defineEmits<{
  'update:show': [show: boolean];
  'confirm': [];
  'cancel': [];
  'close': [];
  'countdownEnd': [];
}>();

// Reactive state
const dialogRef = ref<HTMLDivElement>();
const titleId = ref(`warning-title-${Date.now()}`);
const contentId = ref(`warning-content-${Date.now()}`);
const previousActiveElement = ref<Element | null>(null);
const showDetails = ref(false);
const countdown = ref(0);
const initialCountdown = ref(0);
const countdownTimer = ref<NodeJS.Timeout | null>(null);

// Computed
const dialogClasses = computed(() => {
  const classes = ['warning-dialog'];

  // 尺寸样式
  classes.push(`warning-dialog--${props.size}`);

  // 严重程度样式
  classes.push(`warning-dialog--${props.severity}`);

  // 加载状态
  if (props.loading) {
    classes.push('warning-dialog--loading');
  }

  return classes;
});

const iconClasses = computed(() => {
  const classes = ['warning-icon-wrapper'];

  switch (props.severity) {
    case 'low':
      classes.push('warning-icon--low');
      break;
    case 'medium':
      classes.push('warning-icon--medium');
      break;
    case 'high':
      classes.push('warning-icon--high');
      break;
    case 'critical':
      classes.push('warning-icon--critical');
      break;
  }

  return classes;
});

const iconClass = computed(() => {
  switch (props.severity) {
    case 'low':
      return 'i-tabler-info-circle';
    case 'medium':
      return 'i-tabler-alert-triangle';
    case 'high':
      return 'i-tabler-alert-octagon';
    case 'critical':
      return 'i-tabler-shield-x';
    default:
      return 'i-tabler-alert-triangle';
  }
});

const confirmButtonClasses = computed(() => {
  const classes = ['btn-confirm'];

  switch (props.severity) {
    case 'low':
      classes.push('btn-confirm--info');
      break;
    case 'medium':
      classes.push('btn-confirm--warning');
      break;
    case 'high':
      classes.push('btn-confirm--danger');
      break;
    case 'critical':
      classes.push('btn-confirm--critical');
      break;
  }

  return classes;
});

// Methods
function handleConfirm() {
  if (props.loading || !props.canConfirm || countdown.value > 0)
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
  stopCountdown();
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

function startCountdown() {
  if (props.countdown <= 0)
    return;

  countdown.value = props.countdown;
  initialCountdown.value = props.countdown;

  countdownTimer.value = setInterval(() => {
    countdown.value--;

    if (countdown.value <= 0) {
      stopCountdown();
      emit('countdownEnd');
      handleClose();
    }
  }, 1000);
}

function stopCountdown() {
  if (countdownTimer.value) {
    clearInterval(countdownTimer.value);
    countdownTimer.value = null;
  }
  countdown.value = 0;
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

  // 开始倒计时
  startCountdown();
}

function onLeave() {
  // 恢复页面滚动
  document.body.style.overflow = '';

  // 恢复焦点
  if (previousActiveElement.value) {
    (previousActiveElement.value as HTMLElement).focus?.();
  }

  // 停止倒计时
  stopCountdown();
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

watch(
  () => props.countdown,
  newValue => {
    if (newValue > 0 && props.show) {
      startCountdown();
    }
  },
);

// Lifecycle
onMounted(() => {
  document.addEventListener('keydown', handleKeyDown);
});

onUnmounted(() => {
  document.removeEventListener('keydown', handleKeyDown);
  stopCountdown();
  // 清理样式
  document.body.style.overflow = '';
});

// Expose for parent component
defineExpose({
  focus: focusDialog,
  close: handleClose,
  stopCountdown,
  startCountdown,
});
</script>

<template>
  <Teleport to="body">
    <Transition
      name="warning-fade"
      appear
      @enter="onEnter"
      @leave="onLeave"
    >
      <div
        v-if="show"
        class="warning-overlay"
        role="alertdialog"
        aria-modal="true"
        :aria-labelledby="titleId"
        :aria-describedby="contentId"
        @click="handleOverlayClick"
      >
        <div
          ref="dialogRef"
          class="warning-container"
          :class="dialogClasses"
          tabindex="-1"
          @click.stop
          @keydown.esc="handleEscape"
        >
          <!-- 警告对话框头部 -->
          <div class="warning-header">
            <div class="warning-title-section">
              <div class="warning-icon" :class="iconClasses">
                <i :class="iconClass" class="wh-8 animate-pulse" />
              </div>
              <div class="warning-title-content">
                <h3 :id="titleId" class="warning-title">
                  {{ title }}
                </h3>
                <p v-if="subtitle" class="warning-subtitle">
                  {{ subtitle }}
                </p>
              </div>
            </div>
            <button
              v-if="closable"
              class="warning-close"
              type="button"
              :disabled="loading"
              aria-label="关闭警告对话框"
              @click="handleCancel"
            >
              <i class="i-tabler-x wh-5" />
            </button>
          </div>

          <!-- 警告对话框内容 -->
          <div :id="contentId" class="warning-content">
            <slot>
              <div class="warning-message">
                <p class="warning-text">
                  {{ message }}
                </p>

                <!-- 警告详情 -->
                <div v-if="details" class="warning-details">
                  <button
                    class="warning-details-toggle"
                    type="button"
                    @click="showDetails = !showDetails"
                  >
                    <i
                      class="i-tabler-chevron-right wh-4 transition-transform"
                      :class="{ 'rotate-90': showDetails }"
                    />
                    {{ showDetails ? '隐藏详情' : '查看详情' }}
                  </button>

                  <Transition name="details-slide">
                    <div v-if="showDetails" class="warning-details-content">
                      <div class="warning-details-text">
                        {{ details }}
                      </div>
                    </div>
                  </Transition>
                </div>

                <!-- 警告列表 -->
                <div v-if="warnings.length > 0" class="warning-list">
                  <h4 class="warning-list-title">
                    注意事项：
                  </h4>
                  <ul class="warning-list-items">
                    <li
                      v-for="(warning, index) in warnings"
                      :key="`warning-${index}`"
                      class="warning-list-item"
                    >
                      <i class="i-tabler-alert-triangle text-amber-500 flex-shrink-0 wh-4" />
                      <span>{{ warning }}</span>
                    </li>
                  </ul>
                </div>

                <!-- 倒计时 -->
                <div v-if="countdown > 0" class="warning-countdown">
                  <div class="countdown-progress">
                    <div
                      class="countdown-bar"
                      :style="{ width: `${(countdown / initialCountdown) * 100}%` }"
                    />
                  </div>
                  <p class="countdown-text">
                    {{ countdownText || `${countdown}秒后自动关闭` }}
                  </p>
                </div>
              </div>
            </slot>
          </div>

          <!-- 警告对话框底部 -->
          <div class="warning-footer">
            <div class="warning-actions">
              <button
                v-if="showCancel"
                :disabled="loading"
                class="btn-cancel"
                type="button"
                @click="handleCancel"
              >
                <i v-if="cancelIcon" :class="cancelIcon" class="mr-2 wh-4" />
                {{ cancelText }}
              </button>
              <button
                :disabled="loading || !canConfirm || countdown > 0"
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
                <span v-if="countdown > 0" class="countdown-suffix">
                  ({{ countdown }}s)
                </span>
              </button>
            </div>
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<style scoped lang="postcss">
.warning-overlay {
  @apply fixed inset-0 z-50 flex items-center justify-center p-4
         bg-black/60 backdrop-blur-sm;
}

.warning-container {
  @apply relative w-full max-h-[90vh] overflow-hidden
         bg-white dark:bg-gray-800 rounded-lg shadow-2xl
         border border-amber-200 dark:border-amber-800
         focus:outline-none;
}

.warning-dialog--sm {
  @apply max-w-sm;
}

.warning-dialog--md {
  @apply max-w-md;
}

.warning-dialog--lg {
  @apply max-w-lg;
}

.warning-dialog--xl {
  @apply max-w-xl;
}

.warning-dialog--loading {
  @apply pointer-events-none select-none;
}

.warning-dialog--low {
  @apply border-blue-200 dark:border-blue-800;
}

.warning-dialog--medium {
  @apply border-amber-200 dark:border-amber-800;
}

.warning-dialog--high {
  @apply border-orange-200 dark:border-orange-800;
}

.warning-dialog--critical {
  @apply border-red-200 dark:border-red-800;
}

.warning-header {
  @apply flex items-start justify-between p-6 pb-4
         border-b border-amber-200 dark:border-amber-800;
}

.warning-title-section {
  @apply flex items-start gap-4;
}

.warning-icon-wrapper {
  @apply flex-shrink-0 w-12 h-12 rounded-full flex items-center justify-center;
}

.warning-icon--low {
  @apply bg-blue-100 dark:bg-blue-900/30 text-blue-600 dark:text-blue-400;
}

.warning-icon--medium {
  @apply bg-amber-100 dark:bg-amber-900/30 text-amber-600 dark:text-amber-400;
}

.warning-icon--high {
  @apply bg-orange-100 dark:bg-orange-900/30 text-orange-600 dark:text-orange-400;
}

.warning-icon--critical {
  @apply bg-red-100 dark:bg-red-900/30 text-red-600 dark:text-red-400;
}

.warning-title-content {
  @apply flex-1 min-w-0;
}

.warning-title {
  @apply text-xl font-bold text-gray-900 dark:text-white mb-1;
}

.warning-subtitle {
  @apply text-sm text-gray-600 dark:text-gray-400;
}

.warning-close {
  @apply flex-shrink-0 p-2 rounded-lg
         text-gray-400 hover:text-gray-600 dark:text-gray-500 dark:hover:text-gray-300
         hover:bg-gray-100 dark:hover:bg-gray-700
         focus:outline-none focus:ring-2 focus:ring-amber-500 focus:ring-offset-2
         dark:focus:ring-offset-gray-800
         transition-colors disabled:opacity-50;
}

.warning-content {
  @apply px-6 py-4 max-h-96 overflow-y-auto;
}

.warning-message {
  @apply space-y-4;
}

.warning-text {
  @apply text-gray-700 dark:text-gray-300 leading-relaxed;
}

.warning-details {
  @apply border border-gray-200 dark:border-gray-700 rounded-lg overflow-hidden;
}

.warning-details-toggle {
  @apply w-full px-4 py-3 text-left text-sm font-medium
         text-gray-700 dark:text-gray-300 bg-gray-50 dark:bg-gray-900/50
         hover:bg-gray-100 dark:hover:bg-gray-800
         focus:outline-none focus:ring-2 focus:ring-amber-500 focus:ring-offset-2
         dark:focus:ring-offset-gray-800
         transition-colors flex items-center gap-2;
}

.warning-details-content {
  @apply px-4 py-3 border-t border-gray-200 dark:border-gray-700;
}

.warning-details-text {
  @apply text-sm text-gray-600 dark:text-gray-400 leading-relaxed;
}

.warning-list {
  @apply space-y-2;
}

.warning-list-title {
  @apply text-sm font-semibold text-gray-900 dark:text-white;
}

.warning-list-items {
  @apply space-y-2;
}

.warning-list-item {
  @apply flex items-start gap-2 text-sm text-gray-700 dark:text-gray-300;
}

.warning-countdown {
  @apply space-y-2;
}

.countdown-progress {
  @apply w-full bg-gray-200 dark:bg-gray-700 rounded-full h-2 overflow-hidden;
}

.countdown-bar {
  @apply h-full bg-amber-500 transition-all duration-1000 ease-linear;
}

.countdown-text {
  @apply text-sm text-center text-gray-600 dark:text-gray-400;
}

.warning-footer {
  @apply px-6 py-4 bg-amber-50 dark:bg-amber-900/10
         border-t border-amber-200 dark:border-amber-800;
}

.warning-actions {
  @apply flex justify-end gap-3;
}

.btn-cancel {
  @apply px-4 py-2 text-sm font-medium rounded-lg border
         border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-800
         text-gray-700 dark:text-gray-300
         hover:bg-gray-50 dark:hover:bg-gray-700
         focus:outline-none focus:ring-2 focus:ring-gray-500 focus:ring-offset-2
         dark:focus:ring-offset-gray-800
         transition-colors disabled:opacity-50 disabled:cursor-not-allowed
         flex items-center;
}

.btn-confirm {
  @apply px-4 py-2 text-sm font-medium rounded-lg border border-transparent
         focus:outline-none focus:ring-2 focus:ring-offset-2
         dark:focus:ring-offset-gray-800
         transition-colors disabled:opacity-50 disabled:cursor-not-allowed
         flex items-center;
}

.btn-confirm--info {
  @apply bg-blue-600 text-white hover:bg-blue-700 focus:ring-blue-500;
}

.btn-confirm--warning {
  @apply bg-amber-600 text-white hover:bg-amber-700 focus:ring-amber-500;
}

.btn-confirm--danger {
  @apply bg-orange-600 text-white hover:bg-orange-700 focus:ring-orange-500;
}

.btn-confirm--critical {
  @apply bg-red-600 text-white hover:bg-red-700 focus:ring-red-500;
}

.countdown-suffix {
  @apply ml-1 text-xs opacity-75;
}

/* 动画效果 */
.warning-fade-enter-active {
  @apply transition-all duration-300 ease-out;
}

.warning-fade-leave-active {
  @apply transition-all duration-200 ease-in;
}

.warning-fade-enter-from {
  @apply opacity-0;
}

.warning-fade-enter-from .warning-container {
  @apply transform scale-95 translate-y-4;
}

.warning-fade-leave-to {
  @apply opacity-0;
}

.warning-fade-leave-to .warning-container {
  @apply transform scale-95 translate-y-4;
}

.details-slide-enter-active {
  @apply transition-all duration-200 ease-out;
}

.details-slide-leave-active {
  @apply transition-all duration-150 ease-in;
}

.details-slide-enter-from {
  @apply opacity-0 transform -translate-y-2;
}

.details-slide-leave-to {
  @apply opacity-0 transform -translate-y-2;
}

/* 响应式设计 */
@media (max-width: 640px) {
  .warning-overlay {
    @apply p-2;
  }

  .warning-container {
    @apply max-w-full;
  }

  .warning-header {
    @apply p-4 pb-3;
  }

  .warning-title-section {
    @apply gap-3;
  }

  .warning-icon-wrapper {
    @apply w-10 h-10;
  }

  .warning-title {
    @apply text-lg;
  }

  .warning-content {
    @apply px-4 py-3;
  }

  .warning-footer {
    @apply px-4 py-3;
  }

  .warning-actions {
    @apply flex-col gap-2;
  }

  .btn-cancel,
  .btn-confirm {
    @apply w-full justify-center;
  }
}

/* 无障碍访问 */
@media (prefers-reduced-motion: reduce) {
  .warning-fade-enter-active,
  .warning-fade-leave-active,
  .details-slide-enter-active,
  .details-slide-leave-active {
    @apply transition-none;
  }

  .warning-icon-wrapper i {
    @apply animate-none;
  }
}

/* 高对比度模式 */
@media (prefers-contrast: high) {
  .warning-container {
    @apply border-2 border-amber-600;
  }

  .warning-header {
    @apply border-b-2;
  }

  .warning-footer {
    @apply border-t-2;
  }
}

/* 打印样式 */
@media print {
  .warning-overlay {
    @apply hidden;
  }
}
</style>
