<script setup lang="ts">
import { Check, X } from 'lucide-vue-next';

const props = defineProps<{ title: string; show: boolean }>();
const emit = defineEmits(['save', 'close']);
const show = computed(() => props.show);
const localTitle = ref(props.title);
const isEditable = computed(
  () => localTitle.value.trim() === props.title.trim(),
);
</script>

<template>
  <transition name="fade">
    <div
      v-if="show"
      class="px-4 bg-black/60 flex items-center inset-0 justify-center fixed z-50 backdrop-blur-sm"
      @click="emit('close')"
    >
      <transition name="scale">
        <div
          v-if="show"
          class="p-6 border border-white/20 rounded-2xl bg-white/70 flex flex-col h-auto w-96 shadow-xl backdrop-blur-lg dark:border-gray-700/30 dark:bg-gray-900/80"
          @click.stop
        >
          <input
            v-model="localTitle"
            class="text-base p-3 border border-gray-200 rounded-xl w-full transition-all dark:text-gray-100 focus:outline-none dark:border-gray-600 dark:bg-gray-800 focus:ring-2 focus:ring-blue-500/50"
            placeholder="输入任务标题"
          >
          <div class="mt-5 flex gap-4 justify-center">
            <button
              class="text-sm text-gray-700 font-medium px-5 py-2 rounded-xl bg-gray-100 transition-all dark:text-gray-200 dark:bg-gray-700 hover:bg-gray-200 active:scale-95 hover:scale-105 dark:hover:bg-gray-600"
              @click="emit('close')"
            >
              <X class="wh-5" />
            </button>
            <button
              class="text-sm text-white font-medium px-5 py-2 rounded-xl bg-blue-600 transition-all hover:bg-blue-700 active:scale-95 hover:scale-105"
              :class="{
                'bg-blue-600 hover:bg-blue-700': !isEditable,
                'bg-gray-400 hover:bg-gray-400 cursor-not-allowed': isEditable,
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
