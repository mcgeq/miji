<template>
  <transition name="fade">
    <div
      class="fixed inset-0 bg-black/60 z-50 backdrop-blur-sm px-4 flex justify-center items-center"
      @click="emit('close')"
    >
      <transition name="scale">
        <div
          class="bg-white/70 dark:bg-gray-900/80 p-6 rounded-2xl shadow-xl w-40 flex flex-col gap-4 border border-white/20 dark:border-gray-700/30"
          @click.stop
        >
          <button
            class="w-full rounded-xl py-2 px-2 bg-yellow-100 hover:bg-yellow-200 dark:bg-yellow-800/50 dark:hover:bg-yellow-700 flex justify-center"
            @click="emit('openPopup', 'description')"
          >
            <StickyNote class="w-5 h-5" />
          </button>
          <button
            class="w-full rounded-xl py-2 px-2 bg-yellow-100 hover:bg-yellow-200 dark:bg-yellow-800/50 dark:hover:bg-yellow-700 flex justify-center"
            @click="emit('openPopup', 'tags')"
          >
            <Tag class="w-5 h-5" />
          </button>
          <button
            class="w-full rounded-xl py-2 px-2 bg-yellow-100 hover:bg-yellow-200 dark:bg-yellow-800/50 dark:hover:bg-yellow-700 flex justify-center"
            @click="emit('openPopup', 'projects')"
          >
            <Folder class="w-5 h-5" />
          </button>
          <button
            class="mt-2 text-sm text-gray-500 hover:text-gray-700 dark:hover:text-gray-300 flex justify-center"
            @click="emit('close')"
          >
            <X class="w-4 h-4" />
          </button>
        </div>
      </transition>
    </div>
  </transition>
</template>

<script setup lang="ts">
import { StickyNote, Tag, Folder, X } from 'lucide-vue-next';

const emit = defineEmits(['openPopup', 'close']);
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
