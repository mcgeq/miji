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
    <div v-if="show" class="modal-mask" @click="emit('close')">
      <transition name="scale">
        <div v-if="show" class="modal-mask-window w-80" @click.stop>
          <div class="h-80">
            <!-- Repeat Type -->
            <div class="text-center">
              <label for="repeat-type" class="text-sm text-gray-700 font-medium mb-2 mt-0 block dark:text-gray-300">
                {{ t('todos.repeat.title') }}
              </label>
              <select
                id="repeat-type"
                v-model="form.type"
                class="text-gray-900 mt-1 p-2 border border-gray-300 rounded-lg bg-white w-full block shadow-sm dark:text-gray-100 focus:outline-none dark:border-gray-600 dark:bg-gray-700 focus:ring-2 focus:ring-blue-500"
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
            <div v-if="form.type === 'Daily'" class="mt-4 flex gap-2 items-center justify-center">
              <label for="daily-interval" class="text-sm text-gray-700 font-medium dark:text-gray-300">
                {{ t('todos.repeat.labels.daily') }}
              </label>
              <input
                id="daily-interval"
                v-model.number="form.interval"
                type="number"
                min="1"
                required
                class="text-gray-900 p-2 text-center border border-gray-300 rounded-lg bg-white w-20 shadow-sm dark:text-gray-100 focus:outline-none dark:border-gray-600 dark:bg-gray-700 focus:ring-2 focus:ring-blue-500"
              >
            </div>

            <!-- Weekly -->
            <div v-if="form.type === 'Weekly'" class="mt-4 flex flex-col gap-2 items-center">
              <div class="flex gap-2 items-center">
                <label for="weekly-interval" class="text-sm text-gray-700 font-medium dark:text-gray-300">
                  {{ t('todos.repeat.labels.weekly') }}
                </label>
                <input
                  id="weekly-interval"
                  v-model.number="form.interval"
                  type="number"
                  min="1"
                  required
                  class="text-sm px-2 py-1 border border-gray-300 rounded-md w-16 dark:text-white dark:border-gray-600 dark:bg-gray-700 focus:ring-2 focus:ring-blue-500"
                >
              </div>
              <div class="mt-1 flex flex-wrap gap-3 justify-center">
                <label
                  v-for="day in weekdays"
                  :key="day"
                  class="text-sm flex cursor-pointer select-none items-center"
                >
                  <input
                    v-model="form.daysOfWeek"
                    type="checkbox"
                    :value="day"
                    class="text-blue-600 border-gray-300 rounded h-4 w-4 dark:text-blue-500 dark:border-gray-600 dark:bg-gray-700 focus:ring-blue-500"
                  >
                  <span class="text-gray-700 ml-2 dark:text-gray-300">{{ day }}</span>
                </label>
              </div>
            </div>

            <!-- Monthly -->
            <div v-if="form.type === 'Monthly'" class="mt-4 flex flex-col gap-2 items-center">
              <div class="flex gap-2 items-center">
                <label for="monthly-interval" class="text-sm text-gray-700 font-medium dark:text-gray-300">
                  {{ t('todos.repeat.labels.monthly') }}
                </label>
                <input
                  id="monthly-interval"
                  v-model.number="form.interval"
                  type="number"
                  min="1"
                  required
                  class="text-gray-900 p-2 text-center border border-gray-300 rounded-lg bg-white w-20 shadow-sm dark:text-gray-100 focus:outline-none dark:border-gray-600 dark:bg-gray-700 focus:ring-2 focus:ring-blue-500"
                >
                <select
                  v-model="form.day"
                  class="text-gray-900 ml-1 p-2 border border-gray-300 rounded-lg bg-white shadow-sm dark:text-gray-100 focus:outline-none dark:border-gray-600 dark:bg-gray-700 focus:ring-2 focus:ring-blue-500"
                >
                  <option v-for="n in monthlyDays" :key="n" :value="n">
                    {{ n }}
                  </option>
                  <option value="last">
                    Last day
                  </option>
                </select>
              </div>
            </div>

            <!-- Yearly -->
            <div v-if="form.type === 'Yearly'" class="mt-4 flex flex-col gap-2 items-center">
              <div class="flex gap-2 items-center">
                <label for="yearly-interval" class="text-sm text-gray-700 font-medium dark:text-gray-300">
                  {{ t('todos.repeat.labels.yearly') }}
                </label>
                <input
                  id="yearly-interval"
                  v-model.number="form.interval"
                  type="number"
                  min="1"
                  required
                  class="text-gray-900 p-2 text-center border border-gray-300 rounded-lg bg-white w-20 shadow-sm dark:text-gray-100 focus:outline-none dark:border-gray-600 dark:bg-gray-700 focus:ring-2 focus:ring-blue-500"
                >
              </div>
              <div class="flex gap-2 items-center">
                <select
                  v-model="form.month"
                  class="text-gray-900 p-2 border border-gray-300 rounded-lg bg-white shadow-sm dark:text-gray-100 focus:outline-none dark:border-gray-600 dark:bg-gray-700 focus:ring-2 focus:ring-blue-500"
                >
                  <option v-for="n in 12" :key="n" :value="n">
                    {{ monthNames[n - 1] }}
                  </option>
                </select>
                <select
                  v-model="form.day"
                  class="text-gray-900 p-2 border border-gray-300 rounded-lg bg-white shadow-sm dark:text-gray-100 focus:outline-none dark:border-gray-600 dark:bg-gray-700 focus:ring-2 focus:ring-blue-500"
                >
                  <option v-for="n in yearlyMonthDays" :key="n" :value="n">
                    {{ n }}
                  </option>
                </select>
              </div>
            </div>

            <!-- Custom -->
            <div v-if="form.type === 'Custom'" class="mt-4 text-center">
              <label for="custom-description" class="text-sm text-gray-700 font-medium block dark:text-gray-300">
                {{ t('todos.repeat.types.custom') }}
              </label>
              <input
                id="custom-description"
                v-model="form.description"
                type="text"
                required
                class="text-gray-900 mt-1 p-2 border border-gray-300 rounded-lg bg-white w-full block shadow-sm dark:text-gray-100 focus:outline-none dark:border-gray-600 dark:bg-gray-700 focus:ring-2 focus:ring-blue-500"
              >
            </div>
          </div>

          <!-- Buttons -->
          <div class="mt-6 flex gap-4 justify-center">
            <button
              class="text-sm text-gray-700 font-medium px-5 py-2 rounded-xl bg-gray-100 transition-all dark:text-gray-200 dark:bg-gray-700 hover:bg-gray-200 active:scale-95 hover:scale-105 dark:hover:bg-gray-600"
              @click="emit('close')"
            >
              <X class="wh-5" />
            </button>
            <button
              class="px-5 py-2 rounded-xl transition-all" :class="[
                isChanged ? 'bg-gray-400 cursor-not-allowed text-white' : 'bg-blue-600 hover:bg-blue-700 text-white',
              ]"
              :disabled="isChanged"
              @click="save"
            >
              <Check class="wh-5" />
            </button>
          </div>
        </div>
      </transition>
    </div>
  </transition>
</template>

<style scoped lang="postcss">
.fade-enter-active, .fade-leave-active {
  transition: opacity 0.25s ease-out, transform 0.25s ease-out;
}
.fade-enter-from, .fade-leave-to {
  opacity: 0;
  transform: translateY(8px);
}
.scale-enter-active, .scale-leave-active {
  transition: transform 0.2s ease-out;
}
.scale-enter-from, .scale-leave-to {
  transform: scale(0.9);
}

.input-select {
  @apply rounded-lg border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100 p-2 shadow-sm focus:outline-none focus:ring-2 focus:ring-blue-500;
}

.input-number {
  @apply w-20 mt-4 text-center rounded-lg border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-700 text-gray-900 dark:text-gray-100 p-2 shadow-sm focus:outline-none focus:ring-2 focus:ring-blue-500;
}

.label-text {
  @apply text-sm font-medium mt-4 text-gray-700 dark:text-gray-300;
}

.modal-button {
  @apply px-5 py-2 rounded-xl transition-all;
}

.modal-button-active {
  @apply bg-blue-600 hover:bg-blue-700 text-white;
}

.modal-button-disabled {
  @apply bg-gray-400 hover:bg-gray-400 cursor-not-allowed text-white;
}
</style>
