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
      class="fixed inset-0 z-50 flex items-center justify-center bg-black/60 px-4 backdrop-blur-sm"
      @click="emit('close')"
    >
      <transition name="scale">
        <div
          v-if="show"
          class="h-auto w-96 flex flex-col border border-white/20 rounded-2xl bg-white/70 p-6 shadow-xl backdrop-blur-lg dark:border-gray-700/30 dark:bg-gray-900/80"
          @click.stop
        >
          <input
            v-model="localTitle"
            class="w-full border border-gray-200 rounded-xl p-3 text-base transition-all dark:border-gray-600 dark:bg-gray-800 dark:text-gray-100 focus:outline-none focus:ring-2 focus:ring-blue-500/50"
            placeholder="输入任务标题"
          >
          <div class="mt-5 flex justify-center gap-4">
            <button
              class="rounded-xl bg-gray-100 px-5 py-2 text-sm text-gray-700 font-medium transition-all active:scale-95 hover:scale-105 dark:bg-gray-700 hover:bg-gray-200 dark:text-gray-200 dark:hover:bg-gray-600"
              @click="emit('close')"
            >
              <X class="wh-5" />
            </button>
            <button
              class="rounded-xl bg-blue-600 px-5 py-2 text-sm text-white font-medium transition-all active:scale-95 hover:scale-105 hover:bg-blue-700"
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
