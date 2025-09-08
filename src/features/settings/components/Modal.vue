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
      class="p-4 bg-black/50 flex transition-opacity duration-300 items-center inset-0 justify-center fixed z-50"
      @click="handleBackdropClick"
    >
      <div
        class="rounded-xl bg-white max-h-[90vh] max-w-md w-full shadow-2xl scale-100 transform transition-all duration-300 overflow-y-auto"
        @click.stop
      >
        <slot />
      </div>
    </div>
  </Teleport>
</template>
