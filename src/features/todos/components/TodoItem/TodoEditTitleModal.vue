<script setup lang="ts">
import { Input } from '@/components/ui';

const props = defineProps<{ title: string; show: boolean }>();
const emit = defineEmits(['save', 'close']);
const show = computed(() => props.show);
const localTitle = ref(props.title);
const isEditable = computed(
  () => localTitle.value.trim() === props.title.trim(),
);
</script>

<template>
  <Teleport to="body">
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
            <Input
              v-model="localTitle"
              placeholder="输入任务标题"
              full-width
            />
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
  </Teleport>
</template>

<style scoped lang="postcss">
/* Overlay 背景 */
.modal-overlay {
  position: fixed;
  inset: 0;
  z-index: 10001; /* 确保在 modal-mask 之上 */
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 1rem;
  background-color: color-mix(in oklch, var(--color-neutral) 60%, transparent);
  backdrop-filter: blur(6px);
}

/* 弹窗内容 */
.modal-content {
  width: 24rem; /* w-96 */
  padding: 1.5rem; /* p-6 */
  border-radius: 1.25rem; /* rounded-2xl */
  border: 1px solid var(--color-base-300);
  background-color: var(--color-base-100);
  display: flex;
  flex-direction: column;
  gap: 1.25rem;
  box-shadow: 0 10px 20px color-mix(in oklch, var(--color-neutral) 30%, transparent);
  transition: background-color 0.2s ease, border-color 0.2s ease;
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
  .modal-content {
    background-color: var(--color-base-200);
    border-color: var(--color-base-300);
  }
}
</style>
