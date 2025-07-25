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
  }
  catch (error) {
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
              <label for="repeat-type" class="mb-2 mt-0 block text-sm text-gray-700 font-medium dark:text-gray-300">
                {{ t('todos.repeat.title') }}
              </label>
              <select
                id="repeat-type"
                v-model="form.type"
                class="mt-1 block w-full border border-gray-300 rounded-lg bg-white p-2 text-gray-900 shadow-sm dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 focus:outline-none focus:ring-2 focus:ring-blue-500"
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
            <div v-if="form.type === 'Daily'" class="mt-4 flex items-center justify-center gap-2">
              <label for="daily-interval" class="text-sm text-gray-700 font-medium dark:text-gray-300">
                {{ t('todos.repeat.labels.daily') }}
              </label>
              <input
                id="daily-interval"
                v-model.number="form.interval"
                type="number"
                min="1"
                required
                class="w-20 border border-gray-300 rounded-lg bg-white p-2 text-center text-gray-900 shadow-sm dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 focus:outline-none focus:ring-2 focus:ring-blue-500"
              >
            </div>

            <!-- Weekly -->
            <div v-if="form.type === 'Weekly'" class="mt-4 flex flex-col items-center gap-2">
              <div class="flex items-center gap-2">
                <label for="weekly-interval" class="text-sm text-gray-700 font-medium dark:text-gray-300">
                  {{ t('todos.repeat.labels.weekly') }}
                </label>
                <input
                  id="weekly-interval"
                  v-model.number="form.interval"
                  type="number"
                  min="1"
                  required
                  class="w-16 border border-gray-300 rounded-md px-2 py-1 text-sm dark:border-gray-600 dark:bg-gray-700 dark:text-white focus:ring-2 focus:ring-blue-500"
                >
              </div>
              <div class="mt-1 flex flex-wrap justify-center gap-3">
                <label
                  v-for="day in weekdays"
                  :key="day"
                  class="flex cursor-pointer select-none items-center text-sm"
                >
                  <input
                    v-model="form.daysOfWeek"
                    type="checkbox"
                    :value="day"
                    class="h-4 w-4 border-gray-300 rounded text-blue-600 dark:border-gray-600 dark:bg-gray-700 dark:text-blue-500 focus:ring-blue-500"
                  >
                  <span class="ml-2 text-gray-700 dark:text-gray-300">{{ day }}</span>
                </label>
              </div>
            </div>

            <!-- Monthly -->
            <div v-if="form.type === 'Monthly'" class="mt-4 flex flex-col items-center gap-2">
              <div class="flex items-center gap-2">
                <label for="monthly-interval" class="text-sm text-gray-700 font-medium dark:text-gray-300">
                  {{ t('todos.repeat.labels.monthly') }}
                </label>
                <input
                  id="monthly-interval"
                  v-model.number="form.interval"
                  type="number"
                  min="1"
                  required
                  class="w-20 border border-gray-300 rounded-lg bg-white p-2 text-center text-gray-900 shadow-sm dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 focus:outline-none focus:ring-2 focus:ring-blue-500"
                >
                <select
                  v-model="form.day"
                  class="ml-1 border border-gray-300 rounded-lg bg-white p-2 text-gray-900 shadow-sm dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 focus:outline-none focus:ring-2 focus:ring-blue-500"
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
            <div v-if="form.type === 'Yearly'" class="mt-4 flex flex-col items-center gap-2">
              <div class="flex items-center gap-2">
                <label for="yearly-interval" class="text-sm text-gray-700 font-medium dark:text-gray-300">
                  {{ t('todos.repeat.labels.yearly') }}
                </label>
                <input
                  id="yearly-interval"
                  v-model.number="form.interval"
                  type="number"
                  min="1"
                  required
                  class="w-20 border border-gray-300 rounded-lg bg-white p-2 text-center text-gray-900 shadow-sm dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 focus:outline-none focus:ring-2 focus:ring-blue-500"
                >
              </div>
              <div class="flex items-center gap-2">
                <select
                  v-model="form.month"
                  class="border border-gray-300 rounded-lg bg-white p-2 text-gray-900 shadow-sm dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 focus:outline-none focus:ring-2 focus:ring-blue-500"
                >
                  <option v-for="n in 12" :key="n" :value="n">
                    {{ monthNames[n - 1] }}
                  </option>
                </select>
                <select
                  v-model="form.day"
                  class="border border-gray-300 rounded-lg bg-white p-2 text-gray-900 shadow-sm dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 focus:outline-none focus:ring-2 focus:ring-blue-500"
                >
                  <option v-for="n in yearlyMonthDays" :key="n" :value="n">
                    {{ n }}
                  </option>
                </select>
              </div>
            </div>

            <!-- Custom -->
            <div v-if="form.type === 'Custom'" class="mt-4 text-center">
              <label for="custom-description" class="block text-sm text-gray-700 font-medium dark:text-gray-300">
                {{ t('todos.repeat.types.custom') }}
              </label>
              <input
                id="custom-description"
                v-model="form.description"
                type="text"
                required
                class="mt-1 block w-full border border-gray-300 rounded-lg bg-white p-2 text-gray-900 shadow-sm dark:border-gray-600 dark:bg-gray-700 dark:text-gray-100 focus:outline-none focus:ring-2 focus:ring-blue-500"
              >
            </div>
          </div>

          <!-- Buttons -->
          <div class="mt-6 flex justify-center gap-4">
            <button
              class="rounded-xl bg-gray-100 px-5 py-2 text-sm text-gray-700 font-medium transition-all active:scale-95 hover:scale-105 dark:bg-gray-700 hover:bg-gray-200 dark:text-gray-200 dark:hover:bg-gray-600"
              @click="emit('close')"
            >
              <X class="wh-5" />
            </button>
            <button
              class="rounded-xl px-5 py-2 transition-all" :class="[
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
