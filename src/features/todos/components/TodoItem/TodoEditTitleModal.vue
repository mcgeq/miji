<template>
  <transition name="fade">
    <div class="fixed inset-0 bg-black/60 flex items-center justify-center z-50 backdrop-blur-sm px-4" @click="emit('close')">
      <transition name="scale">
        <div class="bg-white/70 dark:bg-gray-900/80 p-6 rounded-2xl shadow-xl w-96 flex flex-col h-auto backdrop-blur-lg border border-white/20 dark:border-gray-700/30" @click.stop>
          <input
            class="w-full border border-gray-200 dark:border-gray-600 rounded-xl p-3 text-base dark:bg-gray-800 dark:text-gray-100 focus:outline-none focus:ring-2 focus:ring-blue-500/50 transition-all"
            v-model="localTitle"
            placeholder="输入任务标题"
          />
          <div class="flex justify-center gap-4 mt-5">
            <button
              class="px-5 py-2 text-sm font-medium rounded-xl bg-gray-100 hover:bg-gray-200 dark:bg-gray-700 dark:hover:bg-gray-600 text-gray-700 dark:text-gray-200 transition-all hover:scale-105 active:scale-95"
              @click="emit('close')"
            >
              <X class="wh-5" />
            </button>
            <button
              class="px-5 py-2 text-sm font-medium rounded-xl bg-blue-600 hover:bg-blue-700 text-white transition-all hover:scale-105 active:scale-95"
              :class="{
                'bg-blue-600 hover:bg-blue-700': !isEditable,
                'bg-gray-400 hover:bg-gray-400 cursor-not-allowed': isEditable
              }"
              :disabled="isEditable"
              @click="emit('save', localTitle)"
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
import { Check, X } from 'lucide-vue-next';

const props = defineProps<{ title: string }>();
const emit = defineEmits(['save', 'close']);
const localTitle = ref(props.title);
const isEditable = computed(
  () => localTitle.value.trim() === props.title.trim(),
);
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
