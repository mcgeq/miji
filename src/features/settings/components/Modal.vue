<script setup lang="ts">
interface Props {
  closeOnBackdrop?: boolean;
}

const props = withDefaults(defineProps<Props>(), {
  closeOnBackdrop: true,
});

const emit = defineEmits<{
  close: [];
}>();

function handleBackdropClick() {
  if (props.closeOnBackdrop) {
    emit('close');
  }
}
</script>

<template>
  <Teleport to="body">
    <div
      class="modal-overlay-wrapper"
      @click="handleBackdropClick"
    >
      <div
        class="modal-content-wrapper"
        @click.stop
      >
        <slot />
      </div>
    </div>
  </Teleport>
</template>

<style scoped lang="postcss">
.modal-overlay-wrapper {
  transition: opacity 300ms;
}

.modal-content-wrapper {
  max-height: 90vh;
  max-width: 28rem;
  box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25);
  transform: scale(1);
  transition: all 300ms;
  overflow-y: auto;
}
</style>
