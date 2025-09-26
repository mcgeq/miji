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
              <div class="warning-icon-wrapper" :class="iconClasses">
                <i :class="iconClass" />
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
              <i class="icon-close" />
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
                      class="icon-chevron"
                      :class="{ rotate: showDetails }"
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
                      <i class="icon-alert" />
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
                <i v-if="cancelIcon" :class="cancelIcon" />
                {{ cancelText }}
              </button>
              <button
                :disabled="loading || !canConfirm || countdown > 0"
                class="btn-confirm"
                :class="confirmButtonClasses"
                type="button"
                @click="handleConfirm"
              >
                <i v-if="loading" class="icon-loading" />
                <i v-else-if="confirmIcon" :class="confirmIcon" />
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
/* ------------------- Overlay ------------------- */
.warning-overlay {
  position: fixed;
  inset: 0;
  z-index: 50;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 1rem;
  background-color: rgba(0, 0, 0, 0.6);
  backdrop-filter: blur(4px);
}

/* ------------------- Container ------------------- */
.warning-container {
  position: relative;
  width: 100%;
  max-height: 90vh;
  overflow: hidden;
  background-color: var(--color-base-100);
  color: var(--color-base-content);
  border-radius: 0.75rem;
  border: 1px solid var(--color-accent);
  box-shadow: 0 10px 25px rgba(0, 0, 0, 0.2);
  outline: none;
  transition: background 0.3s ease, border-color 0.3s ease;
}

/* ------------------- Header ------------------- */
.warning-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  padding: 1.5rem 1.5rem 1rem;
  border-bottom: 1px solid var(--color-accent);
}

.warning-title-section {
  display: flex;
  align-items: flex-start;
  gap: 1rem;
}

.warning-icon-wrapper {
  flex-shrink: 0;
  width: 3rem;
  height: 3rem;
  border-radius: 9999px;
  display: flex;
  align-items: center;
  justify-content: center;
  animation: pulse 2s infinite;
}

/* Icon 渐变背景 */
.warning-icon--low {
  background: linear-gradient(135deg, #dbeafe, #93c5fd);
  color: #1d4ed8;
}
.warning-icon--medium {
  background: linear-gradient(135deg, #fef3c7, #fcd34d);
  color: #b45309;
}
.warning-icon--high {
  background: linear-gradient(135deg, #ffedd5, #fb923c);
  color: #9a3412;
}
.warning-icon--critical {
  background: linear-gradient(135deg, #fee2e2, #f87171);
  color: #b91c1c;
}

.warning-title-content { flex: 1; min-width: 0; }
.warning-title { font-size: 1.25rem; font-weight: 700; margin-bottom: 0.25rem; }
.warning-subtitle { font-size: 0.875rem; color: var(--color-neutral-content); }

/* ------------------- Content ------------------- */
.warning-content {
  padding: 1rem 1.5rem;
  max-height: 24rem;
  overflow-y: auto;
}

.warning-message { display: flex; flex-direction: column; gap: 1rem; }
.warning-text { line-height: 1.5; color: var(--color-base-content); }

/* Countdown 进度条渐变 */
.warning-countdown { display: flex; flex-direction: column; gap: 0.5rem; }
.countdown-progress {
  width: 100%;
  height: 0.5rem;
  background-color: var(--color-base-300);
  border-radius: 9999px;
  overflow: hidden;
}
.countdown-bar {
  height: 100%;
  background: linear-gradient(90deg, #fbbf24, #f59e0b, #d97706);
  transition: width 1s linear;
}
.countdown-text {
  text-align: center;
  font-size: 0.875rem;
  color: var(--color-neutral-content);
}

/* ------------------- Footer ------------------- */
.warning-footer {
  padding: 1rem 1.5rem;
  background-color: rgba(251, 191, 36, 0.1);
  border-top: 1px solid var(--color-accent);
}

.warning-actions { display: flex; justify-content: flex-end; gap: 0.75rem; }

/* 按钮基础样式 */
.btn-cancel,
.btn-confirm {
  padding: 0.5rem 1rem;
  font-size: 0.875rem;
  font-weight: 500;
  border-radius: 0.75rem;
  cursor: pointer;
  transition: all 0.3s ease;
  display: flex;
  align-items: center;
}
.btn-cancel {
  border: 1px solid var(--color-base-300);
  background: linear-gradient(145deg, var(--color-base-100), var(--color-base-200));
  color: var(--color-base-content);
}
.btn-cancel:hover {
  background: linear-gradient(145deg, var(--color-base-200), var(--color-base-300));
}
.btn-cancel:disabled { opacity: 0.5; cursor: not-allowed; }

/* Confirm 渐变按钮 */
.btn-confirm {
  border: none;
  color: #fff;
  box-shadow: 0 4px 10px rgba(0,0,0,0.15);
}
.btn-confirm--info {
  background: linear-gradient(135deg, #3b82f6, #2563eb);
}
.btn-confirm--info:hover {
  background: linear-gradient(135deg, #2563eb, #1d4ed8);
}
.btn-confirm--warning {
  background: linear-gradient(135deg, #fbbf24, #f59e0b);
}
.btn-confirm--warning:hover {
  background: linear-gradient(135deg, #f59e0b, #d97706);
}
.btn-confirm--danger {
  background: linear-gradient(135deg, #fb923c, #f97316);
}
.btn-confirm--danger:hover {
  background: linear-gradient(135deg, #f97316, #ea580c);
}
.btn-confirm--critical {
  background: linear-gradient(135deg, #ef4444, #dc2626);
}
.btn-confirm--critical:hover {
  background: linear-gradient(135deg, #dc2626, #b91c1c);
}

.countdown-suffix {
  margin-left: 0.25rem;
  font-size: 0.75rem;
  opacity: 0.75;
}

/* ------------------- Animations ------------------- */
@keyframes pulse {
  0%, 100% { transform: scale(1); opacity: 1; }
  50% { transform: scale(1.05); opacity: 0.85; }
}

.warning-fade-enter-active,
.warning-fade-leave-active {
  transition: opacity 0.3s ease, transform 0.3s ease;
}
.warning-fade-enter-from,
.warning-fade-leave-to {
  opacity: 0;
  transform: scale(0.95) translateY(1rem);
}
</style>
