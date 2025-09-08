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
  <transition name="fade">
    <div v-if="show" class="px-4 bg-black/60 flex items-center inset-0 justify-center fixed z-50 backdrop-blur-sm" @click="emit('close')">
      <transition name="scale">
        <div v-if="show" class="p-6 border border-white/20 rounded-2xl bg-white/70 flex flex-col w-96 shadow-xl backdrop-blur-lg dark:border-gray-700/30 dark:bg-gray-900/80" @click.stop>
          <input
            v-model="localDueDate"
            type="datetime-local"
            class="mt-1 p-3 border border-gray-300 rounded-xl w-full dark:text-gray-100 dark:bg-gray-800"
          >
          <div class="mt-5 flex gap-4 justify-center">
            <button
              class="px-5 py-2 rounded-xl bg-gray-100 dark:bg-gray-700"
              @click="emit('close')"
            >
              <X class="wh-5" />
            </button>
            <button
              class="text-white px-5 py-2 rounded-xl bg-blue-600 transition-all hover:bg-blue-700"
              :class="{
                'bg-blue-600 hover:bg-blue-700': !isChanged,
                'bg-gray-400 hover:bg-gray-400 cursor-not-allowed': isChanged,
              }"
              :disabled="isChanged"
              @click="emit('save', localDueDate)"
            >
              <Check class="wh-5" />
            </button>
          </div>
        </div>
      </transition>
    </div>
  </transition>
</template>

<style scoped>
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
</style>
