<script setup lang="ts">
const props = defineProps<{ title: string; show: boolean }>();
const emit = defineEmits(['save', 'close']);
const show = computed(() => props.show);
const localTitle = ref(props.title);
const isEditable = computed(
  () => localTitle.value.trim() === props.title.trim(),
);
</script>

<template>
  <transition name="fade">
    <div
      v-if="show"
      class="modal-overlay"
      @click="emit('close')"
    >
      <transition name="scale">
        <div
          v-if="show"
          class="modal-mask-window-money"
          @click.stop
        >
          <input
            v-model="localTitle"
            class="modal-input"
            placeholder="输入任务标题"
          >
          <div class="modal-actions">
            <button class="btn-cancel" @click="emit('close')">
              <LucideX class="icon" />
            </button>
            <button
              class="btn-save"
              :class="{ 'btn-disabled': isEditable }"
              :disabled="isEditable"
              @click="emit('save', localTitle)"
            >
              <LucideCheck class="icon" />
            </button>
          </div>
        </div>
      </transition>
    </div>
  </transition>
</template>

<style scoped lang="postcss">
/* Overlay 背景 */
.modal-overlay {
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

/* 弹窗内容 */
.modal-content {
  width: 24rem; /* w-96 */
  padding: 1.5rem; /* p-6 */
  border-radius: 1.25rem; /* rounded-2xl */
  border: 1px solid rgba(255, 255, 255, 0.2);
  background-color: rgba(255, 255, 255, 0.7);
  display: flex;
  flex-direction: column;
  gap: 1.25rem;
  box-shadow: 0 10px 20px rgba(0,0,0,0.15);
  backdrop-filter: blur(12px);
  transition: background-color 0.2s ease, border-color 0.2s ease;
}

/* 输入框 */
.modal-input {
  width: 100%;
  padding: 0.75rem; /* p-3 */
  border-radius: 1rem; /* rounded-xl */
  border: 1px solid var(--color-neutral, #e5e7eb);
  font-size: 1rem;
  color: var(--color-base-content, #111827);
  background-color: var(--color-base-100, #fff);
  transition: border-color 0.2s ease, box-shadow 0.2s ease;
}

.modal-input:focus {
  outline: none;
  border-color: var(--color-primary, #2563eb);
  box-shadow: 0 0 0 3px rgba(59, 130, 246, 0.3);
}

/* 动作按钮容器 */
.modal-actions {
  display: flex;
  gap: 1rem;
  justify-content: center;
  margin-top: 1.25rem; /* mt-5 */
}

/* 取消按钮 */
.btn-cancel {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  padding: 0.5rem 1.25rem;
  border-radius: 1rem;
  background-color: var(--color-neutral, #f3f4f6);
  color: var(--color-base-content, #374151);
  font-size: 0.875rem;
  font-weight: 500;
  border: none;
  cursor: pointer;
  transition: background-color 0.2s ease, transform 0.2s ease;
}

.btn-cancel:hover {
  background-color: var(--color-base-200, #e5e7eb);
  transform: scale(1.05);
}

.btn-cancel:active {
  transform: scale(0.95);
}

/* 保存按钮 */
.btn-save {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  padding: 0.5rem 1.25rem;
  border-radius: 1rem;
  background-color: var(--color-primary, #2563eb);
  color: var(--color-primary-content, #fff);
  font-size: 0.875rem;
  font-weight: 500;
  border: none;
  cursor: pointer;
  transition: background-color 0.2s ease, transform 0.2s ease;
}

.btn-save:hover:not(:disabled) {
  background-color: #1e40af; /* hover 深色 */
  transform: scale(1.05);
}

.btn-save:active:not(:disabled) {
  transform: scale(0.95);
}

/* 禁用状态 */
.btn-disabled {
  background-color: var(--color-neutral, #9ca3af);
  cursor: not-allowed;
  pointer-events: none;
}

/* 图标大小 */
.icon {
  width: 1.25rem; /* wh-5 */
  height: 1.25rem;
}

/* Fade 动画 */
.fade-enter-active, .fade-leave-active {
  transition: opacity 0.25s ease-out, transform 0.25s ease-out;
}
.fade-enter-from, .fade-leave-to {
  opacity: 0;
  transform: translateY(8px);
}

/* Scale 动画 */
.scale-enter-active, .scale-leave-active {
  transition: transform 0.2s ease-out;
}
.scale-enter-from, .scale-leave-to {
  transform: scale(0.9);
}

/* Dark theme 支持 */
@media (prefers-color-scheme: dark) {
  .modal-overlay {
    background-color: rgba(0, 0, 0, 0.6);
  }
  .modal-content {
    background-color: rgba(31, 41, 55, 0.8);
    border-color: rgba(55, 65, 81, 0.3);
  }
  .modal-input {
    color: var(--color-base-content, #e5e7eb);
    background-color: var(--color-base-200, #1f2937);
    border-color: var(--color-neutral, #374151);
  }
  .btn-cancel {
    background-color: var(--color-neutral, #374151);
    color: var(--color-neutral-content, #e5e7eb);
  }
  .btn-cancel:hover {
    background-color: var(--color-base-200, #4b5563);
  }
  .btn-save {
    background-color: var(--color-primary, #2563eb);
    color: var(--color-primary-content, #fff);
  }
}
</style>
