<template>
  <transition name="fade">
    <div
      class="modal-mask"
      @click="emit('close')"
    >
      <transition name="scale">
        <div
          class="modal-mask-window"
          @click.stop
        >
          <button
            class="modal-btn-icon"
            @click="emit('openPopup', 'description')"
          >
            <StickyNote class="wh-5" />
          </button>
          <button
            class="modal-btn-icon"
            @click="emit('openPopup', 'tags')"
          >
            <Tag class="wh-5" />
          </button>
          <button
            class="modal-btn-icon"
            @click="emit('openPopup', 'projects')"
          >
            <Folder class="wh-5" />
          </button>
          <button
            class="modal-btn-x"
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
</style>
