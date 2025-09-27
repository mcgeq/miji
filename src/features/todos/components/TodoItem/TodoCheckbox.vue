<script setup lang="ts">
import { CheckCircle, Circle } from 'lucide-vue-next';

const props = defineProps<{ completed: boolean }>();
const emit = defineEmits(['toggle']);
const completed = computed(() => props.completed);
</script>

<template>
  <button
    type="button"
    class="todo-checkbox"
    :aria-pressed="completed"
    :disabled="completed"
    @click="emit('toggle')"
  >
    <CheckCircle v-if="completed" class="icon checked" />
    <Circle v-else class="icon unchecked" />
  </button>
</template>

<style scoped lang="postcss">
.todo-checkbox {
  display: flex;
  align-items: center;
  justify-content: center;
  border: none;
  background: transparent;
  cursor: pointer;
  padding: 0.25rem;
  border-radius: 50%;
  transition: all 0.2s ease;
  outline: none;
}

/* 悬停和聚焦效果 */
.todo-checkbox:hover:not(:disabled),
.todo-checkbox:focus:not(:disabled) {
  transform: scale(1.1);
}

/* 禁用状态 */
.todo-checkbox:disabled {
  cursor: not-allowed;
  opacity: 0.6;
}

/* 图标样式 */
.icon {
  width: 1.25rem; /* wh-5 */
  height: 1.25rem;
  transition: all 0.2s ease;
}

/* 选中状态图标 */
.icon.checked {
  color: var(--color-success, #16a34a); /* 绿色，主题可覆盖 */
}

/* 未选中状态图标 */
.icon.unchecked {
  color: var(--color-neutral, #9ca3af); /* 灰色，主题可覆盖 */
}

/* Dark theme */
@media (prefers-color-scheme: dark) {
  .icon.checked {
    color: var(--color-success, #4ade80);
  }
  .icon.unchecked {
    color: var(--color-neutral, #6b7280);
  }
}
</style>
