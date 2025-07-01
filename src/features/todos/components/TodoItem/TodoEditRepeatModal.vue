<template>
  <transition name="fade">
    <div class="modal-mask" @click="emit('close')">
      <transition name="scale">
        <div class="modal-mask-window w-80 h-96" @click.stop>
          <div class="h-80">
          <!-- Repeat Type -->
          <div class="text-center">
            <label for="repeat-type" class="label-text block mb-2 mt-0">Repeat Type</label>
            <select v-model="form.type" id="repeat-type" class="mt-1 block w-full input-select" @change="resetForm">
              <option value="None">None</option>
              <option value="Daily">Daily</option>
              <option value="Weekly">Weekly</option>
              <option value="Monthly">Monthly</option>
              <option value="Yearly">Yearly</option>
              <option value="Custom">Custom</option>
            </select>
          </div>

          <!-- Daily -->
          <div v-if="form.type === 'Daily'" class="flex-juster-center gap-2">
            <label for="daily-interval" class="label-text">Every</label>
            <input type="number" id="daily-interval" v-model.number="form.interval" min="1" required class="input-number" />
            <span class="label-text">day(s)</span>
          </div>

          <!-- Weekly -->
          
          <div v-if="form.type === 'Weekly'" class="flex flex-col items-center gap-2">
            <div class="flex items-center gap-2 mt-4">
              <label for="weekly-interval" class="text-sm font-medium text-gray-700 dark:text-gray-300">
                Every
              </label>
              <input 
                type="number" 
                id="weekly-interval" 
                v-model.number="form.interval" 
                min="1" 
                required 
                class="w-16 px-2 py-1 text-sm border border-gray-300 rounded-md dark:border-gray-600 dark:bg-gray-700 dark:text-white focus:ring-2 focus:ring-blue-500"
              />
              <span class="text-sm font-medium text-gray-700 dark:text-gray-300">week(s) on</span>
            </div>
  
            <div class="flex flex-wrap gap-3 justify-center mt-1">
              <label 
                v-for="day in weekdays" 
                :key="day" 
                class="flex items-center cursor-pointer select-none text-sm"
              >
                <input 
                  type="checkbox" 
                  :value="day" 
                  v-model="form.daysOfWeek" 
                  class="w-4 h-4 border-gray-300 rounded focus:ring-blue-500 text-blue-600 dark:border-gray-600 dark:bg-gray-700 dark:text-blue-500"
                />
                <span class="ml-2 text-gray-700 dark:text-gray-300">{{ day }}</span>
              </label>
            </div>
          </div>

          <!-- Monthly -->
          <div v-if="form.type === 'Monthly'" class="flex flex-col items-center gap-2">
            <div class="flex items-center gap-2">
              <label for="monthly-interval" class="label-text">Every</label>
              <input type="number" id="monthly-interval" v-model.number="form.interval" min="1" required class="input-number" />
              <span class="label-text">month(s) on</span>
              <select v-model="form.day" class="ml-1 input-select">
                <option v-for="n in 31" :key="n" :value="n">{{ n }}</option>
                <option value="last">Last day</option>
              </select>
            </div>
          </div>

          <!-- Yearly -->
          <div v-if="form.type === 'Yearly'" class="flex flex-col items-center gap-2">
            <div class="flex items-center gap-2">
              <label for="yearly-interval" class="label-text">Every</label>
              <input type="number" id="yearly-interval" v-model.number="form.interval" min="1" required class="input-number" />
              <span class="label-text">year(s) on</span>
            </div>
            <div class="flex items-center gap-2">
              <select v-model="form.month" class="input-select">
                <option v-for="n in 12" :key="n" :value="n">{{ monthNames[n - 1] }}</option>
              </select>
              <select v-model="form.day" class="input-select">
                <option v-for="n in 31" :key="n" :value="n">{{ n }}</option>
              </select>
            </div>
          </div>

          <!-- Custom -->
          <div v-if="form.type === 'Custom'" class="text-center">
            <label for="custom-description" class="label-text block">Custom Description</label>
            <input type="text" id="custom-description" v-model="form.description" required class="mt-1 block w-full input-select" />
          </div>
          </div>

          <!-- 按钮 -->
          <div class="flex justify-center gap-4">
            <button class="px-5 py-2 text-sm font-medium rounded-xl bg-gray-100 hover:bg-gray-200 dark:bg-gray-700 dark:hover:bg-gray-600 text-gray-700 dark:text-gray-200 transition-all hover:scale-105 active:scale-95" @click="emit('close')">
              <X class="wh-5" />
            </button>
            <button
              class="modal-button"
              :class="isChanged ? 'modal-button-disabled' : 'modal-button-active'"
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
<script setup lang="ts">
import { RepeatPeriod, RepeatPeriodSchema, weekdays } from '@/schema/common';
import { buildRepeatPeriod } from '@/utils/common';
import { X, Check } from 'lucide-vue-next';

const emit = defineEmits(['save', 'close']);

const props = defineProps<{ repeat: RepeatPeriod }>();
const isChanged = ref(false);
const repeatObj = computed(() =>
  typeof props.repeat === 'string' ? JSON.parse(props.repeat) : props.repeat,
);

const form = ref<RepeatPeriod>(buildRepeatPeriod(repeatObj.value));
console.log('editRepeat: ', props.repeat);
console.log('editRepeat form: ', form.value);

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

const resetForm = () => {
  form.value = {
    type: form.value.type,
    interval: 1,
    daysOfWeek: [],
    day: 1,
    month: 1,
    description: '',
  };
};

const save = () => {
  try {
    const validatedData = RepeatPeriodSchema.parse(form.value);
    emit('save', validatedData);
    emit('close');
  } catch (error) {
    console.error('Validation failed:', error);
  }
};
</script>

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
