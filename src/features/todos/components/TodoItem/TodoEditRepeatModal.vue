<script setup lang="ts">
import { Check, X } from 'lucide-vue-next';
import { RepeatPeriodSchema, weekdays } from '@/schema/common';
import { buildRepeatPeriod } from '@/utils/common';
import type { RepeatPeriod } from '@/schema/common';

const props = defineProps<{ repeat: RepeatPeriod; show: boolean }>();
const emit = defineEmits(['save', 'close']);
const { t } = useI18n();
const isChanged = ref(false);
const show = computed(() => props.show);
const repeatObj = computed(() =>
  typeof props.repeat === 'string' ? JSON.parse(props.repeat) : props.repeat,
);

const form = ref<RepeatPeriod>(buildRepeatPeriod(repeatObj.value));

const monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

function resetForm() {
  form.value = {
    type: form.value.type,
    interval: 1,
    daysOfWeek: [],
    day: 1,
    month: 1,
    description: '',
  };
}

const monthlyDays = computed(() => {
  if (form.value.type === 'Monthly') {
    const year = new Date().getFullYear();
    // 这里按每月的第 interval 个月算可能语义不太对，应该是当月？
    const month = new Date().getMonth() + 1;
    const days = new Date(year, month, 0).getDate();
    return Array.from({ length: days }, (_, i) => i + 1);
  }
  return [];
});

const yearlyMonthDays = computed(() => {
  if (form.value.type === 'Yearly') {
    const year = new Date().getFullYear();
    const month = form.value.month;
    const days = new Date(year, month, 0).getDate();
    return Array.from({ length: days }, (_, i) => i + 1);
  }
  return [];
});

function save() {
  try {
    const validatedData = RepeatPeriodSchema.parse(form.value);
    emit('save', validatedData);
    emit('close');
  } catch (error) {
    console.error('Validation failed:', error);
  }
}
</script>

<template>
  <transition name="fade">
    <div v-if="show" class="modal-overlay" @click="emit('close')">
      <transition name="scale">
        <div v-if="show" class="modal-mask-window" @click.stop>
          <div class="modal-body">
            <!-- Repeat Type -->
            <div class="form-group">
              <label for="repeat-type" class="form-label">
                {{ t('todos.repeat.title') }}
              </label>
              <select
                id="repeat-type"
                v-model="form.type"
                class="input-select"
                @change="resetForm"
              >
                <option value="None">
                  {{ t('todos.repeat.types.no') }}
                </option>
                <option value="Daily">
                  {{ t('todos.repeat.types.daily') }}
                </option>
                <option value="Weekly">
                  {{ t('todos.repeat.types.weekly') }}
                </option>
                <option value="Monthly">
                  {{ t('todos.repeat.types.monthly') }}
                </option>
                <option value="Yearly">
                  {{ t('todos.repeat.types.yearly') }}
                </option>
                <option value="Custom">
                  {{ t('todos.repeat.types.custom') }}
                </option>
              </select>
            </div>

            <!-- Daily -->
            <div v-if="form.type === 'Daily'" class="repeat-daily">
              <label for="daily-interval" class="form-label">
                {{ t('todos.repeat.labels.daily') }}
              </label>
              <input
                id="daily-interval"
                v-model.number="form.interval"
                type="number"
                min="1"
                required
                class="input-number"
              >
            </div>

            <!-- Weekly -->
            <div v-if="form.type === 'Weekly'" class="repeat-weekly">
              <div class="week-interval">
                <label for="weekly-interval" class="form-label">
                  {{ t('todos.repeat.labels.weekly') }}
                </label>
                <input
                  id="weekly-interval"
                  v-model.number="form.interval"
                  type="number"
                  min="1"
                  required
                  class="input-number"
                >
              </div>
              <div class="week-days">
                <label v-for="day in weekdays" :key="day" class="checkbox-label">
                  <input
                    v-model="form.daysOfWeek"
                    type="checkbox"
                    :value="day"
                    class="checkbox-input"
                  >
                  <span>{{ day }}</span>
                </label>
              </div>
            </div>

            <!-- Monthly -->
            <div v-if="form.type === 'Monthly'" class="repeat-monthly">
              <label for="monthly-interval" class="form-label">
                {{ t('todos.repeat.labels.monthly') }}
              </label>
              <input
                id="monthly-interval"
                v-model.number="form.interval"
                type="number"
                min="1"
                required
                class="input-number"
              >
              <select v-model="form.day" class="input-select">
                <option v-for="n in monthlyDays" :key="n" :value="n">
                  {{ n }}
                </option>
                <option value="last">
                  Last day
                </option>
              </select>
            </div>

            <!-- Yearly -->
            <div v-if="form.type === 'Yearly'" class="repeat-yearly">
              <label for="yearly-interval" class="form-label">
                {{ t('todos.repeat.labels.yearly') }}
              </label>
              <input
                id="yearly-interval"
                v-model.number="form.interval"
                type="number"
                min="1"
                required
                class="input-number"
              >
              <select v-model="form.month" class="input-select">
                <option v-for="n in 12" :key="n" :value="n">
                  {{ monthNames[n - 1] }}
                </option>
              </select>
              <select v-model="form.day" class="input-select">
                <option v-for="n in yearlyMonthDays" :key="n" :value="n">
                  {{ n }}
                </option>
              </select>
            </div>

            <!-- Custom -->
            <div v-if="form.type === 'Custom'" class="repeat-custom">
              <label for="custom-description" class="form-label">
                {{ t('todos.repeat.types.custom') }}
              </label>
              <input
                id="custom-description"
                v-model="form.description"
                type="text"
                required
                class="input-select"
              >
            </div>
          </div>

          <!-- Buttons -->
          <div class="modal-actions">
            <button class="btn-cancel" @click="emit('close')">
              <X class="icon" />
            </button>
            <button
              class="btn-save"
              :class="{ 'btn-disabled': isChanged }"
              :disabled="isChanged"
              @click="save"
            >
              <Check class="icon" />
            </button>
          </div>
        </div>
      </transition>
    </div>
  </transition>
</template>

<style scoped lang="postcss">
/* Form Label */
.form-label {
  display: block;
  font-size: 0.875rem;
  font-weight: 500;
  color: var(--color-base-content, #374151);
  margin-bottom: 0.25rem;
}

/* Select and Input */
.input-select, .input-number {
  width: 100%;
  padding: 0.5rem;
  border-radius: 0.5rem;
  border: 1px solid var(--color-neutral, #d1d5db);
  background-color: var(--color-base-100, #fff);
  color: var(--color-base-content, #111827);
  box-shadow: 0 1px 2px rgba(0,0,0,0.05);
  outline: none;
  transition: border-color 0.2s ease, box-shadow 0.2s ease;
}

.input-select:focus, .input-number:focus {
  border-color: var(--color-primary, #2563eb);
  box-shadow: 0 0 0 2px rgba(59,130,246,0.3);
}

/* Checkbox */
.checkbox-label {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  font-size: 0.875rem;
  cursor: pointer;
  user-select: none;
}

.checkbox-input {
  width: 1rem;
  height: 1rem;
  border-radius: 0.25rem;
  border: 1px solid var(--color-neutral, #d1d5db);
  accent-color: var(--color-primary, #2563eb);
}

/* Modal Buttons */
.modal-actions {
  display: flex;
  gap: 1rem;
  justify-content: center;
  margin-top: 1.5rem;
}

.btn-cancel, .btn-save {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  padding: 0.5rem 1.25rem;
  border-radius: 1rem;
  font-size: 0.875rem;
  font-weight: 500;
  border: none;
  cursor: pointer;
  transition: all 0.2s ease;
}

.btn-cancel {
  background-color: var(--color-neutral, #f3f4f6);
  color: var(--color-base-content, #374151);
}
.btn-cancel:hover {
  background-color: var(--color-base-200, #e5e7eb);
  transform: scale(1.05);
}
.btn-cancel:active {
  transform: scale(0.95);
}

.btn-save {
  background-color: var(--color-primary, #2563eb);
  color: var(--color-primary-content, #fff);
}
.btn-save:hover:not(:disabled) {
  background-color: #1e40af;
  transform: scale(1.05);
}
.btn-save:active:not(:disabled) {
  transform: scale(0.95);
}
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

/* Dark Theme */
@media (prefers-color-scheme: dark) {
  .modal-window {
    background-color: rgba(31,41,55,0.8);
    border-color: rgba(55,65,81,0.3);
  }
  .input-select, .input-number {
    background-color: var(--color-base-200, #1f2937);
    border-color: var(--color-neutral, #374151);
    color: var(--color-base-content, #e5e7eb);
  }
  .form-label {
    color: var(--color-base-content, #e5e7eb);
  }
  .checkbox-input {
    accent-color: var(--color-primary, #2563eb);
    border-color: var(--color-neutral, #374151);
    background-color: var(--color-base-200, #1f2937);
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
