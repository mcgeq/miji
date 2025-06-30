<template>
  <transition name="fade">
    <div class="fixed inset-0 bg-black/60 flex items-center justify-center z-50 backdrop-blur-sm px-4" @click="emit('close')">
      <transition name="scale">
        <div class="bg-white/70 dark:bg-gray-900/80 p-6 rounded-2xl shadow-xl w-96 flex flex-col backdrop-blur-lg border border-white/20 dark:border-gray-700/30" @click.stop>
          <input
            type="datetime-local"
            v-model="localDueDate"
            class="w-full border border-gray-300 rounded-xl p-3 mt-1 dark:bg-gray-800 dark:text-gray-100"
          />
          <div class="flex justify-center gap-4 mt-5">
            <button
              class="px-5 py-2 bg-gray-100 dark:bg-gray-700 rounded-xl"
              @click="emit('close')"
            >
              <X class="wh-5" />
            </button>
            <button
              class="px-5 py-2 text-white rounded-xl bg-blue-600 hover:bg-blue-700 transition-all"
              :class="{
                'bg-blue-600 hover:bg-blue-700': !isChanged,
                'bg-gray-400 hover:bg-gray-400 cursor-not-allowed': isChanged
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

<script setup lang="ts">
import {
  formatForDisplay,
  getLocalISODateTimeWithOffset,
  isDateTimeContaining,
} from '@/utils/date';
import { Check, X } from 'lucide-vue-next';

const props = defineProps<{ dueDate: string | undefined }>();
const emit = defineEmits(['save', 'close']);
const localDueDate = ref(
  formatForDisplay(props.dueDate ?? getLocalISODateTimeWithOffset()),
);

const isChanged = computed(() => {
  if (!props.dueDate) return true;
  return isDateTimeContaining(props.dueDate, localDueDate.value);
});
</script>

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
