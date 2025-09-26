<script setup lang="ts">
// Props
interface Props {
  errors?: string | string[];
  variant?: 'default' | 'inline' | 'tooltip' | 'badge';
  size?: 'sm' | 'md' | 'lg';
  dismissible?: boolean;
  icon?: string;
  maxErrors?: number;
  ariaLive?: 'polite' | 'assertive' | 'off';
  dismissLabel?: string;
}

const props = withDefaults(defineProps<Props>(), {
  errors: () => [],
  variant: 'default',
  size: 'md',
  dismissible: false,
  icon: 'i-tabler-alert-circle',
  maxErrors: 3,
  ariaLive: 'polite',
  dismissLabel: '关闭错误提示',
});

// Emits
const emit = defineEmits<{
  dismiss: [];
  errorChange: [hasErrors: boolean];
}>();

// Reactive state
const dismissed = ref(false);

// Computed
const normalizedErrors = computed(() => {
  if (!props.errors)
    return [];
  return Array.isArray(props.errors) ? props.errors : [props.errors];
});

const displayErrors = computed(() => {
  const errors = normalizedErrors.value.filter(Boolean);
  return props.maxErrors > 0 ? errors.slice(0, props.maxErrors) : errors;
});

const hasErrors = computed(() => {
  return displayErrors.value.length > 0 && !dismissed.value;
});

const containerClasses = computed(() => {
  const classes = ['input-error'];

  // 变体样式
  classes.push(`input-error--${props.variant}`);

  // 尺寸样式
  classes.push(`input-error--${props.size}`);

  // 可关闭样式
  if (props.dismissible) {
    classes.push('input-error--dismissible');
  }

  return classes;
});

const iconClass = computed(() => {
  return props.icon || 'i-tabler-alert-circle';
});

// Methods
function handleDismiss() {
  dismissed.value = true;
  emit('dismiss');
}

function onEnter(el: Element) {
  const element = el as HTMLElement;
  void element.offsetHeight; // 触发重排
  element.classList.add('error-enter-active');
}

function onLeave(el: Element) {
  const element = el as HTMLElement;
  element.classList.add('error-leave-active');
}

// Watchers
watch(
  () => props.errors,
  () => {
    dismissed.value = false;
  },
  { immediate: true },
);

watch(
  hasErrors,
  newValue => {
    emit('errorChange', newValue);
  },
  { immediate: true },
);

// Expose for parent component
defineExpose({
  hasErrors,
  dismiss: handleDismiss,
  reset: () => {
    dismissed.value = false;
  },
});
</script>

<template>
  <Transition
    name="error-slide"
    appear
    @enter="onEnter"
    @leave="onLeave"
  >
    <div
      v-if="hasErrors"
      class="input-error-container"
      :class="containerClasses"
      role="alert"
      :aria-live="ariaLive"
    >
      <div class="error-content">
        <!-- 错误图标 -->
        <div class="error-icon">
          <i :class="iconClass" />
        </div>

        <!-- 错误消息 -->
        <div class="error-messages">
          <div
            v-for="(error, index) in displayErrors"
            :key="`error-${index}`"
            class="error-message"
            :class="{ 'mt-1': index > 0 }"
          >
            {{ error }}
          </div>
        </div>

        <!-- 关闭按钮 -->
        <button
          v-if="dismissible"
          class="error-dismiss"
          type="button"
          :aria-label="dismissLabel"
          @click="handleDismiss"
        >
          <i class="i-tabler-x" />
        </button>
      </div>
    </div>
  </Transition>
</template>

<style scoped lang="postcss">
/* 容器外层 */
.input-error-container {
  margin-top: 0.25rem; /* mt-1 */
}

/* 基础错误框样式 */
.input-error {
  border-left: 4px solid #F87171; /* border-red-400 */
  border-radius: 0.375rem; /* rounded-md */
  background-color: #FEE2E2; /* bg-red-50 */
  display: block;
}

.dark .input-error {
  border-color: #EF4444; /* dark:border-red-500 */
  background-color: rgba(220,38,38,0.125); /* dark:bg-red-900/20 */
}

/* 变体 padding */
.input-error--default { padding: 0.75rem; }
.input-error--inline { padding: 0.5rem 0.75rem; }
.input-error--tooltip { padding: 0.25rem 0.5rem; font-size: 0.75rem; box-shadow: 0 4px 6px rgba(0,0,0,0.1); }
.input-error--badge { display: inline-flex; align-items: center; padding: 0.25rem 0.5rem; border-radius: 9999px; font-size: 0.75rem; font-weight: 500; }

/* 尺寸 */
.input-error--sm { font-size: 0.75rem; }
.input-error--md { font-size: 0.875rem; }
.input-error--lg { font-size: 1rem; }

/* 可关闭 padding 调整 */
.input-error--dismissible { padding-right: 2rem; }

/* 内部布局 */
.error-content {
  display: flex;
  align-items: flex-start;
  gap: 0.5rem;
}

/* 图标 */
.error-icon {
  flex-shrink: 0;
  margin-top: 0.125rem;
}

.error-icon i {
  color: #EF4444; /* red-500 */
}

.dark .error-icon i {
  color: #FCA5A5; /* red-400 */
}

/* 消息内容 */
.error-messages {
  flex: 1;
  min-width: 0;
}

.error-message {
  color: #B91C1C; /* red-700 */
  font-weight: 500;
  line-height: 1.5;
}

.dark .error-message {
  color: #FCA5A5; /* red-300 */
}

/* 可关闭按钮 */
.error-dismiss {
  flex-shrink: 0;
  padding: 0.25rem;
  margin-left: auto;
  margin-right: -0.25rem;
  border-radius: 0.375rem;
  background-color: transparent;
  color: #EF4444;
  cursor: pointer;
  transition: all 0.2s;
  border: none;
}

.error-dismiss:hover {
  color: #B91C1C;
  background-color: #FEE2E2;
}

.dark .error-dismiss {
  color: #FCA5A5;
}

.dark .error-dismiss:hover {
  color: #FECACA;
  background-color: rgba(255,255,255,0.05);
}

/* focus ring */
.error-dismiss:focus {
  outline: 2px solid #EF4444;
  outline-offset: 2px;
}

.dark .error-dismiss:focus {
  outline-color: #FCA5A5;
}

/* tooltip 箭头 */
.input-error--tooltip {
  position: relative;
}

.input-error--tooltip::before {
  content: '';
  position: absolute;
  top: -0.25rem;
  left: 1rem;
  width: 0;
  height: 0;
  border-left: 0.25rem solid transparent;
  border-right: 0.25rem solid transparent;
  border-bottom: 0.25rem solid #FEE2E2;
}

.dark .input-error--tooltip::before {
  border-bottom-color: rgba(220,38,38,0.125);
}

/* badge 背景色 */
.input-error--badge {
  background-color: #FECACA; /* red-100 */
  color: #991B1B; /* red-800 */
}

.dark .input-error--badge {
  background-color: rgba(220,38,38,0.125); /* red-900/30 */
  color: #FCA5A5;
}

/* 动画效果 */
.error-slide-enter-active,
.error-slide-leave-active {
  transition: all 0.3s ease;
}

.error-slide-enter-from {
  opacity: 0;
  transform: translateY(-0.5rem) scale(0.95);
}

.error-slide-leave-to {
  opacity: 0;
  transform: translateY(-0.25rem) scale(0.98);
}

/* 响应式设计 */
@media (max-width: 640px) {
  .input-error--default { padding: 0.5rem; }
  .error-content { gap: 0.375rem; }
  .error-message { font-size: 0.75rem; }
}

/* 减少动画 */
@media (prefers-reduced-motion: reduce) {
  .error-slide-enter-active,
  .error-slide-leave-active {
    transition: none;
  }
}

/* 高对比度 */
@media (prefers-contrast: high) {
  .input-error {
    border-left-width: 8px;
    border-left-color: #B91C1C;
    background-color: #FEE2E2;
  }
  .error-message {
    color: #7F1D1D;
    font-weight: 700;
  }
}

/* 打印 */
@media print {
  .input-error {
    border-left-width: 2px;
    border-left-color: #1F2937;
    background-color: #F3F4F6;
  }
  .error-message {
    color: #111827;
  }
  .error-dismiss {
    display: none;
  }
}
</style>
