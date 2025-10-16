<script setup lang="ts">
import { Check, X } from 'lucide-vue-next';
import {
  DateUtils,
} from '@/utils/date';

const props = defineProps<{ dueDate: string | undefined; show: boolean }>();
const emit = defineEmits(['save', 'close']);
const show = computed(() => props.show);
const localDueDate = ref(
  DateUtils.formatForDisplay(props.dueDate ?? DateUtils.getLocalISODateTimeWithOffset()),
);

const isChanged = computed(() => {
  if (!props.dueDate)
    return true;
  return DateUtils.isDateTimeContaining(props.dueDate, localDueDate.value);
});
</script>

<template>
  <Teleport to="body">
    <transition name="fade">
      <div v-if="show" class="modal-overlay" @click="emit('close')">
        <transition name="scale">
          <div v-if="show" class="modal-window" @click.stop>
            <input
              v-model="localDueDate"
              type="datetime-local"
              class="input-datetime"
            >
            <div class="modal-actions">
              <button class="btn-cancel" @click="emit('close')">
                <X class="icon" />
              </button>
              <button
                class="btn-save"
                :class="{ 'btn-disabled': isChanged }"
                :disabled="isChanged"
                @click="emit('save', localDueDate)"
              >
                <Check class="icon" />
              </button>
            </div>
          </div>
        </transition>
      </div>
    </transition>
  </Teleport>
</template>

<style scoped lang="postcss">
/* Overlay */
.modal-overlay {
  position: fixed;
  inset: 0;
  z-index: 10001; /* 确保在 modal-mask 之上 */
  display: flex;
  justify-content: center;
  align-items: center;
  background-color: color-mix(in oklch, var(--color-neutral) 60%, transparent);
  backdrop-filter: blur(6px);
}

/* Modal Window */
.modal-window {
  width: 24rem; /* w-96 */
  padding: 1.5rem;
  border-radius: 1.25rem;
  border: 1px solid var(--color-base-300);
  background-color: var(--color-base-100);
  display: flex;
  flex-direction: column;
  gap: 1rem;
  box-shadow: 0 10px 20px color-mix(in oklch, var(--color-neutral) 30%, transparent);
  transition: all 0.2s ease;
}

/* Input datetime */
.input-datetime {
  width: 100%;
  padding: 0.75rem;
  border-radius: 1rem;
  border: 1px solid var(--color-neutral, #d1d5db);
  background-color: var(--color-base-100, #fff);
  color: var(--color-base-content, #111827);
  outline: none;
  transition: border-color 0.2s ease, box-shadow 0.2s ease;
}

.input-datetime:focus {
  border-color: var(--color-primary, #2563eb);
  box-shadow: 0 0 0 2px rgba(59,130,246,0.3);
}

/* Buttons container */
.modal-actions {
  display: flex;
  gap: 1rem;
  justify-content: center;
  margin-top: 1.25rem;
}

/* Cancel button */
.btn-cancel {
  padding: 0.5rem 1.25rem;
  border-radius: 1rem;
  font-size: 0.875rem;
  font-weight: 500;
  border: none;
  background-color: var(--color-neutral, #f3f4f6);
  color: var(--color-base-content, #374151);
  cursor: pointer;
  transition: all 0.2s ease;
}
.btn-cancel:hover {
  background-color: var(--color-base-200, #e5e7eb);
  transform: scale(1.05);
}
.btn-cancel:active {
  transform: scale(0.95);
}

/* Save button */
.btn-save {
  padding: 0.5rem 1.25rem;
  border-radius: 1rem;
  font-size: 0.875rem;
  font-weight: 500;
  border: none;
  background-color: var(--color-primary, #2563eb);
  color: var(--color-primary-content, #fff);
  cursor: pointer;
  transition: all 0.2s ease;
}
.btn-save:hover:not(:disabled) {
  background-color: #1e40af;
  transform: scale(1.05);
}
.btn-save:active:not(:disabled) {
  transform: scale(0.95);
}

/* Disabled save button */
.btn-disabled {
  background-color: var(--color-neutral, #9ca3af);
  cursor: not-allowed;
  pointer-events: none;
}

/* Icon size */
.icon {
  width: 1.25rem;
  height: 1.25rem;
}

/* Fade animation */
.fade-enter-active, .fade-leave-active {
  transition: opacity 0.25s ease-out, transform 0.25s ease-out;
}
.fade-enter-from, .fade-leave-to {
  opacity: 0;
  transform: translateY(8px);
}

/* Scale animation */
.scale-enter-active, .scale-leave-active {
  transition: transform 0.2s ease-out;
}
.scale-enter-from, .scale-leave-to {
  transform: scale(0.9);
}

/* Dark theme */
@media (prefers-color-scheme: dark) {
  .modal-window {
    background-color: var(--color-base-200);
    border-color: var(--color-base-300);
  }
  .input-datetime {
    background-color: var(--color-base-100);
    border-color: var(--color-base-300);
  }
}
</style>
