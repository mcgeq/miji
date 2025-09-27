<script setup lang="ts">
import { Pencil, Plus, Trash2 } from 'lucide-vue-next';

const props = defineProps<{ show: boolean; completed: boolean }>();
const emit = defineEmits(['edit', 'add', 'remove']);

const show = computed(() => props.show);
const completed = computed(() => props.completed);
</script>

<template>
  <div v-if="show" class="todo-actions">
    <button
      type="button"
      :disabled="completed"
      aria-label="Edit task"
      class="action-btn edit"
      @click="emit('edit')"
    >
      <Pencil class="icon" />
      <span class="sr-only">Edit</span>
    </button>

    <button
      type="button"
      aria-label="Add task"
      class="action-btn add"
      @click="emit('add')"
    >
      <Plus class="icon" />
      <span class="sr-only">Add</span>
    </button>

    <button
      type="button"
      :disabled="completed"
      aria-label="Delete task"
      class="action-btn delete"
      @click="emit('remove')"
    >
      <Trash2 class="icon" />
      <span class="sr-only">Delete</span>
    </button>
  </div>
</template>

<style scoped lang="postcss">
.todo-actions {
  display: flex;
  gap: 0.75rem; /* 间距 */
  align-items: center;
}

/* 公共按钮样式 */
.action-btn {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  background: transparent;
  border: none;
  padding: 0.25rem;
  border-radius: 0.5rem;
  cursor: pointer;
  transition: all 0.2s ease;
  outline: none;
}

/* 悬停和聚焦 */
.action-btn:hover:not(:disabled),
.action-btn:focus:not(:disabled) {
  transform: scale(1.1);
}

/* 禁用状态 */
.action-btn:disabled {
  cursor: not-allowed;
  opacity: 0.5;
}

/* 图标通用样式 */
.icon {
  width: 1.25rem; /* wh-5 */
  height: 1.25rem;
  transition: color 0.2s ease, transform 0.2s ease;
}

/* 编辑按钮颜色 */
.action-btn.edit {
  color: var(--color-neutral, #9ca3af);
}

.action-btn.edit:hover:not(:disabled) {
  color: var(--color-primary, #2563eb);
}

/* 添加按钮颜色 */
.action-btn.add {
  color: var(--color-primary, #2563eb);
}

.action-btn.add:hover:not(:disabled) {
  color: var(--color-primary-hover, #1d4ed8);
}

/* 删除按钮颜色 */
.action-btn.delete {
  color: var(--color-error, #dc2626);
}

.action-btn.delete:hover:not(:disabled) {
  color: var(--color-error-hover, #b91c1c);
}

/* Dark theme */
@media (prefers-color-scheme: dark) {
  .action-btn.edit {
    color: var(--color-neutral, #6b7280);
  }
  .action-btn.edit:hover:not(:disabled) {
    color: var(--color-primary, #60a5fa);
  }
  .action-btn.add {
    color: var(--color-primary, #60a5fa);
  }
  .action-btn.add:hover:not(:disabled) {
    color: var(--color-primary-hover, #3b82f6);
  }
  .action-btn.delete {
    color: var(--color-error, #f87171);
  }
  .action-btn.delete:hover:not(:disabled) {
    color: var(--color-error-hover, #ef4444);
  }
}
</style>
