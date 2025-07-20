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
      class="fixed inset-0 z-50 flex items-center justify-center bg-black/50 p-4 transition-opacity duration-300"
      @click="handleBackdropClick"
    >
      <div
        class="max-h-[90vh] max-w-md w-full scale-100 transform overflow-y-auto rounded-xl bg-white shadow-2xl transition-all duration-300"
        @click.stop
      >
        <slot />
      </div>
    </div>
  </Teleport>
</template>
