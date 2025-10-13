<script setup lang="ts">
import { Calendar, Pencil, Repeat, X } from 'lucide-vue-next';

const props = defineProps<{ show: boolean }>();
const emit = defineEmits(['editTitle', 'editDueDate', 'editRepeat', 'close']);
const show = computed(() => props.show);
</script>

<template>
  <Teleport to="body">
    <transition name="fade">
      <div
        v-if="show"
        class="modal-mask"
        @click="emit('close')"
      >
        <transition name="scale">
          <div
            v-if="show"
            class="modal-mask-window"
            @click.stop
          >
            <button
              class="modal-btn-icon"
              @click="emit('editTitle')"
            >
              <Pencil class="wh-5" />
            </button>
            <button
              class="modal-btn-icon"
              @click="emit('editDueDate')"
            >
              <Calendar class="wh-5" />
            </button>
            <button
              class="modal-btn-icon"
              @click="emit('editRepeat')"
            >
              <Repeat class="wh-5" />
            </button>
            <button
              class="modal-btn-x"
              @click="emit('close')"
            >
              <X class="wh-4" />
            </button>
          </div>
        </transition>
      </div>
    </transition>
  </Teleport>
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
