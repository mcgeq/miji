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
          <i :class="iconClass" class="wh-4 flex-shrink-0" />
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
          <i class="wh-3 i-tabler-x" />
        </button>
      </div>
    </div>
  </Transition>
</template>

<style scoped lang="postcss">
.input-error-container {
  @apply mt-1;
}

.input-error {
  @apply rounded-md border-l-4 border-red-400 bg-red-50 dark:bg-red-900/20
         dark:border-red-500;
}

.input-error--default {
  @apply p-3;
}

.input-error--inline {
  @apply py-2 px-3;
}

.input-error--tooltip {
  @apply py-1 px-2 text-xs shadow-lg;
}

.input-error--badge {
  @apply inline-flex items-center px-2 py-1 rounded-full text-xs font-medium;
}

.input-error--sm {
  @apply text-xs;
}

.input-error--md {
  @apply text-sm;
}

.input-error--lg {
  @apply text-base;
}

.input-error--dismissible {
  @apply pr-8;
}

.error-content {
  @apply flex items-start gap-2;
}

.error-icon {
  @apply flex-shrink-0 mt-0.5;
}

.error-icon i {
  @apply text-red-500 dark:text-red-400;
}

.error-messages {
  @apply flex-1 min-w-0;
}

.error-message {
  @apply text-red-700 dark:text-red-300 font-medium leading-relaxed;
}

.error-dismiss {
  @apply flex-shrink-0 p-1 ml-auto -mr-1 rounded-md
         text-red-500 hover:text-red-700 dark:text-red-400 dark:hover:text-red-300
         hover:bg-red-100 dark:hover:bg-red-800/30
         focus:outline-none focus:ring-2 focus:ring-red-500 focus:ring-offset-2
         dark:focus:ring-offset-red-900
         transition-colors;
}

/* 变体特定样式 */
.input-error--tooltip {
  @apply relative;
}

.input-error--tooltip::before {
  @apply content-[''] absolute -top-1 left-4 w-0 h-0
         border-l-4 border-r-4 border-b-4 border-transparent border-b-red-50
         dark:border-b-red-900;
}

.input-error--badge {
  @apply bg-red-100 text-red-800 dark:bg-red-900/30 dark:text-red-300;
}

/* 动画效果 */
.error-slide-enter-active {
  @apply transition-all duration-300 ease-out;
}

.error-slide-leave-active {
  @apply transition-all duration-200 ease-in;
}

.error-slide-enter-from {
  @apply opacity-0 transform -translate-y-2 scale-95;
}

.error-slide-leave-to {
  @apply opacity-0 transform -translate-y-1 scale-98;
}

.error-enter-active {
  @apply animate-pulse;
}

.error-leave-active {
  @apply animate-pulse;
}

/* 响应式设计 */
@media (max-width: 640px) {
  .input-error--default {
    @apply p-2;
  }

  .error-content {
    @apply gap-1.5;
  }

  .error-message {
    @apply text-xs;
  }
}

/* 无障碍访问 */
@media (prefers-reduced-motion: reduce) {
  .error-slide-enter-active,
  .error-slide-leave-active {
    @apply transition-none;
  }

  .error-enter-active,
  .error-leave-active {
    @apply animate-none;
  }
}

/* 高对比度模式 */
@media (prefers-contrast: high) {
  .input-error {
    @apply border-l-8 border-red-600 bg-red-100 dark:bg-red-800;
  }

  .error-message {
    @apply text-red-900 dark:text-red-100 font-bold;
  }
}

/* 打印样式 */
@media print {
  .input-error {
    @apply border-l-2 border-gray-800 bg-gray-100;
  }

  .error-message {
    @apply text-gray-900;
  }

  .error-dismiss {
    @apply hidden;
  }
}
</style>
