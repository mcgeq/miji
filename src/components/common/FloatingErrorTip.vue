<!-- src/components/FloatingErrorTip.vue -->
<script setup lang="ts">
defineProps<{
  message?: string;
  visible?: boolean;
}>();
</script>

<template>
  <div
    v-if="visible && message"
    class="pointer-events-none absolute right-2 top-1/2 z-10 transform select-none whitespace-nowrap text-xs text-red-500 -translate-y-1/2"
  >
    {{ message }}
  </div>
</template>
