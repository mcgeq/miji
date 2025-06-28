<!-- src/components/FloatingErrorTip.vue -->
<template>
  <div
    v-if="visible && message"
    class="absolute top-1/2 right-2 transform -translate-y-1/2 text-xs text-red-500
           whitespace-nowrap pointer-events-none select-none z-10"
  >
    {{ message }}
  </div>
</template>

<script setup lang="ts">
defineProps<{
  message?: string;
  visible?: boolean;
}>();
</script>
