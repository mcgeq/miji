<script setup lang="ts">
const props = defineProps<{ title: string; completed: boolean }>();
const emit = defineEmits(['toggle']);

const title = computed(() => props.title);
const completed = computed(() => props.completed);

// 设置最大显示字符数
const MAX_DISPLAY_LENGTH = 30;

// 计算显示的标题（截断后）
const displayTitle = computed(() => {
  if (title.value.length <= MAX_DISPLAY_LENGTH) {
    return title.value;
  }
  return `${title.value.substring(0, MAX_DISPLAY_LENGTH)}...`;
});

// 判断是否需要显示tooltip
const shouldShowTooltip = computed(() => title.value.length > MAX_DISPLAY_LENGTH);

// 移动端长按显示完整内容
const showFullTitle = ref(false);
let longPressTimer: NodeJS.Timeout | null = null;

function handleTouchStart() {
  if (!shouldShowTooltip.value) return;

  longPressTimer = setTimeout(() => {
    showFullTitle.value = true;
  }, 500); // 500ms长按
}

function handleTouchEnd() {
  if (longPressTimer) {
    clearTimeout(longPressTimer);
    longPressTimer = null;
  }
}

function handleTouchMove() {
  if (longPressTimer) {
    clearTimeout(longPressTimer);
    longPressTimer = null;
  }
}

function hideFullTitle() {
  showFullTitle.value = false;
}

// 点击切换完成状态
function handleClick() {
  if (!showFullTitle.value) {
    emit('toggle');
  } else {
    hideFullTitle();
  }
}
</script>

<template>
  <div class="todo-title-container">
    <span
      class="todo-title"
      :class="{ 'todo-title-completed': completed }"
      :title="shouldShowTooltip ? title : undefined"
      @click="handleClick"
      @touchstart="handleTouchStart"
      @touchend="handleTouchEnd"
      @touchmove="handleTouchMove"
    >
      {{ displayTitle }}
    </span>

    <!-- 移动端全屏显示完整标题 -->
    <Teleport to="body">
      <div
        v-if="showFullTitle"
        class="full-title-overlay"
        @click="hideFullTitle"
      >
        <div class="full-title-content">
          <h3 class="full-title-text">
            {{ title }}
          </h3>
          <p class="full-title-hint">
            点击任意位置关闭
          </p>
        </div>
      </div>
    </Teleport>
  </div>
</template>

<style scoped lang="postcss">
.todo-title-container {
  position: relative;
  display: block;
}

.todo-title {
  font-size: 0.875rem;
  line-height: 1.375rem;
  text-align: left;
  display: block;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  cursor: pointer;
  color: var(--color-neutral);
  transition: color 0.2s ease;
}

.todo-title-completed {
  color: var(--color-secondary-content, #9ca3af);
}

/* 全屏显示完整标题的样式 */
.full-title-overlay {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  bottom: 0;
  background-color: rgba(0, 0, 0, 0.8);
  display: flex;
  align-items: center;
  justify-content: center;
  z-index: 9999;
  padding: 2rem;
}

.full-title-content {
  background-color: var(--color-base-100, #fff);
  border-radius: 1rem;
  padding: 2rem;
  max-width: 90%;
  max-height: 80%;
  box-shadow: 0 20px 25px -5px rgba(0, 0, 0, 0.1), 0 10px 10px -5px rgba(0, 0, 0, 0.04);
  text-align: center;
}

.full-title-text {
  font-size: 1.25rem;
  line-height: 1.75rem;
  color: var(--color-neutral);
  margin: 0 0 1rem 0;
  word-wrap: break-word;
  word-break: break-word;
}

.full-title-hint {
  font-size: 0.875rem;
  color: var(--color-neutral-content, #6b7280);
  margin: 0;
}

/* 暗色主题支持 */
@media (prefers-color-scheme: dark) {
  .full-title-content {
    background-color: var(--color-base-200, #1f2937);
  }

  .full-title-text {
    color: var(--color-neutral, #f9fafb);
  }

  .full-title-hint {
    color: var(--color-neutral-content, #9ca3af);
  }
}

/* 移动端优化 */
@media (max-width: 768px) {
  .full-title-overlay {
    padding: 1rem;
  }

  .full-title-content {
    padding: 1.5rem;
    max-width: 95%;
  }

  .full-title-text {
    font-size: 1.125rem;
    line-height: 1.5rem;
  }
}
</style>
