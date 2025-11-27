<script setup lang="ts">
import { Check, X } from 'lucide-vue-next';
import { Checkbox, Input, Select } from '@/components/ui';
import { RepeatPeriodSchema, weekdays } from '@/schema/common';
import { buildRepeatPeriod } from '@/utils/common';
import type { SelectOption } from '@/components/ui';
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

// 重复类型选项
const repeatTypeOptions = computed<SelectOption[]>(() => [
  { value: 'None', label: t('todos.repeat.types.no') },
  { value: 'Daily', label: t('todos.repeat.types.daily') },
  { value: 'Weekly', label: t('todos.repeat.types.weekly') },
  { value: 'Monthly', label: t('todos.repeat.types.monthly') },
  { value: 'Yearly', label: t('todos.repeat.types.yearly') },
  { value: 'Custom', label: t('todos.repeat.types.custom') },
]);

// 月份选项
const monthOptions = computed<SelectOption[]>(() =>
  monthNames.map((name, index) => ({
    value: index + 1,
    label: name,
  })),
);

// 月度日期选项
const monthlyDayOptions = computed<SelectOption[]>(() => [
  ...monthlyDays.value.map(n => ({ value: n, label: String(n) })),
  { value: 'last', label: 'Last day' },
]);

// 年度日期选项
const yearlyDayOptions = computed<SelectOption[]>(() =>
  yearlyMonthDays.value.map(n => ({ value: n, label: String(n) })),
);

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
  <Teleport to="body">
    <transition name="fade">
      <div v-if="show" class="modal-overlay" @click="emit('close')">
        <transition name="scale">
          <div v-if="show" class="modal-mask-window-money" @click.stop>
            <div class="modal-body">
              <!-- Repeat Type -->
              <div class="form-group">
                <label class="form-label">
                  {{ t('todos.repeat.title') }}
                </label>
                <Select
                  v-model="form.type"
                  :options="repeatTypeOptions"
                  full-width
                  @change="resetForm"
                />
              </div>

              <!-- Daily -->
              <div v-if="form.type === 'Daily'" class="repeat-daily">
                <label class="form-label">
                  {{ t('todos.repeat.labels.daily') }}
                </label>
                <Input
                  v-model="form.interval"
                  type="number"
                  required
                  full-width
                />
              </div>

              <!-- Weekly -->
              <div v-if="form.type === 'Weekly'" class="repeat-weekly">
                <div class="week-interval">
                  <label class="form-label">
                    {{ t('todos.repeat.labels.weekly') }}
                  </label>
                  <Input
                    v-model="form.interval"
                    type="number"
                    required
                    full-width
                  />
                </div>
                <div class="week-days">
                  <Checkbox
                    v-for="day in weekdays"
                    :key="day"
                    v-model="form.daysOfWeek"
                    :label="day"
                    :value="day"
                  />
                </div>
              </div>

              <!-- Monthly -->
              <div v-if="form.type === 'Monthly'" class="repeat-monthly">
                <label class="form-label">
                  {{ t('todos.repeat.labels.monthly') }}
                </label>
                <Input
                  v-model="form.interval"
                  type="number"
                  required
                  full-width
                />
                <Select
                  v-model="form.day"
                  :options="monthlyDayOptions"
                  full-width
                />
              </div>

              <!-- Yearly -->
              <div v-if="form.type === 'Yearly'" class="repeat-yearly">
                <label class="form-label">
                  {{ t('todos.repeat.labels.yearly') }}
                </label>
                <Input
                  v-model="form.interval"
                  type="number"
                  required
                  full-width
                />
                <Select
                  v-model="form.month"
                  :options="monthOptions"
                  full-width
                />
                <Select
                  v-model="form.day"
                  :options="yearlyDayOptions"
                  full-width
                />
              </div>

              <!-- Custom -->
              <div v-if="form.type === 'Custom'" class="repeat-custom">
                <label class="form-label">
                  {{ t('todos.repeat.types.custom') }}
                </label>
                <Input
                  v-model="form.description"
                  type="text"
                  required
                  full-width
                />
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
  padding: 1rem;
}

/* Form Label */
.form-label {
  display: block;
  font-size: 0.875rem;
  font-weight: 500;
  color: var(--color-base-content, #374151);
  margin-bottom: 0.25rem;
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
</style>
